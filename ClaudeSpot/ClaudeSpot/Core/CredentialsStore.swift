import Foundation

/// 사용자 입력 API 키의 단일 접근점.
/// UserDefaults 값이 있으면 그것을, 없으면 Constants 기본값을 반환한다.
/// Settings UI에서 값을 쓰고, Service 레이어에서 값을 읽는 방식.
/// 반영 시점은 앱 재시작 후 — Service 초기화 시 한 번 읽어 캐싱하는 구조를 가정한다.
final class CredentialsStore {
    static let shared = CredentialsStore()
    private init() {}

    private let defaults = UserDefaults.standard

    private enum Key {
        static let jiraCloudId         = "jiraCloudId"
        static let jiraEmail           = "jiraEmail"
        static let jiraApiToken        = "jiraApiToken"
        static let jiraProjectKeys     = "jiraProjectKeys"
        static let jiraProjectNames    = "jiraProjectNames"   // [String: String] — projectKey → 별칭
        static let openAIAPIKey        = "openAIAPIKey"
        static let claudeUsageEnabled  = "claudeUsageEnabled"
    }

    // MARK: - Read

    var jiraCloudId:  String { read(Key.jiraCloudId,  fallback: Constants.jiraCloudId) }
    var jiraEmail:    String { read(Key.jiraEmail,    fallback: Constants.jiraEmail) }
    var jiraApiToken: String { read(Key.jiraApiToken, fallback: Constants.jiraApiToken) }
    var openAIAPIKey: String { read(Key.openAIAPIKey, fallback: Constants.openAIAPIKey) }

    /// Jira 대시보드가 조회할 프로젝트 key 목록. UserDefaults에 저장된 값이 있으면 그것을,
    /// 없으면 Constants.defaultJiraProjectKeys 를 반환한다.
    var jiraProjectKeys: [String] {
        let stored = (defaults.stringArray(forKey: Key.jiraProjectKeys) ?? [])
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return stored.isEmpty ? Constants.defaultJiraProjectKeys : stored
    }

    /// 프로젝트 key → 표시용 별칭 매핑. 별칭이 지정되지 않은 key는 이 딕셔너리에 포함되지 않는다.
    var jiraProjectNameByKey: [String: String] {
        (defaults.dictionary(forKey: Key.jiraProjectNames) as? [String: String]) ?? [:]
    }

    /// Claude 사용량 추적 활성화 여부. 최초 기본값은 false — 사용자가 Settings에서 명시적으로 켜야 동작.
    var isClaudeUsageEnabled: Bool {
        defaults.object(forKey: Key.claudeUsageEnabled) == nil
            ? false
            : defaults.bool(forKey: Key.claudeUsageEnabled)
    }

    // MARK: - Write (Settings UI)

    func setJira(cloudId: String, email: String, token: String) {
        defaults.set(cloudId, forKey: Key.jiraCloudId)
        defaults.set(email,   forKey: Key.jiraEmail)
        defaults.set(token,   forKey: Key.jiraApiToken)
    }

    /// 대소문자/공백 정규화 후 중복을 제거한 상태로 저장한다.
    /// 빈 배열을 주면 UserDefaults에서 값을 제거해 다음 읽기부터 Constants 기본값으로 폴백.
    func setJiraProjectKeys(_ keys: [String]) {
        var seen = Set<String>()
        let cleaned: [String] = keys
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        if cleaned.isEmpty {
            defaults.removeObject(forKey: Key.jiraProjectKeys)
        } else {
            defaults.set(cleaned, forKey: Key.jiraProjectKeys)
        }
    }

    /// 프로젝트 key → 별칭 매핑을 저장한다. key는 대문자로 정규화되고,
    /// 빈 별칭은 제거된다. 결과가 비면 UserDefaults 키 자체를 삭제.
    func setJiraProjectNames(_ map: [String: String]) {
        var cleaned: [String: String] = [:]
        for (rawKey, rawName) in map {
            let key  = rawKey.trimmingCharacters(in: .whitespaces).uppercased()
            let name = rawName.trimmingCharacters(in: .whitespaces)
            if !key.isEmpty && !name.isEmpty {
                cleaned[key] = name
            }
        }
        if cleaned.isEmpty {
            defaults.removeObject(forKey: Key.jiraProjectNames)
        } else {
            defaults.set(cleaned, forKey: Key.jiraProjectNames)
        }
    }

    func setOpenAI(apiKey: String) {
        defaults.set(apiKey, forKey: Key.openAIAPIKey)
    }

    func setClaudeUsageEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.claudeUsageEnabled)
    }

    /// Jira 자격증명 + 프로젝트 목록 + 별칭을 UserDefaults에서 제거 — 다음 read부터 Constants 기본값 폴백.
    func resetJira() {
        defaults.removeObject(forKey: Key.jiraCloudId)
        defaults.removeObject(forKey: Key.jiraEmail)
        defaults.removeObject(forKey: Key.jiraApiToken)
        defaults.removeObject(forKey: Key.jiraProjectKeys)
        defaults.removeObject(forKey: Key.jiraProjectNames)
    }

    func resetOpenAI() {
        defaults.removeObject(forKey: Key.openAIAPIKey)
    }

    // MARK: - Convenience

    var isJiraConfigured: Bool {
        !jiraCloudId.isEmpty && !jiraEmail.isEmpty && !jiraApiToken.isEmpty
    }

    var isOpenAIConfigured: Bool {
        !openAIAPIKey.isEmpty
    }

    // MARK: - Helpers

    private func read(_ key: String, fallback: String) -> String {
        let stored = defaults.string(forKey: key) ?? ""
        return stored.isEmpty ? fallback : stored
    }
}
