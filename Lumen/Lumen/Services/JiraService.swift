import Foundation
import Observation

// MARK: - Models

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
    let resolutionDate: Date?
    let created: Date?
    let issueType: String
    let projectKey: String

    var isDone: Bool { statusCategory == .done }
}

nonisolated struct JiraStatusCounts {
    var todo: Int = 0
    var inProgress: Int = 0
    var done: Int = 0

    mutating func add(_ category: JiraStatusCategory) {
        switch category {
        case .new: todo += 1
        case .indeterminate: inProgress += 1
        case .done: done += 1
        case .undefined: todo += 1
        }
    }
}

nonisolated struct ProjectWeekStats: Identifiable {
    var id: String { key }
    let key: String
    let counts: JiraStatusCounts
}

nonisolated struct SprintInfo: Identifiable {
    let id: Int
    let name: String
    let startDate: Date?
    let endDate: Date?
    let projectKey: String
    let totalIssues: Int
    let completedIssues: Int
    var completionPct: Int { totalIssues > 0 ? Int(Double(completedIssues) / Double(totalIssues) * 100) : 0 }
}

nonisolated struct EpicInfo: Identifiable {
    var id: String { key }
    let key: String
    let summary: String
    let projectKey: String
    let status: String
    let dueDate: Date?
}

nonisolated struct JiraDashboardData {
    let thisWeekCounts: JiraStatusCounts
    let projectStats: [ProjectWeekStats]
    let todayIssues: [JiraIssue]
    let thisWeekIssues: [JiraIssue]
    let highestIncomplete: [JiraIssue]
    let overdueIncomplete: [JiraIssue]
    let completedLast30: [JiraIssue]
    let createdLast30: [JiraIssue]
    let nextWeekIssues: [JiraIssue]
    let backlogCountByProject: [String: Int]
    let sprintInfos: [SprintInfo]
    let epicInfos: [EpicInfo]
    /// ±3개월 윈도우에 걸친 자기 담당 이슈 전체. 캘린더(월간/타임라인)의 단일 데이터 소스이며,
    /// 위쪽 필드들(thisWeek/highest/overdue/...)은 이걸 클라이언트 필터링해서 만든다.
    let allIssuesInWindow: [JiraIssue]
    let lastUpdated: Date
}

/// 단건 이슈 미리보기용 — 전체 이슈 fetch에 description/comments는 빠져 있어서
/// 알약/막대 클릭 시점에 lazy로 받아 popover에 띄운다.
nonisolated struct IssueDetail {
    let key: String
    let summary: String
    let status: String
    let descriptionText: String
    let commentCount: Int
}

// MARK: - Service

@Observable
@MainActor
final class JiraService {
    static let shared = JiraService()

    /// Jira 기능이 살아있는지 — 사용자가 Settings에서 켰고(`isJiraEnabled`)
    /// 자격증명도 모두 채워져야(`isJiraConfigured`) true.
    static var isAvailable: Bool {
        let store = CredentialsStore.shared
        return store.isJiraEnabled && store.isJiraConfigured
    }

    var data: JiraDashboardData?
    var isLoading = false
    var errorMessage: String?

    private let repository: JiraRepository
    private var projectKeys: [String] { Constants.jiraProjects.map(\.key) }

    private init() {
        let store = CredentialsStore.shared
        let cachedCloudId = store.jiraCloudId.isEmpty ? nil : store.jiraCloudId
        self.repository = JiraRepository(
            credentials: JiraCredentials(
                workspaceSlug: store.jiraWorkspaceSlug,
                email: store.jiraEmail,
                apiToken: store.jiraApiToken,
                cachedCloudId: cachedCloudId
            )
        )
    }

    func fetch(force: Bool = false) async {
        guard Self.isAvailable else {
            errorMessage = "Jira API 토큰이 설정되지 않았습니다."
            return
        }

        if !force, let existing = data, Date().timeIntervalSince(existing.lastUpdated) < 1800 {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            data = try await repository.fetchDashboard(projectKeys: projectKeys)
            isLoading = false
        } catch {
            errorMessage = error.networkErrorMessage
            isLoading = false
        }
    }

    func fetchIssueDetail(key: String) async throws -> IssueDetail {
        try await repository.fetchIssueDetail(key: key)
    }
}
