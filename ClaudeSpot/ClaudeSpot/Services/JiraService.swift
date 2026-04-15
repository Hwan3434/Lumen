import Foundation

// MARK: - Models

struct JiraIssue: Identifiable {
    let id: String
    let key: String
    let summary: String
    let status: String
    let statusCategoryKey: String  // "new", "indeterminate", "done"
    let priority: String
    let dueDate: Date?
    let issueType: String
    let projectKey: String

    var isDone: Bool { statusCategoryKey == "done" }
    var isActive: Bool { !isDone && status != "취소" }
    var isOnHold: Bool { status.contains("보류") || status.lowercased().contains("hold") }
    var isInProgress: Bool { statusCategoryKey == "indeterminate" }
    var isPending: Bool { statusCategoryKey == "new" && !isOnHold }
}

struct ProjectWeekStats: Identifiable {
    var id: String { key }
    let key: String
    let completed: Int
    let inProgress: Int
    let pending: Int
    let onHold: Int
    var total: Int { completed + inProgress + pending + onHold }
    var completionRate: Double { total > 0 ? Double(completed) / Double(total) : 0 }
}

struct JiraSummaryCards {
    let completedThisWeek: Int
    let inProgressThisWeek: Int
    let pendingThisWeek: Int
    let onHoldThisWeek: Int
    let thisWeekTotal: Int
    let nextWeekTotal: Int
}

struct JiraDashboardData {
    let cards: JiraSummaryCards
    let projectStats: [ProjectWeekStats]
    let todayIssues: [JiraIssue]
    let thisWeekIssues: [JiraIssue]
    let highestIncomplete: [JiraIssue]
    let overdueIncomplete: [JiraIssue]
    let lastUpdated: Date
}

// MARK: - Service

@Observable
final class JiraService {
    static let shared = JiraService()
    private init() {}

    var data: JiraDashboardData?
    var isLoading = false
    var errorMessage: String?

    private var cloudId: String { Constants.jiraCloudId }
    private var email: String { Constants.jiraEmail }
    private var apiToken: String { Constants.jiraApiToken }
    private var projects: [String] { Constants.jiraProjects }

    private var baseURL: String {
        "https://api.atlassian.com/ex/jira/\(cloudId)/rest/api/3"
    }

    private var authHeader: String {
        let cred = "\(email):\(apiToken)"
        let encoded = Data(cred.utf8).base64EncodedString()
        return "Basic \(encoded)"
    }

    // MARK: - Fetch

    func fetch(force: Bool = false) async {
        guard apiToken != "" else {
            await MainActor.run { errorMessage = "Jira API 토큰이 설정되지 않았습니다." }
            return
        }

        if !force, let existing = data, Date().timeIntervalSince(existing.lastUpdated) < 1800 {
            return
        }

        await MainActor.run { isLoading = true; errorMessage = nil }

        let base = "project in (\(projects.joined(separator: ", "))) AND assignee = currentUser()"
        let today = isoDateString(Date())
        let weekStart = isoDateString(startOfWeek(offset: 0))
        let weekEnd = isoDateString(endOfWeek(offset: 0))
        let nextWeekStart = isoDateString(startOfWeek(offset: 1))
        let nextWeekEnd = isoDateString(endOfWeek(offset: 1))

        let queries: [(String, String)] = [
            ("thisWeek", "\(base) AND duedate >= \"\(weekStart)\" AND duedate <= \"\(weekEnd)\" AND status != 취소 ORDER BY duedate ASC, priority ASC"),
            ("nextWeek", "\(base) AND duedate >= \"\(nextWeekStart)\" AND duedate <= \"\(nextWeekEnd)\" ORDER BY duedate ASC"),
            ("highest",  "\(base) AND priority = Highest AND statusCategory != done AND status != 취소 ORDER BY duedate ASC"),
            ("overdue",  "\(base) AND duedate < \"\(today)\" AND statusCategory != done AND status != 취소 ORDER BY duedate ASC"),
        ]

        do {
            var results: [String: [JiraIssue]] = [:]
            try await withThrowingTaskGroup(of: (String, [JiraIssue]).self) { group in
                for (key, jql) in queries {
                    group.addTask { [weak self] in
                        guard let self else { return (key, []) }
                        let issues = try await self.searchIssues(jql: jql, maxResults: 100)
                        return (key, issues)
                    }
                }
                for try await (key, issues) in group {
                    results[key] = issues
                }
            }

            let thisWeek = results["thisWeek"] ?? []
            let nextWeek = results["nextWeek"] ?? []
            let highest = results["highest"] ?? []
            let overdue = results["overdue"] ?? []

            // 상태별 카운트 + 프로젝트별 집계 — 단일 패스
            var completedThisWeek = 0, inProgressThisWeek = 0, onHoldThisWeek = 0, pendingThisWeek = 0
            var byProject: [String: (completed: Int, inProgress: Int, pending: Int, onHold: Int)] = [:]

            for issue in thisWeek {
                var p = byProject[issue.projectKey] ?? (0, 0, 0, 0)
                if issue.isDone          { completedThisWeek += 1;  p.completed  += 1 }
                else if issue.isOnHold   { onHoldThisWeek += 1;     p.onHold     += 1 }
                else if issue.isInProgress { inProgressThisWeek += 1; p.inProgress += 1 }
                else                     { pendingThisWeek += 1;    p.pending    += 1 }
                byProject[issue.projectKey] = p
            }

            let projectStats: [ProjectWeekStats] = Constants.jiraProjects.map { projKey in
                let s = byProject[projKey] ?? (0, 0, 0, 0)
                return ProjectWeekStats(key: projKey, completed: s.completed, inProgress: s.inProgress, pending: s.pending, onHold: s.onHold)
            }

            // 오늘 마감
            let todayIssues = thisWeek.filter { issue in
                guard let due = issue.dueDate else { return false }
                return Calendar.current.isDateInToday(due)
            }

            let dashData = JiraDashboardData(
                cards: JiraSummaryCards(
                    completedThisWeek: completedThisWeek,
                    inProgressThisWeek: inProgressThisWeek,
                    pendingThisWeek: pendingThisWeek,
                    onHoldThisWeek: onHoldThisWeek,
                    thisWeekTotal: thisWeek.count,
                    nextWeekTotal: nextWeek.count
                ),
                projectStats: projectStats,
                todayIssues: todayIssues,
                thisWeekIssues: thisWeek,
                highestIncomplete: highest,
                overdueIncomplete: overdue,
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

    private func searchIssues(jql: String, maxResults: Int) async throws -> [JiraIssue] {
        var comps = URLComponents(string: "\(baseURL)/search/jql")!
        comps.queryItems = [
            URLQueryItem(name: "jql", value: jql),
            URLQueryItem(name: "maxResults", value: "\(maxResults)"),
            URLQueryItem(name: "fields", value: "summary,status,priority,duedate,issuetype,project"),
        ]
        guard let url = comps.url else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.setValue(authHeader, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await URLSession.shared.data(for: req)
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
        let statusCatKey  = ((fields["status"] as? [String: Any])?["statusCategory"] as? [String: Any])?["key"] as? String ?? "new"
        let priorityName  = (fields["priority"] as? [String: Any])?["name"] as? String ?? "Medium"
        let issueTypeName = (fields["issuetype"] as? [String: Any])?["name"] as? String ?? ""
        let projectKey    = (fields["project"] as? [String: Any])?["key"] as? String ?? ""

        var dueDate: Date? = nil
        if let ds = fields["duedate"] as? String {
            dueDate = Self.ymdFormatter.date(from: ds)
        }

        return JiraIssue(
            id: key, key: key, summary: summary,
            status: statusName, statusCategoryKey: statusCatKey,
            priority: priorityName, dueDate: dueDate,
            issueType: issueTypeName, projectKey: projectKey
        )
    }

    // MARK: - Date Helpers

    private static let ymdFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private func isoDateString(_ date: Date) -> String {
        Self.ymdFormatter.string(from: date)
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
