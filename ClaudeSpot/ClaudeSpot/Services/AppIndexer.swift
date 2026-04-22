import AppKit

final class AppIndexer {
    private var cachedApps: [AppItem] = []

    func loadApps() -> [AppItem] {
        if !cachedApps.isEmpty { return cachedApps }

        AppResourceMonitor.trace("AppIndexer:loadApps:enter")

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
            appendApp(at: url, into: &apps, seen: &seen)
        }

        for dir in directories {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                appendApp(at: url, into: &apps, seen: &seen)
            }
        }

        cachedApps = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        AppResourceMonitor.trace("AppIndexer:loadApps:exit(\(cachedApps.count))")
        return cachedApps
    }

    private func appendApp(at url: URL, into apps: inout [AppItem], seen: inout Set<String>) {
        let bundle = Bundle(url: url)
        let bundleID = bundle?.bundleIdentifier ?? url.path
        guard !seen.contains(bundleID) else { return }
        seen.insert(bundleID)

        let displayName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle?.infoDictionary?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent

        apps.append(AppItem(
            id: bundleID,
            name: displayName,
            path: url,
            aliases: Constants.appAliases[bundleID] ?? []
        ))
    }

    func reload() {
        cachedApps = []
        _ = loadApps()
    }
}
