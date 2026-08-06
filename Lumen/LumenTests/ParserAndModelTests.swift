import XCTest
import CoreGraphics
@testable import Lumen

final class ParserAndModelTests: XCTestCase {
    override func tearDown() {
        CredentialsStore.shared.setJiraProjectKeys([])
        CredentialsStore.shared.setJiraProjectNames([:])
        super.tearDown()
    }

    func testCurrencyQueryParsesCommonInputs() {
        XCTAssertEqual(CurrencyQuery.parse("$100")?.amount, 100)
        XCTAssertEqual(CurrencyQuery.parse("$100")?.from, "USD")
        XCTAssertEqual(CurrencyQuery.parse("$100")?.to, "KRW")

        XCTAssertEqual(CurrencyQuery.parse("100 usd")?.amount, 100)
        XCTAssertEqual(CurrencyQuery.parse("5만원")?.amount, 50_000)
        XCTAssertEqual(CurrencyQuery.parse("1.5천원")?.amount, 1_500)
        XCTAssertNil(CurrencyQuery.parse("hello"))
    }

    func testJiraStatusCategoryMapping() {
        XCTAssertEqual(JiraStatusCategory(rawAPIKey: "new"), .new)
        XCTAssertEqual(JiraStatusCategory(rawAPIKey: "indeterminate"), .indeterminate)
        XCTAssertEqual(JiraStatusCategory(rawAPIKey: "done"), .done)
        XCTAssertEqual(JiraStatusCategory(rawAPIKey: "custom"), .undefined)
    }

    func testCredentialsStoreNormalizesProjectKeys() {
        CredentialsStore.shared.setJiraProjectKeys([" abc ", "ABC", "def", "", "Def"])

        XCTAssertEqual(CredentialsStore.shared.jiraProjectKeys, ["ABC", "DEF"])
    }

    func testDateParsersHandleJiraDates() {
        XCTAssertNotNil(DateParsers.ymd.date(from: "2026-06-24"))
        XCTAssertNotNil(DateParsers.parseISO8601("2026-06-24T10:20:30.000+0900"))
        XCTAssertNotNil(DateParsers.parseISO8601("2026-06-24T10:20:30+0900"))
    }

    func testCalendarAdapterBuildsJiraItems() {
        let sprint = SprintInfo(
            id: 1,
            name: "Sprint",
            startDate: date("2026-06-22"),
            endDate: date("2026-06-26"),
            projectKey: "ABC",
            totalIssues: 10,
            completedIssues: 5
        )
        let epic = EpicInfo(
            key: "ABC-1",
            summary: "Epic",
            projectKey: "ABC",
            status: "To Do",
            dueDate: date("2026-06-24")
        )
        let issue = JiraIssue(
            id: "ABC-2",
            key: "ABC-2",
            summary: "Task",
            status: "In Progress",
            statusCategory: .indeterminate,
            priority: "Medium",
            startDate: date("2026-06-23"),
            dueDate: date("2026-06-25"),
            resolutionDate: nil,
            created: nil,
            issueType: "Task",
            projectKey: "ABC"
        )
        let data = JiraDashboardData(
            thisWeekCounts: JiraStatusCounts(),
            projectStats: [],
            todayIssues: [],
            thisWeekIssues: [],
            highestIncomplete: [],
            overdueIncomplete: [],
            completedLast30: [],
            createdLast30: [],
            nextWeekIssues: [],
            backlogCountByProject: [:],
            sprintInfos: [sprint],
            epicInfos: [epic],
            allIssuesInWindow: [issue],
            lastUpdated: Date()
        )

        let localEvent = LocalEvent(title: "Local", start: date("2026-06-24"))
        let externalEvent = ExternalCalendarEvent(
            id: "event-1",
            title: "Calendar",
            startDate: date("2026-06-24"),
            endDate: date("2026-06-24"),
            isAllDay: true,
            calendarTitle: "Work",
            sourceTitle: "Google",
            calendarColor: CGColor(gray: 1, alpha: 1),
            notes: nil,
            location: "Seoul",
            urlString: nil
        )

        let items = CalendarAdapter.buildItems(
            from: data,
            localEvents: [localEvent],
            externalEvents: [externalEvent].compactMap { $0 }
        )

        XCTAssertEqual(items.map(\.kind), [.sprint, .epic, .local, .googleCalendar, .task])
        XCTAssertEqual(items.map(\.projectKey), ["ABC", "ABC", nil, nil, "ABC"])
    }

    func testWeekLayoutUsesSharedDisplayOrderAndReportsOverflow() {
        let weekStart = date("2026-06-21")
        let items = [
            CalendarItem(id: "late", kind: .googleCalendar, title: "Late", start: dateTime("2026-06-22 15:00"), end: dateTime("2026-06-22 16:00"), issueKey: nil, isDone: false, projectKey: nil, hasTimeOfDay: true),
            CalendarItem(id: "all-day", kind: .task, title: "All Day", start: date("2026-06-22"), end: nil, issueKey: nil, isDone: false, projectKey: "ABC"),
            CalendarItem(id: "early", kind: .googleCalendar, title: "Early", start: dateTime("2026-06-22 09:00"), end: dateTime("2026-06-22 10:00"), issueKey: nil, isDone: false, projectKey: nil, hasTimeOfDay: true),
        ]

        let layout = layoutWeek(weekStart: weekStart, items: items, maxLanes: 1)

        XCTAssertEqual(layout.bars.count, 1)
        XCTAssertEqual(layout.bars.first?.item.id, "early")
        XCTAssertEqual(layout.overflowByCol[1], 2)
    }

    func testCalendarItemSortOrdersTimedItemsWithinDate() {
        let items = [
            CalendarItem(id: "all-day", kind: .task, title: "All Day", start: date("2026-06-22"), end: nil, issueKey: nil, isDone: false, projectKey: "ABC"),
            CalendarItem(id: "tomorrow", kind: .googleCalendar, title: "Tomorrow", start: dateTime("2026-06-23 09:00"), end: dateTime("2026-06-23 10:00"), issueKey: nil, isDone: false, projectKey: nil, hasTimeOfDay: true),
            CalendarItem(id: "late", kind: .googleCalendar, title: "Late", start: dateTime("2026-06-22 15:00"), end: dateTime("2026-06-22 16:00"), issueKey: nil, isDone: false, projectKey: nil, hasTimeOfDay: true),
            CalendarItem(id: "early", kind: .googleCalendar, title: "Early", start: dateTime("2026-06-22 09:00"), end: dateTime("2026-06-22 10:00"), issueKey: nil, isDone: false, projectKey: nil, hasTimeOfDay: true),
        ]

        XCTAssertEqual(CalendarItemSort.ordered(items).map(\.id), ["early", "late", "all-day", "tomorrow"])
    }

    func testCommentPageOrdersOldestFirstAndSkipsEmptyBodies() {
        // Jira는 orderBy=-created로 최신순을 주지만, 표시는 대화 흐름대로 뒤집어야 한다.
        let page: [String: Any] = [
            "total": 12,
            "comments": [
                commentJSON(id: "3", author: "최신", body: "newest", created: "2026-06-23T10:00:00.000+0900"),
                commentJSON(id: "2", author: "중간", body: "middle", created: "2026-06-22T10:00:00.000+0900"),
                commentJSON(id: "1", author: nil, body: "", created: "2026-06-21T10:00:00.000+0900"),
            ],
        ]

        let result = JiraRepository.parseCommentPage(page)

        XCTAssertEqual(result.total, 12, "전체 개수는 응답의 total을 그대로 쓴다")
        XCTAssertEqual(result.comments.map(\.id), ["2", "3"], "본문 없는 댓글은 빼고 오래된 것부터")
        XCTAssertEqual(result.comments.first?.bodyText, "middle")
        XCTAssertNotNil(result.comments.first?.created)
    }

    func testCommentPageFallsBackWhenTotalMissing() {
        let page: [String: Any] = [
            "comments": [commentJSON(id: "1", author: nil, body: "hi", created: nil)],
        ]

        let result = JiraRepository.parseCommentPage(page)

        XCTAssertEqual(result.total, 1, "total이 없으면 파싱된 개수로 대체")
        XCTAssertEqual(result.comments.first?.author, "알 수 없음")
        XCTAssertNil(result.comments.first?.created)
        XCTAssertTrue(JiraRepository.parseCommentPage([:]).comments.isEmpty, "빈 응답도 크래시 없이 처리")
    }

    /// Jira 댓글 한 건의 응답 형태 — body는 ADF 문서.
    private func commentJSON(id: String, author: String?, body: String, created: String?) -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "body": [
                "type": "doc",
                "content": [["type": "paragraph", "content": [["type": "text", "text": body]]]],
            ],
        ]
        if let author { dict["author"] = ["displayName": author] }
        if let created { dict["created"] = created }
        return dict
    }

    private func date(_ value: String) -> Date {
        DateParsers.ymd.date(from: value) ?? Date()
    }

    private func dateTime(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: value) ?? Date()
    }
}
