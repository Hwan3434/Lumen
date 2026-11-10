import AppKit
import Carbon.HIToolbox

final class ClipboardFeature: BuiltInFeature {
    let name = "클립보드"
    let featureDescription = "복사한 기록을 다시 꺼내 써요"
    let iconName = "clipboard-list"
    let searchKeywords = ["clipboard", "클립보드", "복사", "붙여넣기", "paste"]

    let windowController = ClipboardWindowController()

    var hotkeys: [HotkeySpec] {
        [
            HotkeySpec(
                keyCode: UInt16(kVK_ANSI_V),
                modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
                description: "Cmd+Shift+V",
                action: { [weak self] in
                    self?.activate()
                }
            )
        ]
    }

    func activate() {
        windowController.toggle()
    }

    func setup() {
        ClipboardManager.shared.startMonitoring()
    }

    func teardown() {
        ClipboardManager.shared.stopMonitoring()
    }
}
