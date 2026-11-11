import Foundation

/// 플러그인별 디스크 캐시. `~/Library/Application Support/Lumen/schedule_cache/<plugin>.json`.
/// 앱을 다시 켜도 마지막 데이터로 즉시 그리기 위한 것이라, TTL이 있는 플러그인만 쓴다.
enum ScheduleCache {
    nonisolated struct Payload: Codable {
        let items: [ScheduleItem]
        let savedAt: Date
    }

    static func load(_ id: SchedulePluginID) -> Payload? {
        LumenStorage.read(Payload.self, from: url(for: id), decoder: decoder)
    }

    static func save(_ items: [ScheduleItem], for id: SchedulePluginID) {
        LumenStorage.write(Payload(items: items, savedAt: Date()), to: url(for: id), encoder: encoder)
    }

    static func remove(_ id: SchedulePluginID) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    /// 테스트가 임시 폴더로 바꾼다 — 실제 캐시 폴더를 건드리지 않게.
    static var directory = LumenStorage.url(for: .scheduleCacheDir)

    private static func url(for id: SchedulePluginID) -> URL {
        directory.appendingPathComponent("\(id.rawValue).json")
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
