import AppKit

struct AppItem: Identifiable, Hashable {
    let id: String
    let name: String
    let path: URL
    let aliases: [String]

    @MainActor var icon: NSImage { AppIconCache.icon(for: path) }
    /// 상세 칸의 큰 아이콘. 목록용 32pt 이미지를 늘리면 흐려서 따로 받는다.
    @MainActor var largeIcon: NSImage { AppIconCache.icon(for: path, side: 128) }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AppItem, rhs: AppItem) -> Bool { lhs.id == rhs.id }
}

@MainActor
enum AppIconCache {
    private static var cache: [String: NSImage] = [:]

    static func icon(for path: URL, side: CGFloat = 32) -> NSImage {
        let key = "\(path.path)|\(side)"
        if let cached = cache[key] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path.path)
        image.size = NSSize(width: side, height: side)
        cache[key] = image
        return image
    }
}
