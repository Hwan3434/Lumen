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
    let image: NSImage?
    let imagePath: String?
    let sourceApp: String?
    let sourceAppBundleID: String?

    /// 리스트 행에 그릴 짧은 한 줄. 1회만 계산해 저장.
    let displayText: String
    /// 검색 비교용 소문자 키. displayText 기반이라 본문 9000번째 단어는 매칭되지 않는다 (의도된 트레이드오프).
    let searchKey: String

    init(id: UUID = UUID(), date: Date, text: String?, fileURLs: [URL]?, image: NSImage?, imagePath: String? = nil, sourceApp: String? = nil, sourceAppBundleID: String? = nil) {
        self.id = id
        self.date = date
        self.text = text
        self.fileURLs = fileURLs
        self.image = image
        self.imagePath = imagePath
        self.sourceApp = sourceApp
        self.sourceAppBundleID = sourceAppBundleID
        let display = Self.computeDisplayText(text: text, fileURLs: fileURLs, image: image, imagePath: imagePath)
        self.displayText = display
        self.searchKey = display.lowercased()
    }

    private static func computeDisplayText(text: String?, fileURLs: [URL]?, image: NSImage?, imagePath: String?) -> String {
        if let text = text, !text.isEmpty {
            let head = text.prefix(displayPrefixLimit)
            return String(head).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let urls = fileURLs, !urls.isEmpty {
            return urls.map { $0.lastPathComponent }.joined(separator: ", ")
        }
        if image != nil || imagePath != nil {
            return "[이미지]"
        }
        return "[알 수 없는 항목]"
    }

    private static var iconCache: [String: NSImage] = [:]

    var sourceAppIcon: NSImage? {
        guard let bundleID = sourceAppBundleID else { return nil }
        if let cached = Self.iconCache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        Self.iconCache[bundleID] = icon
        return icon
    }

    var typeLabel: String {
        if fileURLs != nil { return "파일" }
        if image != nil || imagePath != nil { return "이미지" }
        return "텍스트"
    }

    var resolvedImage: NSImage? {
        if let image = image { return image }
        if let path = imagePath { return NSImage(contentsOfFile: path) }
        return nil
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
final class ClipboardManager {
    static let shared = ClipboardManager()

    var history: [ClipboardItem] = []
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let maxItems = 500

    private let savePath: URL = LumenStorage.url(for: .clipboardHistory)
    private let imagesDir: URL = LumenStorage.url(for: .clipboardImagesDir)

    // 디스크 I/O 전용 직렬 큐 — 메인 스레드 블로킹 방지
    private let diskQueue = DispatchQueue(label: "com.lumen.clipboard.disk", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    private init() {}

    func startMonitoring() {
        AppResourceMonitor.trace("ClipboardManager.loadFromDisk:start")
        loadFromDisk()
        AppResourceMonitor.trace("ClipboardManager.loadFromDisk:done (\(history.count)개)")
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
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
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: savePath)
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
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName
        let appBundleID = frontApp?.bundleIdentifier

        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            addItem(ClipboardItem(date: Date(), text: nil, fileURLs: urls, image: nil, sourceApp: appName, sourceAppBundleID: appBundleID))
            return
        }

        let text = pb.string(forType: .string)
        if let image = NSImage(pasteboard: pb), text == nil || text?.isEmpty == true {
            let imagePath = saveImage(image)
            addItem(ClipboardItem(date: Date(), text: nil, fileURLs: nil, image: image, imagePath: imagePath, sourceApp: appName, sourceAppBundleID: appBundleID))
            return
        }

        if let text = text, !text.isEmpty {
            addItem(ClipboardItem(date: Date(), text: text, fileURLs: nil, image: nil, sourceApp: appName, sourceAppBundleID: appBundleID))
        }
    }

    private func addItem(_ item: ClipboardItem) {
        // 텍스트 항목은 본문 전체로, 그 외는 displayText로 dedup.
        // displayText는 prefix 200자라 텍스트 항목엔 부적합 — 1만자 항목 두 개의 prefix만 같으면 잘못 합쳐진다.
        let newKey = item.text ?? item.displayText
        // 중복 제거 시 이전 이미지 파일도 삭제
        let removed = history.filter { ($0.text ?? $0.displayText) == newKey }
        for old in removed {
            if let path = old.imagePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        history.removeAll { ($0.text ?? $0.displayText) == newKey }

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

    private func saveImage(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }

        let filename = UUID().uuidString + ".png"
        let path = imagesDir.appendingPathComponent(filename)
        try? pngData.write(to: path)
        return path.path
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
        let path = savePath
        let work = DispatchWorkItem {
            guard let data = try? JSONEncoder().encode(items) else { return }
            try? data.write(to: path)
        }
        saveWorkItem = work
        diskQueue.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: savePath),
              let items = try? JSONDecoder().decode([SavedItem].self, from: data) else { return }
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
                image: nil,
                imagePath: saved.imagePath,
                sourceApp: saved.sourceApp,
                sourceAppBundleID: saved.sourceAppBundleID
            )
        }
    }
}
