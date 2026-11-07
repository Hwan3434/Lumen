import AppKit
import Carbon.HIToolbox
import Observation

/// 일정 대시보드. 연동이 하나도 없어도 열리고, 일정 출처는 플러그인(`SchedulePlugins.all`)으로 붙는다.
final class ScheduleFeature: BuiltInFeature {
    let name = "일정"
    let featureDescription = "캘린더와 Jira 일정을 한 화면에"
    let iconName = "calendar"
    let searchKeywords = ["일정", "schedule", "캘린더", "calendar", "jira", "지라", "대시보드", "dashboard", "이슈", "issue"]

    let windowController = ScheduleWindowController()
    private var statusItem: ScheduleStatusItem?

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
        let item = ScheduleStatusItem(coordinator: coordinator, store: ScheduleStore.shared)
        statusItem = item
        applyMenuBarSetting()
        observeMenuBarSetting()
        // 메뉴바 라벨은 패널을 열지 않아도 보여야 하므로 라벨에 올리는 플러그인만 부팅 때 받아 둔다.
        Task { await ScheduleStore.shared.refreshMenuBarPlugins() }
    }

    /// 설정 › 일정 › 대시보드의 메뉴바 라벨 스위치를 켜고 끄는 즉시 따라간다.
    private func observeMenuBarSetting() {
        withObservationTracking {
            _ = DashboardSettingsStore.shared.settings.menuBarLabel
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.applyMenuBarSetting()
                self?.observeMenuBarSetting()
            }
        }
    }

    private func applyMenuBarSetting() {
        statusItem?.setVisible(DashboardSettingsStore.shared.settings.menuBarLabel)
    }
}
