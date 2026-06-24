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

    func testWeekLayoutPrioritizesLongerBarsAndReportsOverflow() {
        let weekStart = date("2026-06-21")
        let items = [
            CalendarItem(id: "short", kind: .task, title: "Short", start: date("2026-06-22"), end: nil, issueKey: nil, isDone: false, projectKey: "ABC"),
            CalendarItem(id: "long", kind: .task, title: "Long", start: date("2026-06-22"), end: date("2026-06-24"), issueKey: nil, isDone: false, projectKey: "ABC"),
            CalendarItem(id: "overflow", kind: .task, title: "Overflow", start: date("2026-06-22"), end: nil, issueKey: nil, isDone: false, projectKey: "ABC"),
        ]

        let layout = layoutWeek(weekStart: weekStart, items: items, maxLanes: 1)

        XCTAssertEqual(layout.bars.count, 1)
        XCTAssertEqual(layout.bars.first?.item.id, "long")
        XCTAssertEqual(layout.overflowByCol[1], 2)
    }

    private func date(_ value: String) -> Date {
        DateParsers.ymd.date(from: value) ?? Date()
    }
}
