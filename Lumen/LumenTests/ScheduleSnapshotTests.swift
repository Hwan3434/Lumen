import XCTest
import SwiftUI
import AppKit
@testable import Lumen

/// 일정 대시보드를 네트워크 없이 가짜 플러그인으로 채워 오프스크린 렌더링하고 PNG로 떨군다.
/// 연동 없이도 화면이 그려지는지, 묶음 색과 막대가 제자리에 오는지 눈으로 확인하기 위한 것.
///
/// 출력 경로는 환경변수 `LUMEN_SNAPSHOT_DIR`, 없으면 임시 디렉터리.
@MainActor
final class ScheduleSnapshotTests: XCTestCase {

    func testRenderDashboardMonthAndWeek() async throws {
        let store = await Self.sampleStore()
        let saved = DashboardSettingsStore.shared.settings.defaultView
        defer { DashboardSettingsStore.shared.settings.defaultView = saved }

        // 오프스크린 창에서는 onAppear의 scrollTo가 첫 레이아웃 전에 지나가 버린다.
        // 실제 앱의 ⌘1/⌘2 경로(보기 전환 → 오늘로 점프)를 그대로 타서 오늘 주로 옮긴다.
        DashboardSettingsStore.shared.settings.defaultView = .month
        try render(ScheduleView().environment(store), size: Constants.scheduleWindowSize, named: "schedule-month.png") {
            NotificationCenter.default.post(name: .scheduleSwitchView, object: CalendarMode.week)
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            NotificationCenter.default.post(name: .scheduleSwitchView, object: CalendarMode.month)
        }

        try render(ScheduleView().environment(store), size: Constants.scheduleWindowSize, named: "schedule-week.png") {
            NotificationCenter.default.post(name: .scheduleSwitchView, object: CalendarMode.week)
        }
    }

    func testRenderTodayAgendaPopover() async throws {
        let store = await Self.sampleStore()
        try render(TodayAgendaPopover().environment(store), size: Constants.agendaPanelSize, named: "schedule-today.png")
    }

    func testRenderSettingsScheduleTabs() throws {
        let action = SettingsActionViewModel()
        let size = NSSize(width: Constants.settingsWindowSize.width - LumenTokens.Space.size(220),
                          height: Constants.settingsWindowSize.height)
        try render(DashboardSettingsTab(action: action), size: size, named: "settings-dashboard.png")
        try render(CalendarSettingsTab(plugin: CalendarPlugin.shared, action: action), size: size, named: "settings-calendar.png")
    }

    // MARK: - Sample data

    /// 오늘을 기준으로 앞뒤 2주에 캘린더 이벤트, Jira 이슈, 내 일정을 흩어 놓는다.
    private static func sampleStore() async -> ScheduleStore {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func day(_ offset: Int, hour: Int = 0, minute: Int = 0) -> Date {
            let d = cal.date(byAdding: .day, value: offset, to: today)!
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: d)!
        }

        let calendar = FakeSchedulePlugin(name: "캘린더", icon: "calendar", groups: [("개인", true), ("업무", true)])
        calendar.items = [
            event(calendar.id, "업무", "주간 회의", day(-6, hour: 10), day(-6, hour: 11)),
            event(calendar.id, "업무", "디자인 리뷰", day(0, hour: 11), day(0, hour: 12), location: "회의실 B"),
            event(calendar.id, "개인", "치과 예약", day(0, hour: 14), day(0, hour: 14, minute: 40)),
            event(calendar.id, "개인", "요가", day(2, hour: 19, minute: 30), day(2, hour: 20, minute: 30)),
            event(calendar.id, "업무", "1:1 미팅", day(3, hour: 15), day(3, hour: 15, minute: 30)),
            event(calendar.id, "업무", "워크숍", day(9), day(10), allDay: true),
            event(calendar.id, "개인", "친구 생일", day(7), nil, allDay: true),
        ]

        let jira = FakeSchedulePlugin(name: "Jira", icon: "square-kanban", groups: [("PROJ", true), ("ABC", true)])
        jira.items = [
            ScheduleItem(id: "jira.sprint.1", plugin: jira.id, group: "PROJ", title: "스프린트 23",
                         start: day(-5), end: day(6), isAllDay: true, kind: .span, subtitle: "스프린트"),
            task(jira.id, "PROJ", "PROJ-142", "결제 모듈 타임아웃 재현", due: day(-2), status: .inProgress),
            task(jira.id, "ABC", "ABC-88", "로그인 오류 수정", due: day(-1), status: .todo, priority: .urgent),
            task(jira.id, "PROJ", "PROJ-156", "온보딩 카피 검토", due: day(0), status: .todo),
            task(jira.id, "PROJ", "PROJ-160", "알림 설정 화면", start: day(2), due: day(5), status: .todo),
            task(jira.id, "ABC", "ABC-91", "API 문서 갱신", due: day(4), status: .inProgress, priority: .high),
            task(jira.id, "ABC", "ABC-95", "릴리스 1.6", start: day(9), due: day(11), status: .todo),
        ]

        let local = FakeSchedulePlugin(name: "내 일정", icon: "calendar-plus", groups: [("local", true)])
        local.items = [
            event(local.id, "local", "자동차 정기 점검", day(1), nil, allDay: true),
            event(local.id, "local", "본가 방문", day(14), day(15), allDay: true),
        ]

        let store = ScheduleStore(plugins: [calendar, jira, local])
        await store.refreshAll(force: true)
        return store
    }

    private static func event(_ plugin: SchedulePluginID, _ group: String, _ title: String,
                              _ start: Date, _ end: Date?, allDay: Bool = false, location: String? = nil) -> ScheduleItem {
        ScheduleItem(id: "\(plugin.rawValue).\(title).\(start.timeIntervalSince1970)", plugin: plugin, group: group,
                     title: title, start: start, end: end, isAllDay: allDay, kind: .event,
                     subtitle: group, location: location)
    }

    private static func task(_ plugin: SchedulePluginID, _ group: String, _ key: String, _ title: String,
                             start: Date? = nil, due: Date, status: ScheduleItem.Status,
                             priority: ScheduleItem.Priority? = nil) -> ScheduleItem {
        ScheduleItem(id: "\(plugin.rawValue).\(key)", plugin: plugin, group: group, title: title,
                     start: start ?? due, end: start == nil ? nil : due, isAllDay: true, kind: .task,
                     status: status, priority: priority, subtitle: key,
                     url: URL(string: "https://example.atlassian.net/browse/\(key)"))
    }

    // MARK: - Rendering

    /// 첫 레이아웃 뒤에 `afterFirstLayout`을 한 번 부르고(보기 전환 같은 상호작용), 다시 기다린 뒤 찍는다.
    private func render(_ view: some View, size: NSSize, named name: String,
                        afterFirstLayout: (() -> Void)? = nil) throws {
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, .dark))
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hosting
        window.setIsVisible(true)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        if let afterFirstLayout {
            afterFirstLayout()
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        }

        let rep = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds), "캡처 실패")
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        let dir = ProcessInfo.processInfo.environment["LUMEN_SNAPSHOT_DIR"]
            .map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let out = dir.appendingPathComponent(name)
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try png.write(to: out)
        window.setIsVisible(false)
        print("[snapshot] \(out.path) (\(png.count) bytes, \(Int(hosting.bounds.width))x\(Int(hosting.bounds.height)))")
    }
}
