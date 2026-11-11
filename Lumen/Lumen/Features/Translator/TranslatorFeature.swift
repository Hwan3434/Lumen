import AppKit
import Carbon.HIToolbox

final class TranslatorFeature: BuiltInFeature {
    let name = "AI 번역"
    let featureDescription = "한국어와 영어를 서로 번역해요"
    let iconName = "languages"
    let searchKeywords = ["번역", "translate", "translation", "ai"]

    let windowController = TranslatorWindowController()

    /// 패널 머리에도 같은 단축키를 보여 주므로 한 곳에 둔다.
    static let toggleKeyCode = UInt16(kVK_ANSI_C)
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
}
