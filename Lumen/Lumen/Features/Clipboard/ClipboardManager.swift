import AppKit
import Observation

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
