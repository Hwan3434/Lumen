import AppKit

struct AppItem: Identifiable, Hashable {
    let id: String
    let name: String
    let path: URL
    let aliases: [String]

    @MainActor var icon: NSImage { AppIconCache.icon(for: path) }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AppItem, rhs: AppItem) -> Bool { lhs.id == rhs.id }
}

@MainActor
enum AppIconCache {
    private static var cache: [String: NSImage] = [:]

    static func icon(for path: URL) -> NSImage {
        let key = path.path
        if let cached = cache[key] { return cached }
        let image = NSWorkspace.shared.icon(forFile: key)
        image.size = NSSize(width: 32, height: 32)
        cache[key] = image
        return image
    }
}
