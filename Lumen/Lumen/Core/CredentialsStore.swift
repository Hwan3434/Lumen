import Foundation

/// 사용자 입력 자격증명의 단일 접근점.
/// 민감 값(Jira/OpenAI 토큰)은 Keychain에, 비-민감 설정(프로젝트 목록·별칭, 토글)은 UserDefaults에 둔다.
/// Settings UI에서 값을 쓰고, Service 레이어에서 값을 읽는다.
/// 반영 시점은 앱 재시작 후 — Service 초기화 시 한 번 읽어 캐싱하는 구조를 가정한다.
final class CredentialsStore {
    static let shared = CredentialsStore()

    private init() {
        migrateLegacyPlaintextIfNeeded()
    }

    private let defaults = UserDefaults.standard

    private enum KCAccount {
        static let jiraCloudId       = "jiraCloudId"
        static let jiraWorkspaceSlug = "jiraWorkspaceSlug"
        static let jiraEmail         = "jiraEmail"
        static let jiraApiToken      = "jiraApiToken"
        static let openAIAPIKey      = "openAIAPIKey"
    }

    private enum UDKey {
        static let jiraProjectKeys     = "jiraProjectKeys"
        static let jiraProjectNames    = "jiraProjectNames"   // [String: String] — projectKey → 별칭
        static let claudeUsageEnabled  = "claudeUsageEnabled"
        static let jiraEnabled         = "jiraEnabled"
        static let openAIEnabled       = "openAIEnabled"
        static let didMigrateKeychain  = "didMigrateKeychainV1"
    }

    // MARK: - Read

    /// Atlassian Cloud ID (=tenantId, UUID 형태). API path에 들어간다:
    /// `https://api.atlassian.com/ex/jira/{cloudId}/rest/api/3/...`
    var jiraCloudId:        String { Keychain.read(KCAccount.jiraCloudId)       ?? Constants.jiraCloudId  }
    /// 워크스페이스 URL slug (브라우저 표기용). `https://{slug}.atlassian.net/browse/...`
    var jiraWorkspaceSlug:  String { Keychain.read(KCAccount.jiraWorkspaceSlug) ?? "" }
    var jiraEmail:          String { Keychain.read(KCAccount.jiraEmail)         ?? Constants.jiraEmail    }
    var jiraApiToken:       String { Keychain.read(KCAccount.jiraApiToken)      ?? Constants.jiraApiToken }
    var openAIAPIKey:       String { Keychain.read(KCAccount.openAIAPIKey)      ?? Constants.openAIAPIKey }

    /// Jira 대시보드가 조회할 프로젝트 key 목록. UserDefaults에 저장된 값이 있으면 그것을,
    /// 없으면 Constants.defaultJiraProjectKeys 를 반환한다.
    var jiraProjectKeys: [String] {
        let stored = (defaults.stringArray(forKey: UDKey.jiraProjectKeys) ?? [])
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return stored.isEmpty ? Constants.defaultJiraProjectKeys : stored
    }

    /// 프로젝트 key → 표시용 별칭 매핑. 별칭이 지정되지 않은 key는 이 딕셔너리에 포함되지 않는다.
    var jiraProjectNameByKey: [String: String] {
        (defaults.dictionary(forKey: UDKey.jiraProjectNames) as? [String: String]) ?? [:]
    }

    /// Claude 사용량 추적 활성화 여부. 최초 기본값은 false — 사용자가 Settings에서 명시적으로 켜야 동작.
    var isClaudeUsageEnabled: Bool {
        defaults.object(forKey: UDKey.claudeUsageEnabled) == nil
            ? false
            : defaults.bool(forKey: UDKey.claudeUsageEnabled)
    }

    /// Jira 기능 사용 여부. 자격증명과 별개로 사용자가 명시적으로 켜야 활성화된다.
    /// OFF면 자격증명이 채워져 있어도 feature가 isEnabled=false가 되어 핫키·메뉴·검색
    /// 어디에도 노출되지 않는다. 토글을 꺼도 자격증명은 보존된다.
    var isJiraEnabled: Bool {
        defaults.object(forKey: UDKey.jiraEnabled) == nil
            ? false
            : defaults.bool(forKey: UDKey.jiraEnabled)
    }

    /// OpenAI(Translator) 사용 여부. Jira와 같은 정책.
    var isOpenAIEnabled: Bool {
        defaults.object(forKey: UDKey.openAIEnabled) == nil
            ? false
            : defaults.bool(forKey: UDKey.openAIEnabled)
    }

    // MARK: - Write (Settings UI)

    func setJira(cloudId: String, workspaceSlug: String, email: String, token: String) {
        Keychain.write(sanitize(cloudId),       for: KCAccount.jiraCloudId)
        Keychain.write(sanitize(workspaceSlug), for: KCAccount.jiraWorkspaceSlug)
        Keychain.write(sanitize(email),         for: KCAccount.jiraEmail)
        Keychain.write(sanitize(token),         for: KCAccount.jiraApiToken)
    }

    /// 대소문자/공백 정규화 후 중복을 제거한 상태로 저장한다.
    /// 빈 배열을 주면 UserDefaults에서 값을 제거해 다음 읽기부터 Constants 기본값으로 폴백.
    func setJiraProjectKeys(_ keys: [String]) {
        var seen = Set<String>()
        let cleaned: [String] = keys
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        if cleaned.isEmpty {
            defaults.removeObject(forKey: UDKey.jiraProjectKeys)
        } else {
            defaults.set(cleaned, forKey: UDKey.jiraProjectKeys)
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
            defaults.removeObject(forKey: UDKey.jiraProjectNames)
        } else {
            defaults.set(cleaned, forKey: UDKey.jiraProjectNames)
        }
    }

    func setOpenAI(apiKey: String) {
        Keychain.write(sanitize(apiKey), for: KCAccount.openAIAPIKey)
    }

    /// 붙여넣기 시 끼어 들어가는 줄바꿈·공백·탭을 제거. API 호출 시 401의 흔한 원인.
    private func sanitize(_ raw: String) -> String {
        raw.components(separatedBy: .whitespacesAndNewlines).joined()
    }

    func setClaudeUsageEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: UDKey.claudeUsageEnabled)
    }

    func setJiraEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: UDKey.jiraEnabled)
    }

    func setOpenAIEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: UDKey.openAIEnabled)
    }

    /// Jira 자격증명 + 프로젝트 목록 + 별칭을 제거 — 다음 read부터 Constants 기본값 폴백.
    func resetJira() {
        Keychain.delete(KCAccount.jiraCloudId)
        Keychain.delete(KCAccount.jiraWorkspaceSlug)
        Keychain.delete(KCAccount.jiraEmail)
        Keychain.delete(KCAccount.jiraApiToken)
        defaults.removeObject(forKey: UDKey.jiraProjectKeys)
        defaults.removeObject(forKey: UDKey.jiraProjectNames)
    }

    func resetOpenAI() {
        Keychain.delete(KCAccount.openAIAPIKey)
    }

    // MARK: - Convenience

    var isJiraConfigured: Bool {
        !jiraCloudId.isEmpty
            && !jiraWorkspaceSlug.isEmpty
            && !jiraEmail.isEmpty
            && !jiraApiToken.isEmpty
    }

    var isOpenAIConfigured: Bool {
        !openAIAPIKey.isEmpty
    }

    // MARK: - Migration

    /// 0.1.x 이전 버전이 UserDefaults에 평문으로 저장한 값을 Keychain으로 옮긴 뒤 원본을 삭제.
    /// 한 번 성공하면 플래그를 세워 다시 실행되지 않는다.
    private func migrateLegacyPlaintextIfNeeded() {
        guard !defaults.bool(forKey: UDKey.didMigrateKeychain) else { return }

        let pairs: [(udKey: String, account: String)] = [
            ("jiraCloudId",  KCAccount.jiraCloudId),
            ("jiraEmail",    KCAccount.jiraEmail),
            ("jiraApiToken", KCAccount.jiraApiToken),
            ("openAIAPIKey", KCAccount.openAIAPIKey),
        ]

        for (udKey, account) in pairs {
            guard let legacy = defaults.string(forKey: udKey), !legacy.isEmpty else { continue }
            // Keychain에 이미 값이 있으면(예: 다른 디바이스/이전 설치) 덮어쓰지 않는다.
            if Keychain.read(account) == nil {
                Keychain.write(legacy, for: account)
            }
            defaults.removeObject(forKey: udKey)
        }

        defaults.set(true, forKey: UDKey.didMigrateKeychain)
    }
}
