import AppKit
import Carbon.HIToolbox

final class JiraDashboardFeature: BuiltInFeature {
    let name = "Jira 대시보드"
    let featureDescription = "Jira 이슈 현황"
    let iconName = "square.grid.2x2"
    let searchKeywords = ["jira", "지라", "태스크", "task", "이슈", "issue", "대시보드"]

    var isEnabled: Bool { JiraService.isAvailable }

    let windowController = JiraDashboardWindowController()
    private var statusItem: CalendarStatusItem?

    var hotkeys: [HotkeySpec] {
        [
            HotkeySpec(
                keyCode: UInt16(kVK_ANSI_G),
                modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
                description: "Cmd+Shift+G",
                action: { [weak self] in self?.activate() }
            ),
            HotkeySpec(
                keyCode: UInt16(kVK_ANSI_A),
                modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
                description: "Cmd+Shift+A",
                action: { [weak self] in self?.statusItem?.togglePopover() }
            )
        ]
    }

    func activate() {
        windowController.toggle()
    }

    @MainActor
    func attachStatusBar(_ coordinator: StatusBarCoordinator) {
        // Jira 자격증명 + iCal 연동이 모두 준비됐을 때만 메뉴바에 캘린더 위젯을 띄운다.
        guard JiraService.isAvailable,
              CredentialsStore.shared.isICalEnabled,
              CredentialsStore.shared.isMenuBarAgendaEnabled else { return }
        statusItem = CalendarStatusItem(coordinator: coordinator)
        Task {
            // 메뉴바 위젯이 켜진 시점엔 dashboard window가 열린 적 없을 수 있어
            // JiraService.data가 nil이다 — 둘 다 병렬로 fetch한 뒤 라벨 갱신.
            async let jira: Void = JiraService.shared.fetch()
            async let cal: Void = EventKitService.shared.requestAccessAndFetch()
            _ = await (jira, cal)
            await MainActor.run { statusItem?.refresh() }
        }
    }
}
