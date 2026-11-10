import Foundation

/// Atlassian의 표준 statusCategory — 워크스페이스/언어 무관한 4분류 식별자.
/// API의 raw string을 그대로 들고 다니지 않도록 디코드 시점에 변환한다.
nonisolated enum JiraStatusCategory: String {
    case new
    case indeterminate
    case done
    case undefined

    init(rawAPIKey: String) {
        self = JiraStatusCategory(rawValue: rawAPIKey) ?? .undefined
    }
}

nonisolated struct JiraIssue: Identifiable {
    let id: String
    let key: String
    let summary: String
    /// 워크스페이스 status 라벨 원문 (예: "In Progress", "진행중", "Code Review"). 표시 전용.
    let status: String
    /// 분류·필터링은 모두 이 값으로 한다.
    let statusCategory: JiraStatusCategory
    let priority: String
    let startDate: Date?
    let dueDate: Date?
    let issueType: String
    let projectKey: String

    var isDone: Bool { statusCategory == .done }
}

nonisolated struct SprintInfo: Identifiable {
    let id: Int
    let name: String
    let startDate: Date?
    let endDate: Date?
    let projectKey: String
}

/// 단건 이슈 미리보기용 — 전체 이슈 조회에 description/comments는 빠져 있어서
/// 막대를 눌렀을 때 따로 받아 팝오버에 띄운다.
nonisolated struct IssueComment: Identifiable {
    let id: String
    let author: String
    let created: Date?
    let bodyText: String
}

nonisolated struct IssueDetail {
    let key: String
    let summary: String
    let status: String
    let descriptionText: String
    /// 댓글 내용은 ⌘클릭 댓글 팝오버가 따로 받는다. 미리보기는 개수만 보여 준다.
    let commentCount: Int
}

// MARK: - 설정

nonisolated struct JiraProjectSetting: Codable, Hashable, Identifiable {
    var key: String
    /// 표시용 별칭. 비우면 키가 그대로 보인다.
    var alias: String = ""
    var isVisible: Bool = true

    var id: String { key }
    var displayName: String { alias.isEmpty ? key : alias }
}

nonisolated struct JiraSettings: Codable, Equatable {
    var enabled = false
    var projects: [JiraProjectSetting] = []
    /// 진행 중 스프린트를 캘린더 기간 막대로.
    var showSprints = true
    /// 마감일 있는 열린 에픽을 마감일에.
    var showEpics = true
    /// 끄면 완료한 이슈는 목록과 캘린더에서 숨긴다.
    var showDone = false

    /// 키는 대문자, 공백 제거, 중복 제거, 빈 키 제거. 별칭은 양끝 공백만 다듬는다.
    static func normalizedProjects(_ raw: [JiraProjectSetting]) -> [JiraProjectSetting] {
        var seen = Set<String>()
        return raw.compactMap { project in
            let key = project.key.trimmingCharacters(in: .whitespaces).uppercased()
            guard !key.isEmpty, seen.insert(key).inserted else { return nil }
            return JiraProjectSetting(
                key: key,
                alias: project.alias.trimmingCharacters(in: .whitespaces),
                isVisible: project.isVisible
            )
        }
    }
}
