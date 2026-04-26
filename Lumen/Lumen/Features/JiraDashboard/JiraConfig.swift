import SwiftUI

struct JiraProject {
    let key: String
    /// 사용자가 Settings에서 지정한 표시용 별칭. 빈 문자열이면 별칭 없음.
    let name: String
    let color: Color

    /// UI에서 우선 표기할 이름 — 별칭이 있으면 별칭, 없으면 key.
    var displayName: String { name.isEmpty ? key : name }
}

extension Constants {
    // MARK: - Jira credentials placeholder defaults
    static let jiraCloudId          = ""
    static let jiraEmail            = ""
    static let jiraApiToken         = ""

    /// UserDefaults에 값이 없을 때 쓰이는 기본 프로젝트 목록.
    /// 비워두면 사용자가 Settings에서 명시적으로 등록할 때까지 대시보드는 빈 상태.
    static let defaultJiraProjectKeys: [String] = []

    /// 프로젝트 색상은 등록 순서에 따라 palette에서 순환 할당된다.
    static let jiraProjectPalette: [Color] = [.cyan, .purple, .orange, .green, .pink, .yellow, .teal, .red]

    /// 대시보드/서비스가 참조하는 실제 프로젝트 목록.
    /// CredentialsStore(= UserDefaults)의 key 배열과 별칭 매핑 기준으로 매번 생성된다.
    static var jiraProjects: [JiraProject] {
        let store = CredentialsStore.shared
        let keys = store.jiraProjectKeys
        let names = store.jiraProjectNameByKey
        return keys.enumerated().map { idx, key in
            JiraProject(
                key: key,
                name: names[key] ?? "",
                color: jiraProjectPalette[idx % jiraProjectPalette.count]
            )
        }
    }

    /// Jira browse URL prefix — 사용자 cloudId(=`{tenant}`)에 따라 매번 다르므로
    /// 사용자가 Settings에 입력한 값으로 동적 생성한다. 잘못/미입력 시 빈 문자열.
    static var jiraBrowseURL: String {
        let cloudId = CredentialsStore.shared.jiraCloudId
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cloudId.isEmpty else { return "" }
        return "https://\(cloudId).atlassian.net/browse/"
    }

    /// Jira "Start date" 커스텀 필드 ID
    static let jiraStartDateFieldId = "customfield_10015"
    /// JQL에서의 동일 필드 표현
    static let jiraStartDateJQL     = "\"Start date\""
}
