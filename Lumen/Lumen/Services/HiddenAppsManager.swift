import Foundation
import Observation

@Observable
final class HiddenAppsManager {
    @MainActor static let shared = HiddenAppsManager()

    private(set) var hiddenIDs: Set<String>

    private init() {
        hiddenIDs = LumenStorage.read(Set<String>.self, from: .hiddenApps) ?? []
    }

    func isHidden(_ bundleID: String) -> Bool {
        hiddenIDs.contains(bundleID)
    }

    func hide(_ bundleID: String) {
        guard !hiddenIDs.contains(bundleID) else { return }
        hiddenIDs.insert(bundleID)
        save()
    }

    func unhide(_ bundleID: String) {
        guard hiddenIDs.contains(bundleID) else { return }
        hiddenIDs.remove(bundleID)
        save()
    }

    private func save() {
        LumenStorage.write(hiddenIDs, to: .hiddenApps)
    }
}
