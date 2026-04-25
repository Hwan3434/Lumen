import Foundation

final class HiddenAppsManager {
    static let shared = HiddenAppsManager()

    private let fileURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Lumen")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("hidden_apps.json")
    }()

    private var hiddenIDs: Set<String>

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            hiddenIDs = ids
        } else {
            hiddenIDs = []
        }
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
        guard let data = try? JSONEncoder().encode(hiddenIDs) else { return }
        try? data.write(to: fileURL)
    }
}
