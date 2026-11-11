import Foundation
import SwiftUI

nonisolated extension SchedulePluginID {
    static let jira = SchedulePluginID("jira")
}

/// Jira Cloud의 내 담당 이슈, 활성 스프린트, 에픽 마감. 묶음은 프로젝트 하나다.
/// 자격증명은 `PluginSecrets(.jira)`에, 프로젝트와 가져올 항목은 `JiraSettings`에 둔다.
@Observable
@MainActor
final class JiraPlugin: SchedulePlugin {
    static let shared = JiraPlugin()
    /// 미리보기 팝오버는 데이터를 받은 뒤에 뜨므로 같은 이슈를 다시 열 때 즉시 뜨도록 짧게 캐시한다.
    nonisolated static let detailCacheTTL: TimeInterval = 180

    let id = SchedulePluginID.jira
    let displayName = "Jira"
    let iconName = "square-kanban"

    var settings: JiraSettings {
        didSet { PluginSettings.save(settings, for: id) }
    }

    @ObservationIgnored private let secrets = PluginSecrets(plugin: .jira)
    @ObservationIgnored private var repository: JiraRepository?
    @ObservationIgnored private var onChange: (@MainActor () -> Void)?
    @ObservationIgnored private var detailCache: [String: (value: IssueDetail, at: Date)] = [:]
    @ObservationIgnored private var commentsCache: [String: (value: (total: Int, comments: [IssueComment]), at: Date)] = [:]

    private init() {
        settings = PluginSettings.load(.jira, default: JiraSettings())
    }

    var isEnabled: Bool { settings.enabled }
    var cacheTTL: TimeInterval? { 1800 }

    var groups: [ScheduleGroup] {
        settings.projects.map { ScheduleGroup(id: $0.key, name: $0.displayName, isVisible: $0.isVisible) }
    }

    // MARK: - 자격증명

    var workspaceSlug: String { secrets.read("workspaceSlug") ?? "" }
    var email: String { secrets.read("email") ?? "" }
    var apiToken: String { secrets.read("apiToken") ?? "" }

    var isConfigured: Bool {
        !workspaceSlug.isEmpty && !email.isEmpty && !apiToken.isEmpty
    }

    /// 브라우저용 `https://{slug}.atlassian.net/browse`. cloudId(UUID)와 다른 값이라 slug를 쓴다.
    var browseURL: URL? {
        workspaceSlug.isEmpty ? nil : URL(string: "https://\(workspaceSlug).atlassian.net/browse")
    }

    /// 도메인이 바뀌면 다른 워크스페이스일 수 있으니 cloudId 캐시를 비운다. 다음 조회에서 다시 받는다.
    /// 하나라도 쓰지 못하면 false — 설정 화면이 "저장했어요" 대신 실패를 보여 준다.
    func saveCredentials(workspaceSlug: String, email: String, apiToken: String) -> Bool {
        let cleanSlug = workspaceSlug.components(separatedBy: .whitespacesAndNewlines).joined()
        if cleanSlug != self.workspaceSlug { secrets.delete("cloudId") }
        let results = [
            secrets.write(cleanSlug, for: "workspaceSlug"),
            secrets.write(email, for: "email"),
            secrets.write(apiToken, for: "apiToken"),
        ]
        repository = nil
        invalidateIssueCaches()
        onChange?()
        return !results.contains(false)
    }

    func resetCredentials() {
        ["workspaceSlug", "email", "apiToken", "cloudId"].forEach { secrets.delete($0) }
        repository = nil
        invalidateIssueCaches()
        onChange?()
    }

    /// 연결 확인. 현재 저장된 자격증명으로 로그인한 사용자 이름을 받아 온다.
    func verifyConnection() async throws -> String {
        try await makeRepository().fetchMyself()
    }

    private func makeRepository() throws -> JiraRepository {
        if let repository { return repository }
        guard isConfigured else { throw JiraPluginError.notConfigured }
        let secrets = self.secrets
        let repo = JiraRepository(
            credentials: JiraCredentials(workspaceSlug: workspaceSlug, email: email,
                                         apiToken: apiToken, cachedCloudId: secrets.read("cloudId")),
            onCloudIdResolved: { cloudId in secrets.write(cloudId, for: "cloudId") }
        )
        repository = repo
        return repo
    }

    // MARK: - 설정

    func setEnabled(_ enabled: Bool) {
        settings.enabled = enabled
        onChange?()
    }

    /// 표시 여부는 넘어온 값이 아니라 지금 값을 지킨다. 설정 탭에서 편집하는 사이 대시보드 칩으로 바꾼 것을
    /// 저장이 덮어쓰지 않도록. 새 프로젝트는 보이는 채로 들어간다.
    func setProjects(_ projects: [JiraProjectSetting]) {
        let visible = Dictionary(settings.projects.map { ($0.key, $0.isVisible) }, uniquingKeysWith: { first, _ in first })
        settings.projects = JiraSettings.normalizedProjects(projects).map { project in
            var project = project
            project.isVisible = visible[project.key] ?? true
            return project
        }
        onChange?()
    }

    func setGroupVisible(_ groupID: String, _ visible: Bool) {
        guard let idx = settings.projects.firstIndex(where: { $0.key == groupID }) else { return }
        settings.projects[idx].isVisible = visible
    }

    func setShowSprints(_ on: Bool) {
        settings.showSprints = on
        onChange?()
    }

    func setShowEpics(_ on: Bool) {
        settings.showEpics = on
        onChange?()
    }

    func setShowDone(_ on: Bool) {
        settings.showDone = on
        onChange?()
    }

    // MARK: - SchedulePlugin

    func fetch(window: DateInterval) async throws -> [ScheduleItem] {
        guard settings.enabled else { return [] }
        let repo = try makeRepository()
        let keys = settings.projects.map(\.key)
        guard !keys.isEmpty else { return [] }
        let settings = self.settings
        let browse = browseURL

        async let issues = repo.fetchIssues(projectKeys: keys, window: window)
        async let sprints: [SprintInfo] = settings.showSprints ? try await repo.fetchActiveSprints(projectKeys: keys) : []
        async let epics: [JiraIssue] = settings.showEpics ? try await repo.fetchEpics(projectKeys: keys, window: window) : []
        let items = Self.makeItems(issues: try await issues, sprints: try await sprints, epics: try await epics,
                                   settings: settings, browseURL: browse)
        // 이슈를 새로 받으면 내용도 바뀌었을 수 있으니 상세 캐시를 함께 버린다.
        invalidateIssueCaches()
        return items
    }

    func startObserving(_ onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    func detailView(for item: ScheduleItem, accent: Color, variant: ScheduleDetailVariant,
                    dismiss: @escaping @MainActor () -> Void) async throws -> AnyView? {
        guard item.kind != .span, let key = Self.issueKey(of: item) else { return nil }
        switch variant {
        case .primary:
            let detail = try await issueDetail(key: key)
            return AnyView(IssuePreviewPopover(detail: detail, accent: accent, openURL: item.url))
        case .secondary:
            let page = try await comments(key: key)
            return AnyView(IssueCommentsPopover(issueKey: key, total: page.total, comments: page.comments))
        }
    }

    var hasSettingsTab: Bool { true }

    func makeSettingsTab(action: SettingsActionViewModel) -> AnyView {
        AnyView(JiraSettingsTab(plugin: self, action: action))
    }

    // MARK: - 상세 캐시

    private func issueDetail(key: String) async throws -> IssueDetail {
        if let hit = detailCache[key], Date().timeIntervalSince(hit.at) < Self.detailCacheTTL {
            return hit.value
        }
        let detail = try await makeRepository().fetchIssueDetail(key: key)
        detailCache[key] = (detail, Date())
        return detail
    }

    private func comments(key: String) async throws -> (total: Int, comments: [IssueComment]) {
        if let hit = commentsCache[key], Date().timeIntervalSince(hit.at) < Self.detailCacheTTL {
            return hit.value
        }
        let page = try await makeRepository().fetchComments(key: key)
        commentsCache[key] = (page, Date())
        return page
    }

    private func invalidateIssueCaches() {
        detailCache.removeAll()
        commentsCache.removeAll()
    }

    // MARK: - 항목 변환 (순수 함수)

    /// 항목 id "jira.<이슈 키>"에서 키를 꺼낸다. 스프린트는 "jira.sprint.<프로젝트 키>.<id>"라 호출자가 kind로 먼저 거른다.
    nonisolated static func issueKey(of item: ScheduleItem) -> String? {
        guard item.plugin == .jira, item.id.hasPrefix("jira.") else { return nil }
        return String(item.id.dropFirst("jira.".count))
    }

    /// 이슈·스프린트·에픽을 공통 항목으로. 시작일과 마감일이 모두 없는 이슈는 캘린더에 둘 곳이 없어 뺀다.
    nonisolated static func makeItems(issues: [JiraIssue], sprints: [SprintInfo], epics: [JiraIssue],
                                      settings: JiraSettings, browseURL: URL?) -> [ScheduleItem] {
        var items: [ScheduleItem] = []
        var seenKeys = Set<String>()

        for sprint in sprints {
            guard let start = sprint.startDate, let end = sprint.endDate else { continue }
            items.append(ScheduleItem(
                // 두 프로젝트가 보드를 같이 쓰면 같은 스프린트가 프로젝트마다 한 번씩 온다. 프로젝트 키를 넣어 id가 겹치지 않게 한다.
                id: "jira.sprint.\(sprint.projectKey).\(sprint.id)",
                plugin: .jira,
                group: sprint.projectKey,
                title: sprint.name,
                start: start,
                end: end,
                isAllDay: true,
                kind: .span,
                subtitle: "스프린트"
            ))
        }

        for issue in issues {
            guard seenKeys.insert(issue.key).inserted else { continue }
            if issue.isDone && !settings.showDone { continue }
            guard let item = makeIssueItem(issue, browseURL: browseURL) else { continue }
            items.append(item)
        }

        // 내 담당이기도 한 에픽은 위에서 이미 들어갔다.
        for epic in epics where !seenKeys.contains(epic.key) {
            seenKeys.insert(epic.key)
            guard let item = makeIssueItem(epic, browseURL: browseURL) else { continue }
            items.append(item)
        }

        return items
    }

    private nonisolated static func makeIssueItem(_ issue: JiraIssue, browseURL: URL?) -> ScheduleItem? {
        guard issue.startDate != nil || issue.dueDate != nil else { return nil }
        let start = issue.startDate ?? issue.dueDate!
        var end: Date? = nil
        if let s = issue.startDate, let d = issue.dueDate, !Calendar.current.isDate(s, inSameDayAs: d) {
            end = d
        }
        let isEpic = issue.issueType.caseInsensitiveCompare("Epic") == .orderedSame
        return ScheduleItem(
            id: "jira.\(issue.key)",
            plugin: .jira,
            group: issue.projectKey,
            title: issue.summary,
            start: start,
            end: end,
            isAllDay: true,
            kind: .task,
            status: status(of: issue.statusCategory),
            priority: priority(of: issue.priority),
            subtitle: isEpic ? "\(issue.key) · 에픽" : issue.key,
            url: browseURL?.appendingPathComponent(issue.key)
        )
    }

    nonisolated static func status(of category: JiraStatusCategory) -> ScheduleItem.Status {
        switch category {
        case .new, .undefined: return .todo
        case .indeterminate:   return .inProgress
        case .done:            return .done
        }
    }

    nonisolated static func priority(of name: String) -> ScheduleItem.Priority? {
        switch name {
        case "Highest": return .urgent
        case "High":    return .high
        default:        return nil
        }
    }
}

nonisolated enum JiraPluginError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Jira 연결 정보가 없어요. 설정 › 일정 › Jira에서 도메인, 이메일, API 토큰을 넣어 주세요."
        }
    }
}
