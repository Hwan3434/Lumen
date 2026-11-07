import XCTest
@testable import Lumen

/// 일정 목록 열의 날짜 묶음 규칙과 시계의 다음 경계.
final class AgendaBucketsTests: XCTestCase {
    /// 2026-06-24(수) 오후 1:00 기준.
    private let now = AgendaBucketsTests.dateTime("2026-06-24 13:00")

    func testTasksGoByDueDateAndOverdueSkipsDone() {
        let items = [
            task("late", due: "2026-06-20"),
            task("late-done", due: "2026-06-20", status: .done),
            task("today", due: "2026-06-24"),
            task("tomorrow", due: "2026-06-25"),
            task("this-week", due: "2026-06-27"),
            task("next-week", due: "2026-06-29"),
            task("later", due: "2026-07-10"),
            task("month-edge", due: "2026-07-24"),
            task("too-far", due: "2026-07-25"),
            event("too-far-event", start: "2026-07-25 10:00", end: "2026-07-25 11:00"),
            // 시작일이 지났어도 마감이 내일이면 내일 묶음.
            task("range", start: "2026-06-20", due: "2026-06-25"),
        ]

        let sections = AgendaBuckets.sections(items: items, now: now, firstWeekday: 1)

        XCTAssertEqual(ids(sections, .overdue), ["late"], "완료한 지난 일은 빠진다")
        XCTAssertEqual(ids(sections, .today), ["today"])
        XCTAssertEqual(Set(ids(sections, .tomorrow)), ["tomorrow", "range"])
        XCTAssertEqual(ids(sections, .thisWeek), ["this-week"])
        XCTAssertEqual(ids(sections, .nextWeek), ["next-week"])
        XCTAssertEqual(ids(sections, .later), ["later", "month-edge"], "한 달 뒤 같은 날까지만 들어온다")
        XCTAssertEqual(sections.map(\.bucket), AgendaBucket.allCases, "순서는 묶음 선언 순서")
    }

    func testEventsSkipEndedAndSpansAreLeftOut() {
        let items = [
            event("ended", start: "2026-06-24 09:00", end: "2026-06-24 10:00"),
            event("ongoing", start: "2026-06-24 12:30", end: "2026-06-24 14:00"),
            event("later-today", start: "2026-06-24 15:00", end: "2026-06-24 16:00"),
            allDay("trip", start: "2026-06-22", end: "2026-06-25"),
            allDay("yesterday", start: "2026-06-23", end: nil),
            ScheduleItem(id: "sprint", plugin: .jira, group: "g", title: "sprint", start: dateTime("2026-06-22 00:00"),
                         end: dateTime("2026-06-30 00:00"), isAllDay: true, kind: .span),
        ]

        let sections = AgendaBuckets.sections(items: items, now: now, firstWeekday: 1)

        XCTAssertEqual(ids(sections, .today), ["ongoing", "later-today", "trip"],
                       "끝난 일정은 빠지고, 이어지는 종일 일정은 오늘 묶음에 시간 일정 뒤로")
        XCTAssertTrue(sections.allSatisfy { !$0.items.contains { $0.id == "sprint" || $0.id == "yesterday" } })
    }

    func testWeekBoundaryFollowsFirstWeekday() {
        // 일요일 시작이면 6/28(일)은 다음 주, 월요일 시작이면 이번 주.
        let items = [task("sunday", due: "2026-06-28")]
        XCTAssertEqual(AgendaBuckets.sections(items: items, now: now, firstWeekday: 1).first?.bucket, .nextWeek)
        XCTAssertEqual(AgendaBuckets.sections(items: items, now: now, firstWeekday: 2).first?.bucket, .thisWeek)
    }

    func testNextBoundaryIsEarliestEdgeBeforeMidnight() {
        let items = [
            event("a", start: "2026-06-24 12:30", end: "2026-06-24 14:00"),
            event("b", start: "2026-06-24 15:00", end: "2026-06-24 16:00"),
            allDay("c", start: "2026-06-24", end: nil),
        ]
        XCTAssertEqual(ScheduleStore.nextBoundary(after: now, items: items),
                       dateTime("2026-06-24 14:00").addingTimeInterval(1))
        XCTAssertEqual(ScheduleStore.nextBoundary(after: dateTime("2026-06-24 16:30"), items: items),
                       dateTime("2026-06-25 00:00").addingTimeInterval(1), "남은 일정이 없으면 자정")
    }

    // MARK: - Helpers

    private func ids(_ sections: [AgendaSection], _ bucket: AgendaBucket) -> [String] {
        sections.first { $0.bucket == bucket }?.items.map(\.id) ?? []
    }

    private func task(_ id: String, start: String? = nil, due: String, status: ScheduleItem.Status = .todo) -> ScheduleItem {
        let dueDate = Self.dateTime("\(due) 00:00")
        let startDate = start.map { Self.dateTime("\($0) 00:00") }
        return ScheduleItem(id: id, plugin: .jira, group: "g", title: id, start: startDate ?? dueDate,
                            end: startDate == nil ? nil : dueDate, isAllDay: true, kind: .task, status: status)
    }

    private func event(_ id: String, start: String, end: String) -> ScheduleItem {
        ScheduleItem(id: id, plugin: .calendar, group: "g", title: id, start: Self.dateTime(start),
                     end: Self.dateTime(end), isAllDay: false, kind: .event)
    }

    private func allDay(_ id: String, start: String, end: String?) -> ScheduleItem {
        ScheduleItem(id: id, plugin: .local, group: "g", title: id, start: Self.dateTime("\(start) 00:00"),
                     end: end.map { Self.dateTime("\($0) 00:00") }, isAllDay: true, kind: .event)
    }

    private func dateTime(_ value: String) -> Date { Self.dateTime(value) }

    private static func dateTime(_ value: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: value)!
    }
}
