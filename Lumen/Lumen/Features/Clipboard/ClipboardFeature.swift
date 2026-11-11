import AppKit
import Carbon.HIToolbox

final class ClipboardFeature: BuiltInFeature {
    let name = "클립보드"
    let featureDescription = "복사한 기록을 다시 꺼내 써요"
    let iconName = "clipboard-list"
    let searchKeywords = ["clipboard", "클립보드", "복사", "붙여넣기", "paste"]

    let windowController = ClipboardWindowController()

    /// 패널 머리에도 같은 단축키를 보여 주므로 한 곳에 둔다.
    static let toggleKeyCode = UInt16(kVK_ANSI_V)
    static let toggleModifiers = UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
    static var toggleLabel: String { HotkeyRegistry.describe(keyCode: toggleKeyCode, modifiers: toggleModifiers) }

    var hotkeys: [HotkeySpec] {
        [
            HotkeySpec(
                keyCode: Self.toggleKeyCode,
                modifiers: Self.toggleModifiers,
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
        ClipboardStore.shared.startMonitoring()
    }

    func teardown() {
        ClipboardStore.shared.stopMonitoring()
    }
}
