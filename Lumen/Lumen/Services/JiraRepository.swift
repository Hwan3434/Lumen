import Foundation

struct JiraCredentials {
    let workspaceSlug: String
    let email: String
    let apiToken: String
    let cachedCloudId: String?
}

actor JiraRepository {
    private let workspaceSlug: String
    private let authHeader: String
    private var resolvedCloudId: String?

    init(credentials: JiraCredentials) {
        self.workspaceSlug = credentials.workspaceSlug
        self.resolvedCloudId = credentials.cachedCloudId
        let cred = "\(credentials.email):\(credentials.apiToken)"
        self.authHeader = "Basic \(Data(cred.utf8).base64EncodedString())"
    }

    func fetchDashboard(projectKeys: [String]) async throws -> JiraDashboardData {
        let cloudId = try await ensureCloudId()
        let base = "project in (\(projectKeys.joined(separator: ", "))) AND assignee = currentUser()"
        let now = Date()
        let weekStartDate = startOfWeek(offset: 0)
        let weekEndDate = endOfWeek(offset: 0)
        let nextWeekStartDate = startOfWeek(offset: 1)
        let nextWeekEndDate = endOfWeek(offset: 1)

        let windowStart = isoDateString(daysOffset(-90))
        let windowEnd = isoDateString(daysOffset(+90))
        let windowJQL = weekOverlapJQL(windowStart, windowEnd)

        let queries: [(String, String)] = [
            ("primary", "\(base) AND (\(windowJQL)) ORDER BY duedate ASC"),
            ("created", "project in (\(projectKeys.joined(separator: ", "))) AND reporter = currentUser() AND created >= -90d ORDER BY created DESC"),
        ]

        var results: [String: [JiraIssue]] = [:]
        try await withThrowingTaskGroup(of: (String, [JiraIssue]).self) { group in
            for (key, jql) in queries {
                group.addTask {
                    let issues = try await self.searchIssues(cloudId: cloudId, jql: jql, maxResults: 1000)
                    return (key, issues)
                }
            }
            for try await (key, issues) in group {
                results[key] = issues
            }
        }

        let primary = results["primary"] ?? []
        let created = results["created"] ?? []
        let cal = Calendar.current

        let thisWeek = primary.filter { overlaps($0, weekStartDate, weekEndDate) }
        let nextWeek = primary.filter { overlaps($0, nextWeekStartDate, nextWeekEndDate) }
        let highest = primary.filter { $0.priority == "Highest" && !$0.isDone }
        let overdue = primary.filter {
            guard let due = $0.dueDate else { return false }
            return due < cal.startOfDay(for: now) && !$0.isDone
        }
        let completed30 = primary.filter {
            guard $0.isDone, let res = $0.resolutionDate else { return false }
            return now.timeIntervalSince(res) <= 30 * 24 * 3600
        }
        let created30 = created.filter {
            guard let c = $0.created else { return false }
            return now.timeIntervalSince(c) <= 30 * 24 * 3600
        }
        let backlog = primary.filter { !$0.isDone && ($0.dueDate == nil || $0.dueDate! > nextWeekEndDate) }

        var weekCounts = JiraStatusCounts()
        var byProjectCounts: [String: JiraStatusCounts] = [:]
        for issue in thisWeek {
            weekCounts.add(issue.statusCategory)
            byProjectCounts[issue.projectKey, default: JiraStatusCounts()].add(issue.statusCategory)
        }

        let projectStats = projectKeys.map { key in
            ProjectWeekStats(key: key, counts: byProjectCounts[key] ?? JiraStatusCounts())
        }

        let todayIssues = thisWeek.filter { issue in
            guard let due = issue.dueDate else { return false }
            return cal.isDateInToday(due)
        }

        async let sprintsFetch = fetchSprintInfos(cloudId: cloudId, projectKeys: projectKeys)
        async let epicsFetch = fetchEpics(cloudId: cloudId, projectKeys: projectKeys)
        let backlogCountByProject = Dictionary(grouping: backlog, by: \.projectKey).mapValues(\.count)
        let (sprints, epics) = await (sprintsFetch, epicsFetch)

        return JiraDashboardData(
            thisWeekCounts: weekCounts,
            projectStats: projectStats,
            todayIssues: todayIssues,
            thisWeekIssues: thisWeek,
            highestIncomplete: highest,
            overdueIncomplete: overdue,
            completedLast30: completed30,
            createdLast30: created30,
            nextWeekIssues: nextWeek,
            backlogCountByProject: backlogCountByProject,
            sprintInfos: sprints,
            epicInfos: epics,
            allIssuesInWindow: primary,
            lastUpdated: Date()
        )
    }

    func fetchIssueDetail(key: String) async throws -> IssueDetail {
        let cloudId = try await ensureCloudId()
        var comps = URLComponents(string: "\(baseURL(cloudId))/issue/\(key)")!
        comps.queryItems = [URLQueryItem(name: "fields", value: "summary,status,description,comment")]
        guard let url = comps.url else { throw URLError(.badURL) }

        let (data, resp) = try await URLSession.shared.data(for: makeRequest(url: url))
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "JiraAPI", code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? ""])
        }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let fields = json["fields"] as? [String: Any]
        else { throw URLError(.cannotParseResponse) }

        let summary = (fields["summary"] as? String) ?? ""
        let statusName = ((fields["status"] as? [String: Any])?["name"] as? String) ?? ""
        let descText = (fields["description"] as? [String: Any])
            .map { Self.adfPlainText(node: $0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""

        var commentCount = 0
        if let comment = fields["comment"] as? [String: Any] {
            commentCount = (comment["total"] as? Int) ?? ((comment["comments"] as? [Any])?.count ?? 0)
        }

        return IssueDetail(key: key, summary: summary, status: statusName,
                           descriptionText: descText, commentCount: commentCount)
    }

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
        await MainActor.run {
            CredentialsStore.shared.cacheJiraCloudId(cloudId)
        }
        return cloudId
    }

    private func baseURL(_ cloudId: String) -> String {
        "https://api.atlassian.com/ex/jira/\(cloudId)/rest/api/3"
    }

    private func agileBaseURL(_ cloudId: String) -> String {
        "https://api.atlassian.com/ex/jira/\(cloudId)/rest/agile/1.0"
    }

    private func makeRequest(url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue(authHeader, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    private func searchIssues(cloudId: String, jql: String, maxResults: Int) async throws -> [JiraIssue] {
        let pageSize = 100
        let totalCap = min(maxResults, 1000)
        var collected: [JiraIssue] = []
        var nextPageToken: String?

        while collected.count < totalCap {
            var comps = URLComponents(string: "\(baseURL(cloudId))/search/jql")!
            var items: [URLQueryItem] = [
                URLQueryItem(name: "jql", value: jql),
                URLQueryItem(name: "maxResults", value: "\(pageSize)"),
                URLQueryItem(name: "fields", value: "summary,status,priority,\(Constants.jiraStartDateFieldId),duedate,resolutiondate,created,issuetype,project"),
            ]
            if let token = nextPageToken {
                items.append(URLQueryItem(name: "nextPageToken", value: token))
            }
            comps.queryItems = items
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
            else { return collected }

            collected.append(contentsOf: issueList.compactMap { parseIssue($0) })

            let isLast = (json["isLast"] as? Bool) ?? false
            if isLast { break }
            guard let next = json["nextPageToken"] as? String, !next.isEmpty else { break }
            nextPageToken = next
        }

        return collected
    }

    private func parseIssue(_ raw: [String: Any]) -> JiraIssue? {
        guard
            let key = raw["key"] as? String,
            let fields = raw["fields"] as? [String: Any],
            let summary = fields["summary"] as? String
        else { return nil }

        let statusObj = fields["status"] as? [String: Any]
        let statusName = statusObj?["name"] as? String ?? ""
        let categoryRaw = (statusObj?["statusCategory"] as? [String: Any])?["key"] as? String ?? "undefined"
        let priorityName = (fields["priority"] as? [String: Any])?["name"] as? String ?? "Medium"
        let issueTypeName = (fields["issuetype"] as? [String: Any])?["name"] as? String ?? ""
        let projectKey = (fields["project"] as? [String: Any])?["key"] as? String ?? ""

        let startDate = (fields[Constants.jiraStartDateFieldId] as? String).flatMap { DateParsers.ymd.date(from: $0) }
        let dueDate = (fields["duedate"] as? String).flatMap { DateParsers.ymd.date(from: $0) }
        let resolutionDate = (fields["resolutiondate"] as? String).flatMap { DateParsers.parseISO8601($0) }
        let created = (fields["created"] as? String).flatMap { DateParsers.parseISO8601($0) }

        return JiraIssue(
            id: key,
            key: key,
            summary: summary,
            status: statusName,
            statusCategory: JiraStatusCategory(rawAPIKey: categoryRaw),
            priority: priorityName,
            startDate: startDate,
            dueDate: dueDate,
            resolutionDate: resolutionDate,
            created: created,
            issueType: issueTypeName,
            projectKey: projectKey
        )
    }

    private func fetchSprintInfos(cloudId: String, projectKeys: [String]) async -> [SprintInfo] {
        await withTaskGroup(of: SprintInfo?.self) { group in
            for projKey in projectKeys {
                group.addTask {
                    guard
                        let boardId = try? await self.fetchBoardId(cloudId: cloudId, projectKey: projKey),
                        let sprint = try? await self.fetchActiveSprint(cloudId: cloudId, boardId: boardId, projKey: projKey)
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

        let id = sprint["id"] as? Int ?? 0
        let name = sprint["name"] as? String ?? ""
        let startDate = (sprint["startDate"] as? String).flatMap { DateParsers.parseISO8601($0) }
        let endDate = (sprint["endDate"] as? String).flatMap { DateParsers.parseISO8601($0) }
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

    private func fetchEpics(cloudId: String, projectKeys: [String]) async -> [EpicInfo] {
        let jql = "project in (\(projectKeys.joined(separator: ", "))) AND issuetype = Epic AND statusCategory != done AND duedate is not EMPTY ORDER BY project ASC, duedate ASC"
        let issues = (try? await searchIssues(cloudId: cloudId, jql: jql, maxResults: 20)) ?? []
        return issues.map { EpicInfo(key: $0.key, summary: $0.summary, projectKey: $0.projectKey, status: $0.status, dueDate: $0.dueDate) }
    }

    private func overlaps(_ issue: JiraIssue, _ start: Date, _ end: Date) -> Bool {
        if let due = issue.dueDate, due >= start && due <= end { return true }
        if let st = issue.startDate, st >= start && st <= end { return true }
        if let st = issue.startDate, let due = issue.dueDate, st < start && due > end { return true }
        return false
    }

    private func weekOverlapJQL(_ start: String, _ end: String) -> String {
        let sd = Constants.jiraStartDateJQL
        return "(duedate >= \"\(start)\" AND duedate <= \"\(end)\") OR (\(sd) >= \"\(start)\" AND \(sd) <= \"\(end)\") OR (\(sd) < \"\(start)\" AND duedate > \"\(end)\")"
    }

    private func daysOffset(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
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

    private static func adfPlainText(node: Any) -> String {
        if let dict = node as? [String: Any] {
            let type = dict["type"] as? String ?? ""
            if type == "text", let text = dict["text"] as? String { return text }
            var inner = ""
            if let content = dict["content"] as? [Any] {
                for child in content {
                    inner += adfPlainText(node: child)
                }
            }
            switch type {
            case "paragraph", "heading", "bulletList", "orderedList", "listItem", "codeBlock", "blockquote":
                inner += "\n"
            default:
                break
            }
            return inner
        } else if let arr = node as? [Any] {
            return arr.map { adfPlainText(node: $0) }.joined()
        }
        return ""
    }
}
