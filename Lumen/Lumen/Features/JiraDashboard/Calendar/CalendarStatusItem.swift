import AppKit
import EventKit
import SwiftUI

/// 메뉴바의 캘린더 위젯 — 다음 일정을 라벨로 표기, 클릭 시 오늘 일정 popover.
/// JiraDashboardFeature가 attachStatusBar 시점에 인스턴스를 만든다.
@MainActor
final class CalendarStatusItem {
    private let handle: StatusBarItemHandle
    private let popover: NSPopover
    private var refreshTimer: Timer?
    private var observation: NSKeyValueObservation?
    private var observer: NSObjectProtocol?

    init(coordinator: StatusBarCoordinator) {
        let hosting = NSHostingController(rootView: TodayAgendaPopover())
        hosting.view.frame.size = NSSize(width: 320, height: 200)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 200)
        popover.contentViewController = hosting
        self.popover = popover

        // 두 단계로 만든다: handle을 먼저 만들고, onClick 클로저는 init 끝난 뒤 self를 통해 다룬다.
        // (init 안에서 handle을 캡처하면 self가 아직 완성되지 않아 self.handle 접근이 안 된다.)
        self.handle = coordinator.addItem(
            initialIcon: "calendar",
            accessibility: "오늘 일정",
            visible: true,
            variableLength: true,
            onClick: { /* 아래 wireOnClick에서 채움 */ }
        )
        wireOnClick()

        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                EventKitService.shared.fetch()
                self?.refresh()
            }
        }
        // 시간 흐름에 따라 "다음 일정"이 바뀌므로 1분마다 갱신.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit {
        refreshTimer?.invalidate()
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    private func wireOnClick() {
        handle.setOnClick { [weak self] in self?.togglePopover() }
    }

    func togglePopover() {
        guard let button = handle.buttonView else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func refresh() {
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        let items = todaysCalendarItems()

        // 1순위: 가장 가까운 시간 이벤트 (지금 진행 중이거나 아직 시작 안 한 것).
        if let next = items.filter({ $0.hasTimeOfDay && ($0.end ?? $0.start) > now && $0.start < tomorrow })
            .sorted(by: { $0.start < $1.start })
            .first {
            handle.updateTitle("\(Self.format(next.start))  \(Self.truncate(next.title))")
            return
        }
        // 2순위: 종일/마감 항목 1개.
        if let allDay = items.first(where: { !$0.hasTimeOfDay }) {
            handle.updateTitle(Self.truncate(allDay.title))
            return
        }
        // 3순위: 둘 다 없음.
        handle.updateTitle("일정 없음")
    }

    private func todaysCalendarItems() -> [CalendarItem] {
        let day = Date()
        if let data = JiraService.shared.data {
            return CalendarAdapter.buildItems(from: data, includeLocal: true).filter { $0.covers(day) }
        }
        // Jira 데이터 없으면 EKEvent + 로컬만 포함.
        var items: [CalendarItem] = []
        let cal = Calendar.current
        for ev in LocalEventStore.shared.events {
            items.append(CalendarItem(
                id: "local-\(ev.id.uuidString)", kind: .local, title: ev.title,
                start: ev.start, end: ev.end, issueKey: nil, isDone: false, projectKey: nil
            ))
        }
        for ev in EventKitService.shared.events {
            guard let start = ev.startDate, let end = ev.endDate else { continue }
            let effectiveEnd = ev.isAllDay ? cal.date(byAdding: .day, value: -1, to: end) ?? end : end
            items.append(CalendarItem(
                id: "gcal-\(ev.eventIdentifier ?? UUID().uuidString)", kind: .googleCalendar,
                title: ev.title ?? "(제목 없음)",
                start: start,
                end: ev.isAllDay
                    ? (cal.isDate(start, inSameDayAs: effectiveEnd) ? nil : effectiveEnd)
                    : end,
                issueKey: nil, isDone: false, projectKey: nil,
                hasTimeOfDay: !ev.isAllDay
            ))
        }
        return items.filter { $0.covers(day) }
    }

    private static func truncate(_ s: String) -> String {
        s.count > 18 ? s.prefix(18) + "…" : s
    }

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h a"
        return f
    }()

    private static let minuteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f
    }()

    private static func format(_ date: Date) -> String {
        let m = Calendar.current.component(.minute, from: date)
        return (m == 0 ? hourFormatter : minuteFormatter).string(from: date)
    }
}
