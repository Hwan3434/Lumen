import AppKit
import Carbon.HIToolbox

final class JiraDashboardFeature: BuiltInFeature {
    let name = "Jira 대시보드"
    let featureDescription = "PPAI · PPDEV1 현황"
    let iconName = "square.grid.2x2"
    let searchKeywords = ["jira", "지라", "태스크", "task", "이슈", "issue", "대시보드"]

    let windowController = JiraDashboardWindowController()

    var hotkeys: [HotkeySpec] {
        [
            HotkeySpec(
                keyCode: UInt16(kVK_ANSI_J),
                modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
                description: "Cmd+Shift+J",
                action: { [weak self] in self?.activate() }
            )
        ]
    }

    func activate() {
        windowController.toggle()
    }
}
