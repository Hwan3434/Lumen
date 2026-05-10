import Foundation

// MARK: - Models

/// Atlassian의 표준 statusCategory — 워크스페이스/언어 무관한 4분류 식별자.
/// API의 raw string을 그대로 들고 다니지 않도록 디코드 시점에 변환한다.
enum JiraStatusCategory: String {
    case new            // statusCategory.key == "new" — to-do
    case indeterminate  // statusCategory.key == "indeterminate" — in-progress
    case done           // statusCategory.key == "done"
    case undefined      // 알 수 없음 / 없음

    init(rawAPIKey: String) {
        self = JiraStatusCategory(rawValue: rawAPIKey) ?? .undefined
    }
}

struct JiraIssue: Identifiable {
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

struct JiraStatusCounts {
    var todo: Int = 0
    var inProgress: Int = 0
    var done: Int = 0

    mutating func add(_ category: JiraStatusCategory) {
        switch category {
        case .new:           todo       += 1
        case .indeterminate: inProgress += 1
        case .done:          done       += 1
        case .undefined:     todo       += 1
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
struct IssueDetail {
    let key: String
    let summary: String
    let status: String
    let descriptionText: String   // ADF → plain text
    let commentCount: Int
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
                self.errorMessage = error.networkErrorMessage
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

        // ±3개월 윈도우 — 모든 탭(대시보드/월간/타임라인)이 공유하는 단일 데이터 소스.
        // span overlap: start/due가 윈도우 안에 있거나, 윈도우를 가로지르는 긴 이슈 모두 포함.
        let windowStart = isoDateString(daysOffset(-90))
        let windowEnd   = isoDateString(daysOffset(+90))
        let windowJQL   = weekOverlapJQL(windowStart, windowEnd)

        // 두 개의 쿼리만 남는다:
        //   primary:  ±3M 윈도우에 걸친, 자기 담당 모든 이슈 (대시보드 분류 + 캘린더의 baseline)
        //   created:  3개월 안에 자기가 만든 이슈 (대시보드의 "내가 만든" 트렌드 — 담당자 무관)
        let queries: [(String, String)] = [
            ("primary",  "\(base) AND (\(windowJQL)) ORDER BY duedate ASC"),
            ("created",  "project in (\(projects.joined(separator: ", "))) AND reporter = currentUser() AND created >= -90d ORDER BY created DESC"),
        ]

        do {
            var results: [String: [JiraIssue]] = [:]
            try await withThrowingTaskGroup(of: (String, [JiraIssue]).self) { group in
                for (key, jql) in queries {
                    group.addTask { [weak self] in
                        guard let self else { return (key, []) }
                        // searchIssues는 nextPageToken을 따라가며 누적 — 인자는 총 상한.
                        // 1000은 ±3M 윈도우 + 본인 담당으로 사실상 도달 안 함.
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

            // --- 대시보드용 분류 (클라이언트 필터링) ---
            let cal = Calendar.current
            let now = Date()
            let weekStartDate = startOfWeek(offset: 0)
            let weekEndDate   = endOfWeek(offset: 0)
            let nextWeekStartDate = startOfWeek(offset: 1)
            let nextWeekEndDate   = endOfWeek(offset: 1)

            func overlaps(_ issue: JiraIssue, _ s: Date, _ e: Date) -> Bool {
                // weekOverlapJQL과 같은 의미: due 또는 start가 [s,e]에 있거나 span이 그 구간을 가로지름.
                if let due = issue.dueDate, due >= s && due <= e { return true }
                if let st  = issue.startDate, st >= s && st <= e { return true }
                if let st = issue.startDate, let due = issue.dueDate, st < s && due > e { return true }
                return false
            }

            let thisWeek = primary.filter { overlaps($0, weekStartDate, weekEndDate) }
            let nextWeek = primary.filter { overlaps($0, nextWeekStartDate, nextWeekEndDate) }
            let highest  = primary.filter { $0.priority == "Highest" && !$0.isDone }
            let overdue  = primary.filter {
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

            let projectStats: [ProjectWeekStats] = Constants.jiraProjects.map { proj in
                ProjectWeekStats(key: proj.key, counts: byProjectCounts[proj.key] ?? JiraStatusCounts())
            }

            let todayIssues = thisWeek.filter { issue in
                guard let due = issue.dueDate else { return false }
                return cal.isDateInToday(due)
            }

            async let sprintsFetch = fetchSprintInfos(cloudId: cloudId)
            async let epicsFetch   = fetchEpics(cloudId: cloudId)

            let backlogCountByProject = Dictionary(grouping: backlog, by: \.projectKey).mapValues(\.count)

            let (sprints, epics) = await (sprintsFetch, epicsFetch)

            let dashData = JiraDashboardData(
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

            // weekStart/weekEnd/today/nextWeek 변수가 더 이상 JQL에 안 쓰이지만,
            // 의도적으로 지우지 않은 게 아니라 — 위에서 weekStartDate 등으로 옮겨갔다.
            _ = today; _ = weekStart; _ = weekEnd; _ = nextWeekStart; _ = nextWeekEnd

            await MainActor.run {
                self.data = dashData
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.networkErrorMessage
                self.isLoading = false
            }
        }
    }

    /// 오늘 기준 ±N일 (자정 기준).
    private func daysOffset(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }

    // MARK: - API

    /// 단건 이슈 디테일 fetch — popover 미리보기에서 호출. 호출 시점마다 새로 받음(캐시 없음).
    /// description은 ADF (Atlassian Document Format) 트리이므로 모든 text 노드를 합쳐 plain text로.
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

        var descText = ""
        if let descNode = fields["description"] as? [String: Any] {
            descText = Self.adfPlainText(node: descNode).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var commentCount = 0
        if let comment = fields["comment"] as? [String: Any] {
            commentCount = (comment["total"] as? Int) ?? ((comment["comments"] as? [Any])?.count ?? 0)
        }

        return IssueDetail(key: key, summary: summary, status: statusName,
                           descriptionText: descText, commentCount: commentCount)
    }

    /// ADF 노드 트리에서 모든 text 노드 추출. paragraph 사이엔 개행 두 번.
    private static func adfPlainText(node: Any) -> String {
        if let dict = node as? [String: Any] {
            let type = dict["type"] as? String ?? ""
            // text 노드는 자체적으로 text 들고 있음
            if type == "text", let t = dict["text"] as? String { return t }
            var inner = ""
            if let content = dict["content"] as? [Any] {
                for child in content {
                    inner += adfPlainText(node: child)
                }
            }
            // block-level 노드 뒤엔 개행
            switch type {
            case "paragraph", "heading", "bulletList", "orderedList", "listItem", "codeBlock", "blockquote":
                inner += "\n"
            default: break
            }
            return inner
        } else if let arr = node as? [Any] {
            return arr.map { adfPlainText(node: $0) }.joined()
        }
        return ""
    }

    /// /search/jql는 한 응답에 최대 100건만 담고 그 이상은 nextPageToken으로 받아야 한다.
    /// `maxResults`는 페이지당 크기가 아니라 "한 번의 fetch에서 누적 받을 총 상한"으로 동작한다 —
    /// 호출자가 100을 넘게 부르면 자동으로 페이지를 따라간다. 1000으로 cap을 두어 폭주 방지.
    private func searchIssues(cloudId: String, jql: String, maxResults: Int) async throws -> [JiraIssue] {
        let pageSize = 100
        let totalCap = min(maxResults, 1000)
        var collected: [JiraIssue] = []
        var nextPageToken: String? = nil

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

            // isLast가 true이거나 nextPageToken이 없으면 더 받을 게 없음.
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

        let statusObj     = fields["status"] as? [String: Any]
        let statusName    = statusObj?["name"] as? String ?? ""
        let categoryRaw   = (statusObj?["statusCategory"] as? [String: Any])?["key"] as? String ?? "undefined"
        let category      = JiraStatusCategory(rawAPIKey: categoryRaw)
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
            statusCategory: category,
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
        // Atlassian의 Epic은 워크스페이스/언어 무관하게 issueType id가 "Epic"으로 통일된다.
        let jql = "project in (\(projects.joined(separator: ", "))) AND issuetype = Epic AND statusCategory != done AND duedate is not EMPTY ORDER BY project ASC, duedate ASC"
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
