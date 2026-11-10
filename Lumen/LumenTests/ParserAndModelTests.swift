import XCTest
import CoreGraphics
@testable import Lumen

final class ParserAndModelTests: XCTestCase {
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

    func testJiraSettingsNormalizesProjects() {
        let raw = [
            JiraProjectSetting(key: " abc ", alias: " 결제 "),
            JiraProjectSetting(key: "ABC"),
            JiraProjectSetting(key: "def", isVisible: false),
            JiraProjectSetting(key: ""),
            JiraProjectSetting(key: "Def"),
        ]

        let normalized = JiraSettings.normalizedProjects(raw)

        XCTAssertEqual(normalized.map(\.key), ["ABC", "DEF"], "대문자·공백 제거·중복 제거·빈 키 제거")
        XCTAssertEqual(normalized.first?.alias, "결제")
        XCTAssertEqual(normalized.last?.isVisible, false, "표시 여부는 그대로 남는다")
    }

    func testDateParsersHandleJiraDates() {
        XCTAssertNotNil(DateParsers.ymd.date(from: "2026-06-24"))
        XCTAssertNotNil(DateParsers.parseISO8601("2026-06-24T10:20:30.000+0900"))
        XCTAssertNotNil(DateParsers.parseISO8601("2026-06-24T10:20:30+0900"))
    }

    func testJiraPluginBuildsItems() {
        let sprint = SprintInfo(id: 1, name: "Sprint", startDate: date("2026-06-22"),
                                endDate: date("2026-06-26"), projectKey: "ABC")
        let epic = jiraIssue(key: "ABC-1", summary: "Epic", category: .new, priority: "Medium",
                             start: nil, due: date("2026-06-24"), type: "Epic")
        let issue = jiraIssue(key: "ABC-2", summary: "Task", category: .indeterminate, priority: "Highest",
                              start: date("2026-06-23"), due: date("2026-06-25"), type: "Task")
        let done = jiraIssue(key: "ABC-3", summary: "Done", category: .done, priority: "Medium",
                             start: nil, due: date("2026-06-20"), type: "Task")
        let undated = jiraIssue(key: "ABC-4", summary: "No dates", category: .new, priority: "Medium",
                                start: nil, due: nil, type: "Task")

        let items = JiraPlugin.makeItems(
            issues: [issue, done, undated], sprints: [sprint], epics: [epic],
            settings: JiraSettings(), browseURL: URL(string: "https://x.atlassian.net/browse")
        )

        XCTAssertEqual(items.map(\.id), ["jira.sprint.1", "jira.ABC-2", "jira.ABC-1"],
                       "완료 이슈는 기본 숨김, 날짜 없는 이슈는 뺀다")
        XCTAssertEqual(items.map(\.kind), [.span, .task, .task])
        XCTAssertEqual(items[1].status, .inProgress)
        XCTAssertEqual(items[1].priority, .urgent)
        XCTAssertEqual(items[1].start, date("2026-06-23"))
        XCTAssertEqual(items[1].end, date("2026-06-25"))
        XCTAssertEqual(items[1].url?.absoluteString, "https://x.atlassian.net/browse/ABC-2")
        XCTAssertEqual(items[2].subtitle, "ABC-1 · 에픽")
        XCTAssertNil(items[2].end, "마감일만 있으면 한 시점")
        XCTAssertTrue(items.allSatisfy { $0.group == "ABC" && $0.plugin == .jira })

        var showDone = JiraSettings()
        showDone.showDone = true
        let withDone = JiraPlugin.makeItems(issues: [issue, done], sprints: [], epics: [epic, issue],
                                            settings: showDone, browseURL: nil)
        XCTAssertEqual(withDone.map(\.id), ["jira.ABC-2", "jira.ABC-3", "jira.ABC-1"],
                       "담당 이슈이기도 한 에픽은 한 번만 들어간다")
        XCTAssertTrue(withDone[1].isDone)
    }

    func testCalendarPluginBuildsItemsWithUniqueIDs() throws {
        // 반복 이벤트는 회차마다 같은 식별자를 쓰므로 시작 시각으로 id를 가른다.
        let first = try XCTUnwrap(ExternalCalendarEvent(
            id: "rec", title: "요가", startDate: dateTime("2026-06-22 19:30"), endDate: dateTime("2026-06-22 20:30"),
            isAllDay: false, calendarIdentifier: "cal-1", calendarTitle: "개인", sourceTitle: "iCloud",
            notes: nil, location: "스튜디오", urlString: nil))
        let second = try XCTUnwrap(ExternalCalendarEvent(
            id: "rec", title: "요가", startDate: dateTime("2026-06-24 19:30"), endDate: dateTime("2026-06-24 20:30"),
            isAllDay: false, calendarIdentifier: "cal-1", calendarTitle: "개인", sourceTitle: "iCloud",
            notes: nil, location: nil, urlString: nil))
        // EventKit의 종일 끝은 다음날 0시다.
        let trip = try XCTUnwrap(ExternalCalendarEvent(
            id: "trip", title: "여행", startDate: date("2026-06-26"), endDate: date("2026-06-28"),
            isAllDay: true, calendarIdentifier: "cal-2", calendarTitle: "가족", sourceTitle: nil,
            notes: nil, location: nil, urlString: nil))

        let items = [first, second, trip].map(CalendarPlugin.makeItem)

        XCTAssertNotEqual(items[0].id, items[1].id)
        XCTAssertTrue(items[0].hasTimeOfDay)
        XCTAssertEqual(items[0].group, "cal-1")
        XCTAssertEqual(items[0].location, "스튜디오")
        XCTAssertEqual(items[0].subtitle, "개인")
        XCTAssertTrue(items[2].isAllDay)
        XCTAssertEqual(items[2].end, date("2026-06-27"), "종일 범위는 끝 날짜를 하루 당겨 포함 범위로")
    }

    func testWeekLayoutUsesSharedDisplayOrderAndReportsOverflow() {
        let weekStart = date("2026-06-21")
        let items = [
            item("late", kind: .event, start: dateTime("2026-06-22 15:00"), end: dateTime("2026-06-22 16:00"), allDay: false),
            item("all-day", kind: .task, start: date("2026-06-22")),
            item("early", kind: .event, start: dateTime("2026-06-22 09:00"), end: dateTime("2026-06-22 10:00"), allDay: false),
        ]

        let layout = layoutWeek(weekStart: weekStart, items: items, maxLanes: 1)

        XCTAssertEqual(layout.bars.count, 1)
        XCTAssertEqual(layout.bars.first?.item.id, "early")
        XCTAssertEqual(layout.overflowByCol[1], 2)
    }

    func testCalendarItemSortOrdersTimedItemsWithinDate() {
        let items = [
            item("all-day", kind: .task, start: date("2026-06-22")),
            item("tomorrow", kind: .event, start: dateTime("2026-06-23 09:00"), end: dateTime("2026-06-23 10:00"), allDay: false),
            item("late", kind: .event, start: dateTime("2026-06-22 15:00"), end: dateTime("2026-06-22 16:00"), allDay: false),
            item("early", kind: .event, start: dateTime("2026-06-22 09:00"), end: dateTime("2026-06-22 10:00"), allDay: false),
        ]

        XCTAssertEqual(CalendarItemSort.ordered(items).map(\.id), ["early", "late", "all-day", "tomorrow"])
    }

    func testStartOfWeekFollowsFirstWeekday() {
        // 2026-06-24는 수요일.
        let wednesday = date("2026-06-24")
        XCTAssertEqual(CalendarDateUtils.startOfWeek(of: wednesday, firstWeekday: 1), date("2026-06-21"))
        XCTAssertEqual(CalendarDateUtils.startOfWeek(of: wednesday, firstWeekday: 2), date("2026-06-22"))
        XCTAssertEqual(CalendarDateUtils.weekdaySymbols(firstWeekday: 2), ["월", "화", "수", "목", "금", "토", "일"])
    }

    func testCommentPageOrdersOldestFirst() {
        // Jira는 orderBy=-created로 최신순을 주지만, 표시는 대화 흐름대로 뒤집어야 한다.
        let page: [String: Any] = [
            "total": 12,
            "comments": [
                commentJSON(id: "3", author: "최신", body: "newest", created: "2026-06-23T10:00:00.000+0900"),
                commentJSON(id: "2", author: "중간", body: "middle", created: "2026-06-22T10:00:00.000+0900"),
            ],
        ]

        let result = JiraRepository.parseCommentPage(page)

        XCTAssertEqual(result.total, 12, "전체 개수는 응답의 total을 그대로 쓴다")
        XCTAssertEqual(result.comments.map(\.id), ["2", "3"], "오래된 것부터 최신 순")
        XCTAssertEqual(result.comments.first?.bodyText, "middle")
        XCTAssertNotNil(result.comments.first?.created)
    }

    /// 멘션·이모지·첨부만 있는 댓글이 통째로 사라지던 회귀를 막는다.
    func testCommentPageKeepsNonTextOnlyComments() {
        let mentionOnly: [String: Any] = [
            "id": "10",
            "author": ["displayName": "홍길동"],
            "body": [
                "type": "doc",
                "content": [["type": "paragraph", "content": [
                    ["type": "mention", "attrs": ["text": "@김철수"]],
                    ["type": "emoji", "attrs": ["text": "👍"]],
                ]]],
            ],
        ]
        let attachmentOnly: [String: Any] = [
            "id": "11",
            "author": ["displayName": "김철수"],
            "body": ["type": "doc", "content": [["type": "mediaSingle", "content": [["type": "media"]]]]],
        ]
        // id가 숫자로 오는 응답도 버리지 않는다.
        let numericID: [String: Any] = [
            "id": 12,
            "body": ["type": "doc", "content": [["type": "paragraph", "content": [["type": "text", "text": "hi"]]]]],
        ]

        let result = JiraRepository.parseCommentPage(["total": 3, "comments": [numericID, attachmentOnly, mentionOnly]])

        XCTAssertEqual(result.comments.count, 3, "본문이 비어도 댓글 자체는 유지")
        XCTAssertEqual(result.comments.map(\.id), ["10", "11", "12"])
        XCTAssertEqual(result.comments.first?.bodyText, "@김철수👍", "멘션·이모지도 평문으로 뽑아낸다")
        XCTAssertEqual(result.comments[1].bodyText, "[첨부]")
    }

    func testCommentAcceptsPlainStringBody() {
        let page: [String: Any] = [
            "total": 1,
            "comments": [["id": "1", "body": "  평문 본문  ", "author": ["displayName": "홍길동"]]],
        ]

        let result = JiraRepository.parseCommentPage(page)

        XCTAssertEqual(result.comments.first?.bodyText, "평문 본문", "ADF가 아닌 문자열 body도 받는다")
    }

    /// 하루가 넘으면 "50시간 전"이 아니라 일 단위로 말한다 — 저장된 리소스 이상 기록은 며칠 전 것도 보인다.
    func testRelativeTimeStepsUpToDays() {
        let now = Date()
        XCTAssertEqual(LumenTime.relative(now.addingTimeInterval(-30)), "방금")
        XCTAssertEqual(LumenTime.relative(now.addingTimeInterval(-50 * 60 - 5)), "50분 전")
        XCTAssertEqual(LumenTime.relative(now.addingTimeInterval(-5 * 3600 - 5)), "5시간 전")
        XCTAssertEqual(LumenTime.relative(now.addingTimeInterval(-50 * 3600 - 5)), "2일 전")
    }

    /// 절대 시각은 Still 표기("오후 2:30", "11. 7")를 쓴다. 24시간제나 "11월 7일"이 아니다.
    func testCalendarTimeUsesStillFormat() {
        let cal = Calendar.current
        let todayAfternoon = cal.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
        XCTAssertEqual(LumenTime.relative(todayAfternoon, granularity: .calendar), "오늘 오후 2:30")
        XCTAssertEqual(LumenTime.relative(dateTime("2026-01-07 09:05"), granularity: .calendar), "1. 7 오전 9:05")
    }

    /// 넓게는 Still 값 그대로다. 단위 맞춤(2·4 단위)은 줄이는 밀도에만 적용한다.
    func testSpaciousDensityKeepsStillSpacing() {
        for base: CGFloat in [2, 3, 6, 9, 10, 12, 14, 16, 24] {
            XCTAssertEqual(LumenDensity.spacious.space(base), base)
        }
        XCTAssertEqual(LumenDensity.cozy.space(14), 8)
        XCTAssertEqual(LumenDensity.regular.space(10), 8)
    }

    func testMagnetOptionsFollowSteps() {
        let options = WindowMagnetViewModel().options
        XCTAssertEqual(options.map(\.ratio), Constants.magnetSteps + Constants.magnetSteps)
        XCTAssertEqual(options.first?.label, "← 왼쪽 20%")
        XCTAssertEqual(options.last?.label, "→ 오른쪽 100%")
    }

    // MARK: - Helpers

    private func date(_ ymd: String) -> Date {
        DateParsers.ymd.date(from: ymd)!
    }

    private func dateTime(_ value: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: value)!
    }

    private func item(_ id: String, kind: ScheduleItem.Kind, start: Date, end: Date? = nil, allDay: Bool = true) -> ScheduleItem {
        ScheduleItem(id: id, plugin: .local, group: "g", title: id, start: start, end: end, isAllDay: allDay, kind: kind)
    }

    private func jiraIssue(key: String, summary: String, category: JiraStatusCategory, priority: String,
                           start: Date?, due: Date?, type: String) -> JiraIssue {
        JiraIssue(id: key, key: key, summary: summary, status: "", statusCategory: category, priority: priority,
                  startDate: start, dueDate: due, issueType: type,
                  projectKey: key.split(separator: "-").first.map(String.init) ?? "")
    }

    private func commentJSON(id: String, author: String, body: String, created: String) -> [String: Any] {
        [
            "id": id,
            "author": ["displayName": author],
            "body": ["type": "doc", "content": [["type": "paragraph", "content": [["type": "text", "text": body]]]]],
            "created": created,
        ]
    }
}
