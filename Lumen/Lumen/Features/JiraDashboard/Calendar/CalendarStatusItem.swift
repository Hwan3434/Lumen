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
    private var lastClosedAt: Date = .distantPast
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
        // 닫힌 직후(0.3초 이내) 재클릭이면 무시 — localMonitor closePanel과 togglePopover가 같은 틱에 실행되는 문제 방지.
        if panel != nil || Date().timeIntervalSince(lastClosedAt) < 0.3 {
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
                let isButtonWindow = self?.handle.buttonView?.window === event.window
                if isButtonWindow {
                    self?.lastClosedAt = Date()
                }
                self?.closePanel()
            }
            return event
        }
    }

    private func closePanel() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
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

        // 상태바 라벨은 캘린더/로컬만 — Jira 이슈는 팝오버에서만 보임.
        let labelItems = items.filter { $0.kind == .googleCalendar || $0.kind == .local }

        if let next = labelItems.filter({ $0.hasTimeOfDay && ($0.end ?? $0.start) > now && $0.start < tomorrow })
            .min(by: { $0.start < $1.start }) {
            var label = "\(Self.format(next.start))  \(Self.truncate(next.title))"
            if let loc = next.location, !loc.isEmpty { label += " · \(Self.truncate(loc))" }
            handle.updateTitle(label)
            return
        }
        if let allDay = labelItems.first(where: { !$0.hasTimeOfDay }) {
            var label = Self.truncate(allDay.title)
            if let loc = allDay.location, !loc.isEmpty { label += " · \(Self.truncate(loc))" }
            handle.updateTitle(label)
            return
        }
        // 3순위: 둘 다 없음 — 라벨 비우면 아이콘만 보인다.
        handle.updateTitle("")
    }

    private func todaysCalendarItems() -> [CalendarItem] {
        let day = Date()
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
                id: "gcal-\(ev.eventIdentifier ?? ev.calendarItemIdentifier)", kind: .googleCalendar,
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
