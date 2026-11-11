import Foundation

/// 플러그인별 비민감 설정. Codable 구조체 하나를 UserDefaults 키 `schedule.<plugin>`에 JSON으로 둔다.
enum PluginSettings {
    static func load<T: Decodable>(_ id: SchedulePluginID, default fallback: T) -> T {
        load(key: key(for: id), default: fallback)
    }

    static func save<T: Encodable>(_ value: T, for id: SchedulePluginID) {
        save(value, key: key(for: id))
    }

    static func load<T: Decodable>(key: String, default fallback: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(T.self, from: data) else { return fallback }
        return value
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func key(for id: SchedulePluginID) -> String { "schedule.\(id.rawValue)" }
}

/// 플러그인별 민감값. `SecretStore`에 "<plugin>.<이름>" 키로 두어 플러그인이 자기 것만 본다.
struct PluginSecrets {
    let plugin: SchedulePluginID

    func read(_ name: String) -> String? {
        SecretStore.read(key(name))
    }

    /// 붙여넣기 때 끼어드는 공백·줄바꿈을 지우고 저장한다. 빈 값은 지운다.
    @discardableResult
    func write(_ value: String, for name: String) -> Bool {
        SecretStore.write(value.components(separatedBy: .whitespacesAndNewlines).joined(), for: key(name))
    }

    func delete(_ name: String) {
        SecretStore.delete(key(name))
    }

    private func key(_ name: String) -> String { "\(plugin.rawValue).\(name)" }
}
