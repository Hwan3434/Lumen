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
        static let openAIAPIKey        = "openAIAPIKey"
        static let claudeUsageEnabled  = "claudeUsageEnabled"
    }

    // MARK: - Read

    var jiraCloudId:  String { read(Key.jiraCloudId,  fallback: Constants.jiraCloudId) }
    var jiraEmail:    String { read(Key.jiraEmail,    fallback: Constants.jiraEmail) }
    var jiraApiToken: String { read(Key.jiraApiToken, fallback: Constants.jiraApiToken) }
    var openAIAPIKey: String { read(Key.openAIAPIKey, fallback: Constants.openAIAPIKey) }

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

    func setOpenAI(apiKey: String) {
        defaults.set(apiKey, forKey: Key.openAIAPIKey)
    }

    func setClaudeUsageEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.claudeUsageEnabled)
    }

    /// Jira 자격증명 3개를 UserDefaults에서 제거 — 다음 read부터 Constants 기본값 폴백.
    func resetJira() {
        defaults.removeObject(forKey: Key.jiraCloudId)
        defaults.removeObject(forKey: Key.jiraEmail)
        defaults.removeObject(forKey: Key.jiraApiToken)
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
