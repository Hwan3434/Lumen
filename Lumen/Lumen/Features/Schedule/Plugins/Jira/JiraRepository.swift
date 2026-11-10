import Foundation

nonisolated struct JiraCredentials {
    let workspaceSlug: String
    let email: String
    let apiToken: String
    let cachedCloudId: String?
}

/// Jira Cloud REST 호출. 자격증명은 만들 때 한 번 받고, 바뀌면 플러그인이 새로 만든다.
actor JiraRepository {
    /// Jira "Start date" 커스텀 필드 ID와 JQL 표현.
    static let startDateFieldId = "customfield_10015"
    static let startDateJQL = "\"Start date\""

    private let workspaceSlug: String
    private let authHeader: String
    private var resolvedCloudId: String?
    private let onCloudIdResolved: @MainActor @Sendable (String) -> Void

    init(credentials: JiraCredentials, onCloudIdResolved: @escaping @MainActor @Sendable (String) -> Void) {
        self.workspaceSlug = credentials.workspaceSlug
        self.resolvedCloudId = credentials.cachedCloudId
        self.onCloudIdResolved = onCloudIdResolved
        let cred = "\(credentials.email):\(credentials.apiToken)"
        self.authHeader = "Basic \(Data(cred.utf8).base64EncodedString())"
    }

    // MARK: - 조회

    /// 담당 이슈 중 시작일이나 마감일이 범위 안에 있는 것. 둘 사이에 범위를 통째로 품는 것도 포함.
    func fetchIssues(projectKeys: [String], window: DateInterval) async throws -> [JiraIssue] {
        let cloudId = try await ensureCloudId()
        return try await searchIssues(cloudId: cloudId, jql: Self.issuesJQL(projectKeys: projectKeys, window: window), cap: 1000)
    }

    /// 프로젝트별 활성 스프린트. 보드나 진행 중인 스프린트가 없는 프로젝트는 건너뛴다.
    func fetchActiveSprints(projectKeys: [String]) async throws -> [SprintInfo] {
        let cloudId = try await ensureCloudId()
        return try await withThrowingTaskGroup(of: SprintInfo?.self) { group in
            for projectKey in projectKeys {
                group.addTask {
                    do {
                        guard let boardId = try await self.fetchBoardId(cloudId: cloudId, projectKey: projectKey) else { return nil }
                        return try await self.fetchActiveSprint(cloudId: cloudId, boardId: boardId, projectKey: projectKey)
                    } catch where !Self.failsRefresh(error) {
                        return nil
                    }
                }
            }
            var result: [SprintInfo] = []
            for try await sprint in group {
                if let sprint { result.append(sprint) }
            }
            return result.sorted { $0.projectKey < $1.projectKey }
        }
    }

    /// 마감일이 범위 안에 있는 열린 에픽, 최대 20개.
    func fetchEpics(projectKeys: [String], window: DateInterval) async throws -> [JiraIssue] {
        let cloudId = try await ensureCloudId()
        do {
            return try await searchIssues(cloudId: cloudId, jql: Self.epicsJQL(projectKeys: projectKeys, window: window), cap: 20)
        } catch where !Self.failsRefresh(error) {
            return []
        }
    }

    /// 스프린트·에픽은 부가 정보라 "이 프로젝트엔 없다"에 해당하는 실패(보드 없음, 권한 없음, 에픽 유형 없음)는
    /// 로그만 남기고 넘어간다. 인증 실패, 요청 제한, 서버 오류, 네트워크 오류는 갱신 전체를 실패로 돌린다 —
    /// 삼키면 스프린트·에픽이 빠진 결과가 성공으로 처리돼 30분 동안 캐시된다.
    static func failsRefresh(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == errorDomain else { return true }
        return nsError.code == 401 || nsError.code == 429 || (500...599).contains(nsError.code)
    }

    func fetchIssueDetail(key: String) async throws -> IssueDetail {
        let cloudId = try await ensureCloudId()

        // 본문과 댓글 수는 서로 독립이라 동시에 받는다 — 댓글 때문에 미리보기가 느려지지 않도록.
        async let fieldsTask = fetchIssueFields(cloudId: cloudId, key: key)
        async let commentCount = fetchCommentCount(cloudId: cloudId, key: key)

        let (summary, statusName, descText) = try await fieldsTask
        return IssueDetail(key: key, summary: summary, status: statusName,
                           descriptionText: descText, commentCount: await commentCount)
    }

    /// 최신 댓글 `limit`개와 전체 개수. 긴 스레드를 처음부터 다 받으면 팝오버가 늦게 뜨고,
    /// 오래된 순으로 받다 자르면 정작 최신 댓글이 빠지므로 최신순으로 한 페이지만 받는다.
    func fetchComments(key: String, limit: Int = 100) async throws -> (total: Int, comments: [IssueComment]) {
        let cloudId = try await ensureCloudId()
        let url = try makeURL("\(baseURL(cloudId))/issue/\(pathEscaped(key))/comment", query: [
            URLQueryItem(name: "orderBy", value: "-created"),
            URLQueryItem(name: "maxResults", value: "\(limit)"),
        ])
        return Self.parseCommentPage(try await getJSON(url, context: "댓글 \(key)"))
    }

    /// 연결 확인. 로그인한 사용자의 표시 이름을 돌려준다.
    func fetchMyself() async throws -> String {
        let cloudId = try await ensureCloudId()
        let json = try await getJSON(makeURL("\(baseURL(cloudId))/myself"), context: "연결 확인")
        return (json["displayName"] as? String) ?? (json["emailAddress"] as? String) ?? ""
    }

    // MARK: - JQL (순수 함수)

    static func issuesJQL(projectKeys: [String], window: DateInterval) -> String {
        let start = DateParsers.ymd.string(from: window.start)
        let end = DateParsers.ymd.string(from: window.end)
        let sd = startDateJQL
        let overlap = "(duedate >= \"\(start)\" AND duedate <= \"\(end)\") OR (\(sd) >= \"\(start)\" AND \(sd) <= \"\(end)\") OR (\(sd) < \"\(start)\" AND duedate > \"\(end)\")"
        return "\(projectClause(projectKeys)) AND assignee = currentUser() AND (\(overlap)) ORDER BY duedate ASC"
    }

    /// 담당자를 가리지 않으므로 범위를 두지 않으면 오래전에 마감이 지난 열린 에픽이 "지난 기한"에 계속 남는다.
    static func epicsJQL(projectKeys: [String], window: DateInterval) -> String {
        let start = DateParsers.ymd.string(from: window.start)
        let end = DateParsers.ymd.string(from: window.end)
        return "\(projectClause(projectKeys)) AND issuetype = Epic AND statusCategory != done AND duedate >= \"\(start)\" AND duedate <= \"\(end)\" ORDER BY project ASC, duedate ASC"
    }

    /// 키를 따옴표로 감싼다. 감싸지 않으면 JQL 예약어와 같은 키에서 400이 난다.
    private static func projectClause(_ keys: [String]) -> String {
        "project in (\(keys.map { "\"\($0)\"" }.joined(separator: ", ")))"
    }

    // MARK: - 상세

    private func fetchIssueFields(cloudId: String, key: String) async throws -> (summary: String, status: String, description: String) {
        let url = try makeURL("\(baseURL(cloudId))/issue/\(pathEscaped(key))",
                              query: [URLQueryItem(name: "fields", value: "summary,status,description")])
        let json = try await getJSON(url, context: "이슈 \(key)")
        guard let fields = json["fields"] as? [String: Any] else { throw URLError(.cannotParseResponse) }

        let summary = (fields["summary"] as? String) ?? ""
        let statusName = ((fields["status"] as? [String: Any])?["name"] as? String) ?? ""
        let descText = (fields["description"] as? [String: Any])
            .map { Self.adfPlainText(node: $0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        return (summary, statusName, descText)
    }

    /// 미리보기의 "댓글 N개"용. 개수만 필요해 한 개짜리 페이지를 받는다. 실패하면 0 — 미리보기를 막지 않는다.
    private func fetchCommentCount(cloudId: String, key: String) async -> Int {
        guard let url = try? makeURL("\(baseURL(cloudId))/issue/\(pathEscaped(key))/comment",
                                     query: [URLQueryItem(name: "maxResults", value: "1")]),
              let json = try? await getJSON(url, context: "댓글 수 \(key)") else { return 0 }
        return Self.parseCommentPage(json).total
    }

    /// `/issue/{key}/comment?orderBy=-created` 응답 → (전체 개수, 표시용 댓글).
    /// 네트워크와 분리된 순수 함수 — 정렬·필터 규칙을 테스트로 고정하기 위함.
    static func parseCommentPage(_ json: [String: Any]) -> (total: Int, comments: [IssueComment]) {
        let raw = (json["comments"] as? [[String: Any]]) ?? []
        // 응답은 최신순(-created)이지만, 표시는 대화 흐름대로 오래된 것 → 최신 순으로 뒤집는다.
        let parsed = Array(raw.compactMap(parseComment).reversed())
        let total = (json["total"] as? Int) ?? parsed.count
        return (max(total, parsed.count), parsed)
    }

    private static func parseComment(_ dict: [String: Any]) -> IssueComment? {
        // id는 문자열이 원칙이지만 숫자로 오는 응답도 있어 둘 다 받는다.
        guard let id = (dict["id"] as? String) ?? (dict["id"] as? NSNumber)?.stringValue else { return nil }

        // body는 v3에서 ADF(dict)지만, 평문 문자열로 오는 경우도 방어한다.
        let body: String
        if let adf = dict["body"] as? [String: Any] {
            body = adfPlainText(node: adf).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let text = dict["body"] as? String {
            body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            body = ""
        }

        // 본문이 비어도 버리지 않는다 — 첨부만 있는 댓글도 "있다"는 사실은 보여줘야 한다.
        return IssueComment(
            id: id,
            author: ((dict["author"] as? [String: Any])?["displayName"] as? String) ?? "알 수 없음",
            created: (dict["created"] as? String).flatMap { DateParsers.parseISO8601($0) },
            bodyText: body
        )
    }

    // MARK: - 공통

    private static let errorDomain = "JiraAPI"

    private func ensureCloudId() async throws -> String {
        if let cached = resolvedCloudId, !cached.isEmpty { return cached }
        guard !workspaceSlug.isEmpty,
              let url = URL(string: "https://\(workspaceSlug).atlassian.net/_edge/tenant_info") else {
            throw NSError(domain: Self.errorDomain, code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "워크스페이스 도메인이 비어 있어요."])
        }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cloudId = json["cloudId"] as? String, !cloudId.isEmpty else {
            throw NSError(domain: Self.errorDomain, code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: "워크스페이스 정보를 불러올 수 없어요 (도메인: \(workspaceSlug))."])
        }
        resolvedCloudId = cloudId
        await onCloudIdResolved(cloudId)
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

    /// GET 한 번: 2xx가 아니면 사람이 읽을 오류를, 본문이 JSON 객체가 아니면 파싱 오류를 던진다.
    private func getJSON(_ url: URL, context: String) async throws -> [String: Any] {
        let (data, resp) = try await URLSession.shared.data(for: makeRequest(url: url))
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            throw Self.apiError(status: status, data: data, context: context)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return json
    }

    /// cloudId는 API 응답에서, 이슈 키는 사용자 데이터에서 오므로 조합이 항상 유효하다는 보장이 없다 —
    /// 그래서 force unwrap 대신 badURL을 던진다.
    private func makeURL(_ base: String, query items: [URLQueryItem] = []) throws -> URL {
        guard var comps = URLComponents(string: base) else { throw URLError(.badURL) }
        if !items.isEmpty { comps.queryItems = items }
        guard let url = comps.url else { throw URLError(.badURL) }
        return url
    }

    private func pathEscaped(_ raw: String) -> String {
        raw.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? raw
    }

    /// HTTP 실패 응답 → 사람이 읽을 수 있는 오류. 원문은 로그로 남기고 UI에는 요약만 보낸다.
    private static func apiError(status: Int, data: Data, context: String) -> NSError {
        let raw = String(data: data.prefix(500), encoding: .utf8) ?? ""
        NSLog("[Lumen] Jira 요청 실패 (%@): http=%d body=%@", context, status, raw)

        let base: String
        switch status {
        case 401:       base = "Jira 인증에 실패했어요. 이메일과 API 토큰을 확인해 주세요."
        case 403:       base = "이 리소스를 볼 권한이 없어요."
        case 404:       base = "요청한 항목을 Jira에서 찾을 수 없어요."
        case 429:       base = "요청이 너무 잦아요. 잠시 후 다시 시도해 주세요."
        case 500...599: base = "Jira 서버 오류예요 (\(status))."
        default:        base = "Jira 요청이 실패했어요 (\(status))."
        }

        // Atlassian이 주는 errorMessages는 대개 한 줄짜리 사람말이라 붙여주면 도움이 된다.
        let detail = errorMessages(from: data).first
        let message = detail.map { "\(base)\n\($0)" } ?? base
        return NSError(domain: errorDomain, code: status,
                       userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func errorMessages(from data: Data) -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        if let messages = json["errorMessages"] as? [String], !messages.isEmpty {
            return messages
        }
        if let errors = json["errors"] as? [String: String], !errors.isEmpty {
            return errors.map { "\($0.key): \($0.value)" }
        }
        return []
    }

    private func searchIssues(cloudId: String, jql: String, cap: Int) async throws -> [JiraIssue] {
        try await Self.collectIssues(cap: cap) { token, limit in
            var items: [URLQueryItem] = [
                URLQueryItem(name: "jql", value: jql),
                URLQueryItem(name: "maxResults", value: "\(limit)"),
                URLQueryItem(name: "fields", value: "summary,status,priority,\(Self.startDateFieldId),duedate,issuetype,project"),
            ]
            if let token {
                items.append(URLQueryItem(name: "nextPageToken", value: token))
            }
            return try await self.getJSON(self.makeURL("\(self.baseURL(cloudId))/search/jql", query: items), context: "이슈 검색")
        }
    }

    /// `/search/jql` 결과를 `cap`개까지 페이지를 넘기며 모은다. 네트워크와 분리된 순수 함수 — 페이지 규칙을 테스트로 고정한다.
    /// `page`는 (다음 페이지 토큰, 이번에 요청할 개수)를 받아 응답 JSON을 돌려준다.
    static func collectIssues(cap: Int, pageSize: Int = 100,
                              page: (_ token: String?, _ limit: Int) async throws -> [String: Any]) async throws -> [JiraIssue] {
        var collected: [JiraIssue] = []
        var token: String?
        while collected.count < cap {
            let json = try await page(token, min(pageSize, cap - collected.count))
            // 중간 페이지가 깨졌을 때 모은 데까지만 돌려주면 잘린 목록이 성공으로 처리돼 캐시까지 덮는다.
            guard let raw = json["issues"] as? [[String: Any]] else { throw URLError(.cannotParseResponse) }
            collected += raw.compactMap(parseIssue)

            if (json["isLast"] as? Bool) == true { return collected }
            // 빈 페이지나 같은 토큰이 다시 오면 끝난 것으로 본다(무한 반복 방지).
            guard !raw.isEmpty, let next = json["nextPageToken"] as? String, !next.isEmpty, next != token else {
                return collected
            }
            token = next
        }
        NSLog("[Lumen] Jira 검색 결과가 상한 %d개를 넘어 뒤쪽을 잘랐어요", cap)
        return Array(collected.prefix(cap))
    }

    private static func parseIssue(_ raw: [String: Any]) -> JiraIssue? {
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

        let startDate = (fields[startDateFieldId] as? String).flatMap { DateParsers.ymd.date(from: $0) }
        let dueDate = (fields["duedate"] as? String).flatMap { DateParsers.ymd.date(from: $0) }

        return JiraIssue(
            id: key,
            key: key,
            summary: summary,
            status: statusName,
            statusCategory: JiraStatusCategory(rawAPIKey: categoryRaw),
            priority: priorityName,
            startDate: startDate,
            dueDate: dueDate,
            issueType: issueTypeName,
            projectKey: projectKey
        )
    }

    private func fetchBoardId(cloudId: String, projectKey: String) async throws -> Int? {
        let url = try makeURL("\(agileBaseURL(cloudId))/board", query: [
            URLQueryItem(name: "projectKeyOrId", value: projectKey),
            URLQueryItem(name: "maxResults", value: "1"),
        ])
        let json = try await getJSON(url, context: "보드 \(projectKey)")
        return (json["values"] as? [[String: Any]])?.first?["id"] as? Int
    }

    private func fetchActiveSprint(cloudId: String, boardId: Int, projectKey: String) async throws -> SprintInfo? {
        let url = try makeURL("\(agileBaseURL(cloudId))/board/\(boardId)/sprint",
                              query: [URLQueryItem(name: "state", value: "active")])
        let json = try await getJSON(url, context: "스프린트 \(projectKey)")
        guard let sprint = (json["values"] as? [[String: Any]])?.first else { return nil }

        return SprintInfo(
            id: sprint["id"] as? Int ?? 0,
            name: sprint["name"] as? String ?? "",
            startDate: (sprint["startDate"] as? String).flatMap { DateParsers.parseISO8601($0) },
            endDate: (sprint["endDate"] as? String).flatMap { DateParsers.parseISO8601($0) },
            projectKey: projectKey
        )
    }

    private static func adfPlainText(node: Any) -> String {
        if let dict = node as? [String: Any] {
            let type = dict["type"] as? String ?? ""
            if type == "text", let text = dict["text"] as? String { return text }

            // 텍스트가 아닌 leaf 노드들 — 이걸 빼먹으면 멘션/이모지만 있는 댓글이 통째로 빈 문자열이 된다.
            let attrs = dict["attrs"] as? [String: Any]
            switch type {
            case "mention":
                return (attrs?["text"] as? String) ?? "@사용자"
            case "emoji":
                return (attrs?["text"] as? String) ?? (attrs?["shortName"] as? String) ?? ""
            case "inlineCard", "blockCard", "embedCard":
                return (attrs?["url"] as? String) ?? ""
            case "media", "mediaInline":
                return "[첨부]"
            case "hardBreak":
                return "\n"
            case "date":
                return (attrs?["timestamp"] as? String) ?? ""
            case "status":
                return (attrs?["text"] as? String) ?? ""
            default:
                break
            }

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
