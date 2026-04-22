import Foundation

final class UsageTracker {
    private let key = "ClaudeSpot.appUsageCounts"
    private var cache: [String: Int]

    init() {
        cache = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
    }

    func recordUsage(for appID: String) {
        AppResourceMonitor.trace("UsageTracker:recordUsage:enter")
        cache[appID, default: 0] += 1
        UserDefaults.standard.set(cache, forKey: key)
        AppResourceMonitor.trace("UsageTracker:recordUsage:exit")
    }

    func usageCount(for appID: String) -> Int {
        cache[appID] ?? 0
    }
}
