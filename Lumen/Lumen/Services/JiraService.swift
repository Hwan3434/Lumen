import Foundation

// MARK: - Models

struct JiraIssue: Identifiable {
    let id: String
    let key: String
    let summary: String
    let status: String
    let priority: String
    let startDate: Date?
    let dueDate: Date?
    let resolutionDate: Date?
    let created: Date?
    let issueType: String
    let projectKey: String

    var isDone: Bool { status == "완료" || status == "취소" }
    var isCancelled: Bool { status == "취소" }
}

struct JiraStatusCounts {
    var todo: Int = 0        // 해야 할 일
    var inProgress: Int = 0  // 진행중
    var onHold: Int = 0      // 보류
    var waiting: Int = 0     // 대기
    var completed: Int = 0   // 완료
    var cancelled: Int = 0   // 취소

    mutating func add(_ status: String) {
        switch status {
        case "완료":       completed  += 1
        case "진행중":     inProgress += 1
        case "보류":       onHold     += 1
        case "대기":       waiting    += 1
        case "취소":       cancelled  += 1
        default:           todo       += 1
        }
    }
}

struct ProjectWeekStats: Identifiable {
    var id: String { key }
    let key: String
    let counts: JiraStatusCounts
}

struct SprintInfo: Identifiable {
    let id: Int
    let name: String
    let startDate: Date?
    let endDate: Date?
    let projectKey: String
    let totalIssues: Int
    let completedIssues: Int
    var completionPct: Int { totalIssues > 0 ? Int(Double(completedIssues) / Double(totalIssues) * 100) : 0 }
}

struct EpicInfo: Identifiable {
    var id: String { key }
    let key: String
    let summary: String
    let projectKey: String
    let status: String
    let dueDate: Date?
}

struct JiraDashboardData {
    let thisWeekCounts: JiraStatusCounts
    let projectStats: [ProjectWeekStats]
    let todayIssues: [JiraIssue]
    let thisWeekIssues: [JiraIssue]
    let highestIncomplete: [JiraIssue]
    let overdueIncomplete: [JiraIssue]
    let blockedIssues: [JiraIssue]
    let completedLast30: [JiraIssue]
    let createdLast30: [JiraIssue]
    let nextWeekIssues: [JiraIssue]
    let backlogCountByProject: [String: Int]
    let sprintInfos: [SprintInfo]
    let epicInfos: [EpicInfo]
    let lastUpdated: Date
}

// MARK: - Service

@Observable
final class JiraService {
    static let shared = JiraService()

    /// 자격증명 3종이 모두 설정되어 있어야 이 Service가 활성화된다.
    /// Feature.isEnabled 체크, FeatureRegistry 격리의 기준점.
    /// Jira 기능이 살아있는지 — 사용자가 Settings에서 켰고(`isJiraEnabled`)
    /// 자격증명도 모두 채워져야(`isJiraConfigured`) true.
    static var isAvailable: Bool {
        let store = CredentialsStore.shared
        return store.isJiraEnabled && store.isJiraConfigured
    }

    var data: JiraDashboardData?
    var isLoading = false
    var errorMessage: String?

    private let authHeader: String
    private let workspaceSlug: String
    /// 첫 fetch 시점에 slug로부터 resolve된 후 캐싱된다. resolve 전에는 nil.
    private var resolvedCloudId: String?
    private var projects: [String] { Constants.jiraProjects.map(\.key) }

    private func baseURL(_ cloudId: String) -> String {
        "https://api.atlassian.com/ex/jira/\(cloudId)/rest/api/3"
    }

    private func agileBaseURL(_ cloudId: String) -> String {
        "https://api.atlassian.com/ex/jira/\(cloudId)/rest/agile/1.0"
    }

    private init() {
        let store = CredentialsStore.shared
        self.workspaceSlug = store.jiraWorkspaceSlug
        self.resolvedCloudId = {
            let cached = store.jiraCloudId
            return cached.isEmpty ? nil : cached
        }()
        let cred = "\(store.jiraEmail):\(store.jiraApiToken)"
        self.authHeader = "Basic \(Data(cred.utf8).base64EncodedString())"
    }

    /// Keychain에 캐싱된 cloudId를 우선 사용, 없으면 `_edge/tenant_info`로 한 번 조회 후 캐싱.
    /// 동일 인스턴스 내에서는 메모리에도 캐시돼 매 호출마다 네트워크가 발생하지 않는다.
    private func ensureCloudId() async throws -> String {
        if let cached = resolvedCloudId, !cached.isEmpty { return cached }
        guard !workspaceSlug.isEmpty,
              let url = URL(string: "https://\(workspaceSlug).atlassian.net/_edge/tenant_info") else {
            throw NSError(domain: "JiraAPI", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "워크스페이스 URL이 설정되지 않았습니다."])
        }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cloudId = json["cloudId"] as? String, !cloudId.isEmpty else {
            throw NSError(domain: "JiraAPI", code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: "워크스페이스 정보를 불러올 수 없습니다 (slug: \(workspaceSlug))."])
        }
        resolvedCloudId = cloudId
        CredentialsStore.shared.cacheJiraCloudId(cloudId)
        return cloudId
    }

    private func makeRequest(url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue(authHeader, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    // MARK: - Fetch

    func fetch(force: Bool = false) async {
        guard Self.isAvailable else {
            await MainActor.run { errorMessage = "Jira API 토큰이 설정되지 않았습니다." }
            return
        }

        if !force, let existing = data, Date().timeIntervalSince(existing.lastUpdated) < 1800 {
            return
        }

        await MainActor.run { isLoading = true; errorMessage = nil }

        let cloudId: String
        do {
            cloudId = try await ensureCloudId()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            return
        }

        let base = "project in (\(projects.joined(separator: ", "))) AND assignee = currentUser()"
        let today = isoDateString(Date())
        let weekStart = isoDateString(startOfWeek(offset: 0))
        let weekEnd = isoDateString(endOfWeek(offset: 0))
        let nextWeekStart = isoDateString(startOfWeek(offset: 1))
        let nextWeekEnd = isoDateString(endOfWeek(offset: 1))

        let queries: [(String, String)] = [
            ("thisWeek",    "\(base) AND (\(weekOverlapJQL(weekStart, weekEnd))) ORDER BY duedate ASC, priority ASC"),
            ("nextWeek",    "\(base) AND (\(weekOverlapJQL(nextWeekStart, nextWeekEnd))) ORDER BY duedate ASC"),
            ("highest",     "\(base) AND priority = Highest AND statusCategory != done ORDER BY duedate ASC"),
            ("overdue",     "\(base) AND duedate < \"\(today)\" AND statusCategory != done AND status != 취소 ORDER BY duedate ASC"),
            ("blocked",     "\(base) AND (status = 보류 OR status = 대기) AND statusCategory != done ORDER BY updated ASC"),
            ("completed30", "\(base) AND statusCategory = done AND resolutiondate >= -30d ORDER BY resolutiondate DESC"),
            ("backlog",     "\(base) AND statusCategory != done AND (duedate is EMPTY OR duedate > \"\(nextWeekEnd)\") ORDER BY priority ASC, updated DESC"),
            ("created30",   "project in (\(projects.joined(separator: ", "))) AND reporter = currentUser() AND created >= -30d ORDER BY created DESC"),
        ]

        do {
            var results: [String: [JiraIssue]] = [:]
            try await withThrowingTaskGroup(of: (String, [JiraIssue]).self) { group in
                for (key, jql) in queries {
                    group.addTask { [weak self] in
                        guard let self else { return (key, []) }
                        let issues = try await self.searchIssues(cloudId: cloudId, jql: jql, maxResults: 100)
                        return (key, issues)
                    }
                }
                for try await (key, issues) in group {
                    results[key] = issues
                }
            }

            let thisWeek    = results["thisWeek"]    ?? []
            let nextWeek    = results["nextWeek"]    ?? []
            let highest     = results["highest"]     ?? []
            let overdue     = results["overdue"]     ?? []
            let completed30 = results["completed30"] ?? []
            let backlog     = results["backlog"]     ?? []
            let created30   = results["created30"]   ?? []

            var weekCounts = JiraStatusCounts()
            var byProjectCounts: [String: JiraStatusCounts] = [:]

            for issue in thisWeek {
                weekCounts.add(issue.status)
                byProjectCounts[issue.projectKey, default: JiraStatusCounts()].add(issue.status)
            }

            let projectStats: [ProjectWeekStats] = Constants.jiraProjects.map { proj in
                ProjectWeekStats(key: proj.key, counts: byProjectCounts[proj.key] ?? JiraStatusCounts())
            }

            let todayIssues = thisWeek.filter { issue in
                guard let due = issue.dueDate else { return false }
                return Calendar.current.isDateInToday(due)
            }

            async let sprintsFetch = fetchSprintInfos(cloudId: cloudId)
            async let epicsFetch   = fetchEpics(cloudId: cloudId)

            var backlogCountByProject = Dictionary(grouping: backlog, by: \.projectKey).mapValues(\.count)

            let (sprints, epics) = await (sprintsFetch, epicsFetch)

            let dashData = JiraDashboardData(
                thisWeekCounts: weekCounts,
                projectStats: projectStats,
                todayIssues: todayIssues,
                thisWeekIssues: thisWeek,
                highestIncomplete: highest,
                overdueIncomplete: overdue,
                blockedIssues: results["blocked"] ?? [],
                completedLast30: completed30,
                createdLast30: created30,
                nextWeekIssues: nextWeek,
                backlogCountByProject: backlogCountByProject,
                sprintInfos: sprints,
                epicInfos: epics,
                lastUpdated: Date()
            )

            await MainActor.run {
                self.data = dashData
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // MARK: - API

    private func searchIssues(cloudId: String, jql: String, maxResults: Int) async throws -> [JiraIssue] {
        var comps = URLComponents(string: "\(baseURL(cloudId))/search/jql")!
        comps.queryItems = [
            URLQueryItem(name: "jql", value: jql),
            URLQueryItem(name: "maxResults", value: "\(maxResults)"),
            URLQueryItem(name: "fields", value: "summary,status,priority,\(Constants.jiraStartDateFieldId),duedate,resolutiondate,created,issuetype,project"),
        ]
        guard let url = comps.url else { throw URLError(.badURL) }

        let (data, resp) = try await URLSession.shared.data(for: makeRequest(url: url))
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "JiraAPI", code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: body])
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let issueList = json["issues"] as? [[String: Any]]
        else { return [] }

        return issueList.compactMap { parseIssue($0) }
    }

    private func parseIssue(_ raw: [String: Any]) -> JiraIssue? {
        guard
            let key = raw["key"] as? String,
            let fields = raw["fields"] as? [String: Any],
            let summary = fields["summary"] as? String
        else { return nil }

        let statusName    = (fields["status"] as? [String: Any])?["name"] as? String ?? ""
        let priorityName  = (fields["priority"] as? [String: Any])?["name"] as? String ?? "Medium"
        let issueTypeName = (fields["issuetype"] as? [String: Any])?["name"] as? String ?? ""
        let projectKey    = (fields["project"] as? [String: Any])?["key"] as? String ?? ""

        var startDate: Date? = nil
        if let ds = fields[Constants.jiraStartDateFieldId] as? String {
            startDate = DateParsers.ymd.date(from: ds)
        }

        var dueDate: Date? = nil
        if let ds = fields["duedate"] as? String {
            dueDate = DateParsers.ymd.date(from: ds)
        }

        var resolutionDate: Date? = nil
        if let ds = fields["resolutiondate"] as? String {
            resolutionDate = DateParsers.parseISO8601(ds)
        }

        var created: Date? = nil
        if let ds = fields["created"] as? String {
            created = DateParsers.parseISO8601(ds)
        }

        return JiraIssue(
            id: key, key: key, summary: summary,
            status: statusName,
            priority: priorityName, startDate: startDate, dueDate: dueDate,
            resolutionDate: resolutionDate, created: created,
            issueType: issueTypeName, projectKey: projectKey
        )
    }

    // MARK: - Agile API

    private func fetchSprintInfos(cloudId: String) async -> [SprintInfo] {
        await withTaskGroup(of: SprintInfo?.self) { group in
            for projKey in projects {
                group.addTask { [weak self] in
                    guard let self,
                          let boardId = try? await self.fetchBoardId(cloudId: cloudId, projectKey: projKey),
                          let sprint  = try? await self.fetchActiveSprint(cloudId: cloudId, boardId: boardId, projKey: projKey)
                    else { return nil }
                    return sprint
                }
            }
            var result: [SprintInfo] = []
            for await sprint in group {
                if let sprint { result.append(sprint) }
            }
            return result.sorted { $0.projectKey < $1.projectKey }
        }
    }

    private func fetchBoardId(cloudId: String, projectKey: String) async throws -> Int? {
        var comps = URLComponents(string: "\(agileBaseURL(cloudId))/board")!
        comps.queryItems = [
            URLQueryItem(name: "projectKeyOrId", value: projectKey),
            URLQueryItem(name: "maxResults", value: "1"),
        ]
        guard let url = comps.url else { throw URLError(.badURL) }
        let (data, resp) = try await URLSession.shared.data(for: makeRequest(url: url))
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = json["values"] as? [[String: Any]],
              let boardId = values.first?["id"] as? Int
        else { return nil }
        return boardId
    }

    private func fetchActiveSprint(cloudId: String, boardId: Int, projKey: String) async throws -> SprintInfo? {
        var comps = URLComponents(string: "\(agileBaseURL(cloudId))/board/\(boardId)/sprint")!
        comps.queryItems = [URLQueryItem(name: "state", value: "active")]
        guard let url = comps.url else { throw URLError(.badURL) }
        let (data, resp) = try await URLSession.shared.data(for: makeRequest(url: url))
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = json["values"] as? [[String: Any]],
              let sprint = values.first
        else { return nil }

        let id      = sprint["id"]   as? Int    ?? 0
        let name    = sprint["name"] as? String ?? ""
        let startDate = (sprint["startDate"] as? String).flatMap { DateParsers.parseISO8601($0) }
        let endDate   = (sprint["endDate"]   as? String).flatMap { DateParsers.parseISO8601($0) }

        let (total, completed) = (try? await fetchSprintIssueCounts(cloudId: cloudId, sprintId: id)) ?? (0, 0)
        return SprintInfo(id: id, name: name, startDate: startDate, endDate: endDate,
                          projectKey: projKey, totalIssues: total, completedIssues: completed)
    }

    private func fetchSprintIssueCounts(cloudId: String, sprintId: Int) async throws -> (Int, Int) {
        var comps = URLComponents(string: "\(agileBaseURL(cloudId))/sprint/\(sprintId)/issue")!
        comps.queryItems = [
            URLQueryItem(name: "fields", value: "status"),
            URLQueryItem(name: "maxResults", value: "200"),
        ]
        guard let url = comps.url else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(for: makeRequest(url: url))
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let issues = json["issues"] as? [[String: Any]]
        else { return (0, 0) }

        let total = issues.count
        let completed = issues.filter { issue in
            let catKey = (((issue["fields"] as? [String: Any])?["status"] as? [String: Any])?["statusCategory"] as? [String: Any])?["key"] as? String
            return catKey == "done"
        }.count
        return (total, completed)
    }

    private func fetchEpics(cloudId: String) async -> [EpicInfo] {
        let jql = "project in (\(projects.joined(separator: ", "))) AND issuetype in (Epic, 에픽) AND statusCategory != done AND duedate is not EMPTY ORDER BY project ASC, duedate ASC"
        let issues = (try? await searchIssues(cloudId: cloudId, jql: jql, maxResults: 20)) ?? []
        return issues.map { EpicInfo(key: $0.key, summary: $0.summary, projectKey: $0.projectKey, status: $0.status, dueDate: $0.dueDate) }
    }

    // MARK: - Date Helpers

    private func weekOverlapJQL(_ start: String, _ end: String) -> String {
        let sd = Constants.jiraStartDateJQL
        return "(duedate >= \"\(start)\" AND duedate <= \"\(end)\") OR (\(sd) >= \"\(start)\" AND \(sd) <= \"\(end)\") OR (\(sd) < \"\(start)\" AND duedate > \"\(end)\")"
    }

    private func isoDateString(_ date: Date) -> String {
        DateParsers.ymd.string(from: date)
    }

    private func startOfWeek(offset weeks: Int) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let now = Date()
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        var start = cal.date(from: components) ?? now
        start = cal.date(byAdding: .weekOfYear, value: weeks, to: start) ?? start
        return start
    }

    private func endOfWeek(offset weeks: Int) -> Date {
        let start = startOfWeek(offset: weeks)
        return Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
    }
}
