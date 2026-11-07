import AppKit
import Observation
import SwiftUI

/// 메뉴바의 일정 위젯 — 다음 일정을 라벨로 표기, 클릭 시 오늘 일정 popover.
/// `ScheduleFeature`가 attachStatusBar 시점에 인스턴스를 만든다.
@MainActor
final class ScheduleStatusItem {
    private let handle: StatusBarItemHandle
    private let store: ScheduleStore
    private var panel: NSPanel?
    private var localMonitor: Any?
    private var lastClosedAt: Date = .distantPast
    private var refreshTimer: Timer?

    init(coordinator: StatusBarCoordinator, store: ScheduleStore) {
        self.store = store
        self.handle = coordinator.addItem(
            initialIcon: Self.todayIconName(),
            accessibility: "오늘 일정",
            visible: DashboardSettingsStore.shared.settings.menuBarLabel,
            variableLength: true,
            onClick: { /* 아래 setOnClick에서 채움 */ }
        )
        handle.setOnClick { [weak self] in self?.togglePopover() }

        refresh()
        observeStore()
        if handle.isVisible { startTimer() }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func setVisible(_ visible: Bool) {
        if visible {
            handle.show()
            refresh()
            startTimer()
        } else {
            closePanel()
            handle.hide()
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    /// 라벨이 보이는 동안만 1분마다 "다음 일정"을 다시 고른다. 숨기면 멈춘다.
    private func startTimer() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    /// 스토어의 보이는 항목이 바뀌면 라벨을 다시 쓴다. 한 번 발화하면 다시 등록한다.
    private func observeStore() {
        withObservationTracking {
            _ = store.visibleItems
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh()
                self?.observeStore()
            }
        }
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

        let size = Constants.agendaPanelSize
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
        panel.contentView = NSHostingView(rootView: TodayAgendaPopover().environment(store))

        // 메뉴바 버튼 아래 정렬.
        let buttonInWindow = button.convert(button.bounds, to: nil as NSView?)
        let buttonFrameInScreen = buttonWindow.convertToScreen(buttonInWindow)
        let x = buttonFrameInScreen.midX - size.width / 2
        let y = buttonFrameInScreen.minY - size.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()

        self.panel = panel
        Task { await store.refreshStale() }

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

    /// 라벨 규칙: 아직 끝나지 않은 가장 이른 시간 일정 → 종일 일정 → 없으면 아이콘만.
    /// 라벨에 올리는 플러그인(`contributesToMenuBarLabel`)의 항목만 본다.
    func refresh() {
        let now = Date()
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
        let labelPlugins = Set(store.enabledPlugins.filter(\.contributesToMenuBarLabel).map(\.id))
        let items = CalendarItemSort.ordered(store.items(on: now).filter { labelPlugins.contains($0.plugin) })

        handle.updateIcon(Self.todayIconName())

        if let next = items.filter({ $0.hasTimeOfDay && ($0.end ?? $0.start) > now && $0.start < tomorrow })
            .min(by: { $0.start < $1.start }) {
            var label = "\(LumenDateFormat.time.string(from: next.start))  \(Self.truncate(next.title))"
            if let loc = next.location, !loc.isEmpty { label += " · \(Self.truncate(loc))" }
            handle.updateTitle(label)
            return
        }
        if let allDay = items.first(where: { !$0.hasTimeOfDay }) {
            var label = Self.truncate(allDay.title)
            if let loc = allDay.location, !loc.isEmpty { label += " · \(Self.truncate(loc))" }
            handle.updateTitle(label)
            return
        }
        handle.updateTitle("")
    }

    private static func truncate(_ s: String) -> String {
        s.count > 18 ? s.prefix(18) + "…" : s
    }

    /// 오늘 일자(1~31)에 해당하는 SF Symbol — 자정 넘으면 다음 날짜로 자연스럽게 바뀐다.
    private static func todayIconName() -> String {
        let day = Calendar.current.component(.day, from: Date())
        return "\(day).square.fill"
    }
}
