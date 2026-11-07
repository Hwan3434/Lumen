import Foundation

/// 플러그인별 디스크 캐시. `~/Library/Application Support/Lumen/schedule_cache/<plugin>.json`.
/// 앱을 다시 켜도 마지막 데이터로 즉시 그리기 위한 것이라, TTL이 있는 플러그인만 쓴다.
enum ScheduleCache {
    nonisolated struct Payload: Codable {
        let items: [ScheduleItem]
        let savedAt: Date
    }

    static func load(_ id: SchedulePluginID) -> Payload? {
        guard let data = try? Data(contentsOf: url(for: id)) else { return nil }
        return try? decoder.decode(Payload.self, from: data)
    }

    static func save(_ items: [ScheduleItem], for id: SchedulePluginID) {
        guard let data = try? encoder.encode(Payload(items: items, savedAt: Date())) else { return }
        try? data.write(to: url(for: id), options: .atomic)
    }

    static func remove(_ id: SchedulePluginID) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    private static func url(for id: SchedulePluginID) -> URL {
        LumenStorage.url(for: .scheduleCacheDir).appendingPathComponent("\(id.rawValue).json")
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
