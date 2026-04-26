import Foundation

final class HiddenAppsManager {
    static let shared = HiddenAppsManager()

    private let fileURL: URL = LumenStorage.url(for: .hiddenApps)

    private var hiddenIDs: Set<String>

    private init() {
        hiddenIDs = LumenStorage.read(Set<String>.self, from: .hiddenApps) ?? []
    }

    func isHidden(_ bundleID: String) -> Bool {
        hiddenIDs.contains(bundleID)
    }

    func hide(_ bundleID: String) {
        hiddenIDs.insert(bundleID)
        save()
    }

    func unhide(_ bundleID: String) {
        hiddenIDs.remove(bundleID)
        save()
    }

    private func save() {
        LumenStorage.write(hiddenIDs, to: .hiddenApps)
    }
}
