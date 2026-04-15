import AppKit

struct AppItem: Identifiable, Hashable {
    let id: String  // bundleIdentifier 또는 path
    let name: String
    let path: URL
    let icon: NSImage

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.id == rhs.id
    }
}
