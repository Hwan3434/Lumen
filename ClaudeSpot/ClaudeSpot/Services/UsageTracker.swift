import Foundation

final class UsageTracker {
    private let key = "ClaudeSpot.appUsageCounts"
    private var cache: [String: Int]

    init() {
        cache = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
    }

    func recordUsage(for appID: String) {
        cache[appID, default: 0] += 1
        UserDefaults.standard.set(cache, forKey: key)
    }

    func usageCount(for appID: String) -> Int {
        cache[appID] ?? 0
    }
}
