import AppKit
import EventKit
import SwiftUI

/// 메뉴바의 캘린더 위젯 — 다음 일정을 라벨로 표기, 클릭 시 오늘 일정 popover.
/// JiraDashboardFeature가 attachStatusBar 시점에 인스턴스를 만든다.
@MainActor
final class CalendarStatusItem {
    private let handle: StatusBarItemHandle
    private var panel: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var refreshTimer: Timer?
    private var observer: NSObjectProtocol?

    init(coordinator: StatusBarCoordinator) {
        self.handle = coordinator.addItem(
            initialIcon: Self.todayIconName(),
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
        if panel != nil {
            closePanel()
            return
        }
        showPanel()
    }

    private func showPanel() {
        guard let button = handle.buttonView,
              let buttonWindow = button.window else { return }

        let size = NSSize(width: 320, height: 420)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: TodayAgendaPopover())

        // 메뉴바 버튼 아래 정렬.
        let buttonInWindow = button.convert(button.bounds, to: nil as NSView?)
        let buttonFrameInScreen = buttonWindow.convertToScreen(buttonInWindow)
        let x = buttonFrameInScreen.midX - size.width / 2
        let y = buttonFrameInScreen.minY - size.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()

        self.panel = panel

        // 외부 클릭/Esc 시 닫기.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            if event.type == .keyDown, event.keyCode == 0x35 { // Escape
                self?.closePanel()
                return nil
            }
            if event.type != .keyDown, event.window !== self?.panel {
                self?.closePanel()
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanel() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        panel?.orderOut(nil)
        panel = nil
    }

    func refresh() {
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        let items = todaysCalendarItems()

        handle.updateIcon(Self.todayIconName())

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
        // 3순위: 둘 다 없음 — 라벨 비우면 아이콘만 보인다.
        handle.updateTitle("")
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

    /// 오늘 일자(1~31)에 해당하는 SF Symbol — 자정 넘으면 다음 날짜로 자연스럽게 바뀐다.
    private static func todayIconName() -> String {
        let day = Calendar.current.component(.day, from: Date())
        return "\(day).square.fill"
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
