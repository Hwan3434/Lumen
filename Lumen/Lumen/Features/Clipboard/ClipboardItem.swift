import AppKit

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
