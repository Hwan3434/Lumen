import AppKit

final class AppIndexer {
    private var cachedApps: [AppItem] = []

    func loadApps() -> [AppItem] {
        if !cachedApps.isEmpty { return cachedApps }

        var apps: [AppItem] = []
        var seen = Set<String>()

        let directories = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
        ]

        // CoreServices 전체 탐색 시 시스템 에이전트가 딸려오므로 필요한 앱만 직접 추가
        let individualApps = [
            URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
        ]

        for url in individualApps where url.pathExtension == "app" {
            let bundle = Bundle(url: url)
            let bundleID = bundle?.bundleIdentifier ?? url.path
            guard !seen.contains(bundleID) else { continue }
            seen.insert(bundleID)

            let displayName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle?.infoDictionary?["CFBundleName"] as? String
                ?? url.deletingPathExtension().lastPathComponent

            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 32, height: 32)

            apps.append(AppItem(id: bundleID, name: displayName, path: url, icon: icon))
        }

        for dir in directories {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                let bundle = Bundle(url: url)
                let bundleID = bundle?.bundleIdentifier ?? url.path
                guard !seen.contains(bundleID) else { continue }
                seen.insert(bundleID)

                let displayName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? bundle?.infoDictionary?["CFBundleName"] as? String
                    ?? url.deletingPathExtension().lastPathComponent

                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 32, height: 32)

                apps.append(AppItem(id: bundleID, name: displayName, path: url, icon: icon))
            }
        }

        cachedApps = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return cachedApps
    }

    func reload() {
        cachedApps = []
        _ = loadApps()
    }
}
