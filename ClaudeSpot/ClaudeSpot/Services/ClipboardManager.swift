import AppKit
import Observation

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let text: String?
    let fileURLs: [URL]?
    let image: NSImage?
    let imagePath: String?
    let sourceApp: String?
    let sourceAppBundleID: String?

    init(id: UUID = UUID(), date: Date, text: String?, fileURLs: [URL]?, image: NSImage?, imagePath: String? = nil, sourceApp: String? = nil, sourceAppBundleID: String? = nil) {
        self.id = id
        self.date = date
        self.text = text
        self.fileURLs = fileURLs
        self.image = image
        self.imagePath = imagePath
        self.sourceApp = sourceApp
        self.sourceAppBundleID = sourceAppBundleID
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

    var displayText: String {
        if let text = text, !text.isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let urls = fileURLs, !urls.isEmpty {
            return urls.map { $0.lastPathComponent }.joined(separator: ", ")
        }
        if image != nil || imagePath != nil {
            return "[이미지]"
        }
        return "[알 수 없는 항목]"
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

    private let baseDir: URL
    private let savePath: URL
    private let imagesDir: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let base = appSupport.appendingPathComponent("ClaudeSpot")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.baseDir = base
        self.savePath = base.appendingPathComponent("clipboard_history.json")
        let imgs = base.appendingPathComponent("images")
        try? FileManager.default.createDirectory(at: imgs, withIntermediateDirectories: true)
        self.imagesDir = imgs
    }

    func startMonitoring() {
        loadFromDisk()
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
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
        // 중복 제거 시 이전 이미지 파일도 삭제
        let removed = history.filter { $0.displayText == item.displayText }
        for old in removed {
            if let path = old.imagePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        history.removeAll { $0.displayText == item.displayText }

        history.insert(item, at: 0)

        // 초과분 이미지 삭제
        while history.count > maxItems {
            let removed = history.removeLast()
            if let path = removed.imagePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }

        saveToDisk()
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

    private func saveToDisk() {
        let items: [SavedItem] = history.map { item in
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
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: savePath)
        }
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
