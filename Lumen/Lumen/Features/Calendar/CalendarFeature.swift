import AppKit
import Carbon.HIToolbox

final class CalendarFeature: BuiltInFeature {
    let name = "Jira 캘린더"
    let featureDescription = "스프린트·에픽·태스크 일정 조회"
    let iconName = "calendar"
    let searchKeywords = ["캘린더", "calendar", "일정", "schedule", "jira", "지라", "스프린트", "에픽", "epic"]

    var isEnabled: Bool { JiraService.isAvailable }

    let windowController = CalendarWindowController()

    var hotkeys: [HotkeySpec] {
        [
            HotkeySpec(
                keyCode: UInt16(kVK_ANSI_G),
                modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
                description: "Cmd+Shift+G",
                action: { [weak self] in self?.activate() }
            )
        ]
    }

    func activate() {
        windowController.toggle()
    }
}
