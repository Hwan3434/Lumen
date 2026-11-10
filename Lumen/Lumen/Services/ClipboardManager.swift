import AppKit
import Observation

struct ClipboardItem: Identifiable, Equatable {
    /// 큰 본문(수만 자 텍스트)이 행/필터/dedup마다 매번 trim·lowercased 되지 않도록
    /// 표시·검색용으로만 사용할 prefix 한도. 본문 자체는 text에 그대로 남는다.
    static let displayPrefixLimit = 200

    let id: UUID
    let date: Date
    let text: String?
    let fileURLs: [URL]?
    /// 복사한 이미지를 저장해 둔 PNG 파일. 디코딩한 이미지는 들고 있지 않는다 —
    /// 화면 캡처 한 장이 수십 MB라 기록 수만큼 쌓이면 안 된다. 그릴 때만 `resolvedImage`로 읽는다.
    let imagePath: String?
    let sourceApp: String?
    let sourceAppBundleID: String?

    /// 리스트 행에 그릴 짧은 한 줄. 1회만 계산해 저장.
    let displayText: String
    /// 검색 비교용 소문자 키. displayText 기반이라 본문 9000번째 단어는 매칭되지 않는다 (의도된 트레이드오프).
    let searchKey: String

    init(id: UUID = UUID(), date: Date, text: String?, fileURLs: [URL]?, imagePath: String? = nil, sourceApp: String? = nil, sourceAppBundleID: String? = nil) {
        self.id = id
        self.date = date
        self.text = text
        self.fileURLs = fileURLs
        self.imagePath = imagePath
        self.sourceApp = sourceApp
        self.sourceAppBundleID = sourceAppBundleID
        let display = Self.computeDisplayText(text: text, fileURLs: fileURLs, imagePath: imagePath)
        self.displayText = display
        self.searchKey = display.lowercased()
    }

    private static func computeDisplayText(text: String?, fileURLs: [URL]?, imagePath: String?) -> String {
        if let text = text, !text.isEmpty {
            let head = text.prefix(displayPrefixLimit)
            return String(head).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let urls = fileURLs, !urls.isEmpty {
            return urls.map { $0.lastPathComponent }.joined(separator: ", ")
        }
        if imagePath != nil {
            return "[이미지]"
        }
        return "[알 수 없는 항목]"
    }

    /// 아이콘 캐시는 그리는 쪽(뷰)에서만 쓰므로 메인 액터에 묶어 둔다.
    /// 격리 없는 static var면 다른 스레드에서 닿는 순간 데이터 레이스가 된다.
    @MainActor private static var iconCache: [String: NSImage] = [:]

    @MainActor
    var sourceAppIcon: NSImage? {
        guard let bundleID = sourceAppBundleID else { return nil }
        if let cached = Self.iconCache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        Self.iconCache[bundleID] = icon
        return icon
    }

    enum Kind {
        case text, image, file

        /// 목록 행 오른쪽에 보이는 종류 문구.
        var label: String {
            switch self {
            case .text:  return "텍스트"
            case .image: return "이미지"
            case .file:  return "파일"
            }
        }

        /// 목록 행 왼쪽 `LumenIcon` 이름.
        var icon: String {
            switch self {
            case .text:  return "align-left"
            case .image: return "image"
            case .file:  return "file"
            }
        }
    }

    /// 파일 → 이미지 → 텍스트 순으로 판정한다.
    var kind: Kind {
        if fileURLs != nil { return .file }
        if imagePath != nil { return .image }
        return .text
    }

    var resolvedImage: NSImage? {
        imagePath.flatMap { NSImage(contentsOfFile: $0) }
    }

    /// 같은 내용을 다시 복사한 것인지. 텍스트는 본문 전체, 파일은 경로 전체로 본다.
    /// 이미지는 서로 같다고 보지 않는다 — 내용 비교가 비싸고, 한데 묶으면 새 이미지가 이전 이미지를 모두 지운다.
    func isDuplicate(of other: ClipboardItem) -> Bool {
        guard kind == other.kind else { return false }
        switch kind {
        case .text:  return text == other.text
        case .file:  return fileURLs == other.fileURLs
        case .image: return false
        }
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    func copyToPasteboard() {
        NSPasteboard.general.clearContents()
        if let urls = fileURLs {
            NSPasteboard.general.writeObjects(urls as [NSURL])
        } else if let img = resolvedImage {
            NSPasteboard.general.writeObjects([img])
        } else if let text = text {
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
}

@Observable
@MainActor
final class ClipboardManager {
    static let shared = ClipboardManager()

    var history: [ClipboardItem] = []
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    let maxItems = 500

    private let imagesDir: URL = LumenStorage.url(for: .clipboardImagesDir)

    // 디스크 I/O 전용 직렬 큐 — 메인 스레드 블로킹 방지
    private let diskQueue = DispatchQueue(label: "com.lumen.clipboard.disk", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    private init() {}

    func startMonitoring() {
        MemoryTrace.record("ClipboardManager.loadFromDisk:start")
        loadFromDisk()
        MemoryTrace.record("ClipboardManager.loadFromDisk:done (\(history.count)개)")
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkClipboard() }
        }
        // 앱이 떠 있는 내내 도는 타이머라 시스템이 다른 깨어남과 묶을 수 있게 여유를 준다.
        timer.tolerance = 0.2
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        flushPendingSave()
    }

    /// 디바운스 대기 중인 save 즉시 실행 (앱 종료 시 호출)
    func flushPendingSave() {
        guard let work = saveWorkItem, !work.isCancelled else { return }
        work.cancel()
        saveWorkItem = nil
        let items = snapshotSavedItems()
        // diskQueue는 직렬 큐라 sync로 넣으면 이미 실행 중인 저장이 끝난 뒤에 쓴다 — 같은 파일 동시 쓰기 방지.
        diskQueue.sync {
            Self.writeHistory(items)
        }
    }

    private func snapshotSavedItems() -> [SavedItem] {
        history.map { item in
            SavedItem(
                id: item.id.uuidString,
                date: item.date,
                text: item.text,
                filePaths: item.fileURLs?.map { $0.path },
                imagePath: item.imagePath,
                sourceApp: item.sourceApp,
                sourceAppBundleID: item.sourceAppBundleID
            )
        }
    }

    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        let pb = NSPasteboard.general
        // 비밀번호 관리자는 복사한 값에 이 표시를 붙여 클립보드 기록 앱이 건너뛰게 한다(nspasteboard.org 관례).
        let types = pb.types ?? []
        if types.contains(Self.concealedType) || types.contains(Self.transientType) { return }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName
        let appBundleID = frontApp?.bundleIdentifier

        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            addItem(ClipboardItem(date: Date(), text: nil, fileURLs: urls, sourceApp: appName, sourceAppBundleID: appBundleID))
            return
        }

        let text = pb.string(forType: .string)
        if text == nil || text?.isEmpty == true, let image = NSImage(pasteboard: pb) {
            addImage(image, from: pb, sourceApp: appName, sourceAppBundleID: appBundleID)
            return
        }

        if let text = text, !text.isEmpty {
            addItem(ClipboardItem(date: Date(), text: text, fileURLs: nil, sourceApp: appName, sourceAppBundleID: appBundleID))
        }
    }

    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    // MARK: - 다시 복사

    /// 기록의 항목을 다시 클립보드에 올리고 맨 위로 옮긴다.
    /// 여기서 올린 내용을 감시 타이머가 새 복사로 또 읽지 않게 changeCount를 맞춰 둔다 —
    /// 이미지는 중복으로 묶이지 않아서, 그대로 두면 고를 때마다 같은 이미지가 하나씩 늘어난다.
    func copyToPasteboard(_ item: ClipboardItem) {
        item.copyToPasteboard()
        lastChangeCount = NSPasteboard.general.changeCount
        guard let idx = history.firstIndex(where: { $0.id == item.id }) else { return }
        history.remove(at: idx)
        history.insert(ClipboardItem(id: item.id, date: Date(), text: item.text, fileURLs: item.fileURLs,
                                     imagePath: item.imagePath, sourceApp: item.sourceApp,
                                     sourceAppBundleID: item.sourceAppBundleID), at: 0)
        scheduleSave()
    }

    // MARK: - 삭제

    /// 단건 삭제. 첨부된 이미지 파일도 함께 정리.
    func delete(id: UUID) {
        guard let idx = history.firstIndex(where: { $0.id == id }) else { return }
        let removed = history.remove(at: idx)
        if let path = removed.imagePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        scheduleSave()
    }

    /// 전체 삭제. 이미지 디렉터리도 통째로 비운다.
    func deleteAll() {
        for item in history {
            if let path = item.imagePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        history.removeAll()
        scheduleSave()
    }

    private func addItem(_ item: ClipboardItem) {
        history.removeAll { item.isDuplicate(of: $0) }

        history.insert(item, at: 0)

        // 초과분 이미지 삭제
        while history.count > maxItems {
            let removed = history.removeLast()
            if let path = removed.imagePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }

        scheduleSave()
    }

    // MARK: - 이미지 저장

    /// 이미지를 PNG 파일로 저장한 뒤에 기록에 넣는다. 큰 화면 캡처는 인코딩이 오래 걸려 메인에서 하면 UI가 멈칫한다.
    /// 그래서 메인에서는 클립보드의 원본 바이트만 꺼내고, 변환과 쓰기는 diskQueue에서 한다.
    /// 저장에 실패하면 기록에 넣지 않는다 — 파일 없는 이미지 항목은 다음 실행 때 사라질 뿐이다.
    private func addImage(_ image: NSImage, from pb: NSPasteboard, sourceApp: String?, sourceAppBundleID: String?) {
        let png = pb.data(forType: .png)
        guard let data = png ?? pb.data(forType: .tiff) ?? image.tiffRepresentation else { return }
        let isPNG = png != nil
        let date = Date()
        let fileURL = imagesDir.appendingPathComponent(UUID().uuidString + ".png")
        diskQueue.async { [weak self] in
            guard Self.writePNG(data, isPNG: isPNG, to: fileURL) else { return }
            // flushPendingSave가 메인에서 diskQueue.sync로 기다리므로 여기서 main.sync를 쓰면 서로 물린다.
            DispatchQueue.main.async {
                self?.addItem(ClipboardItem(date: date, text: nil, fileURLs: nil, imagePath: fileURL.path,
                                            sourceApp: sourceApp, sourceAppBundleID: sourceAppBundleID))
            }
        }
    }

    /// 클립보드에서 꺼낸 이미지 바이트를 PNG 파일로 쓴다. 이미 PNG면 그대로, 아니면(TIFF) 변환한다.
    nonisolated static func writePNG(_ data: Data, isPNG: Bool, to fileURL: URL) -> Bool {
        guard let pngData = isPNG ? data
                : NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:]) else { return false }
        return (try? pngData.write(to: fileURL, options: .atomic)) != nil
    }

    // MARK: - 영속성

    private struct SavedItem: Codable {
        let id: String
        let date: Date
        let text: String?
        let filePaths: [String]?
        let imagePath: String?
        let sourceApp: String?
        let sourceAppBundleID: String?
    }

    /// 메인 스레드 블로킹 방지 — 2초 디바운스 후 백그라운드에서 인코딩/쓰기
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let items = snapshotSavedItems()
        let work = DispatchWorkItem {
            Self.writeHistory(items)
        }
        saveWorkItem = work
        diskQueue.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    /// 기록에는 복사한 글이 그대로 들어 있어 본인만 읽을 수 있게 둔다(`secrets.dat`와 같은 0600).
    /// atomic 쓰기가 매번 새 파일로 바꿔 놓으므로 쓸 때마다 다시 건다.
    private static func writeHistory(_ items: [SavedItem]) {
        LumenStorage.write(items, to: .clipboardHistory)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600],
                                               ofItemAtPath: LumenStorage.url(for: .clipboardHistory).path)
    }

    private func loadFromDisk() {
        guard let items = LumenStorage.read([SavedItem].self, from: .clipboardHistory) else { return }
        history = items.compactMap { saved in
            // 이미지 파일이 존재하는지 확인
            if let imgPath = saved.imagePath, !FileManager.default.fileExists(atPath: imgPath) {
                return nil
            }
            return ClipboardItem(
                id: UUID(uuidString: saved.id) ?? UUID(),
                date: saved.date,
                text: saved.text,
                fileURLs: saved.filePaths?.map { URL(fileURLWithPath: $0) },
                imagePath: saved.imagePath,
                sourceApp: saved.sourceApp,
                sourceAppBundleID: saved.sourceAppBundleID
            )
        }
    }
}
