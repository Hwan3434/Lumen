import AppKit
import Carbon.HIToolbox

final class TranslatorFeature: BuiltInFeature {
    let name = "AI 번역"
    let featureDescription = "한국어와 영어를 서로 번역해요"
    let iconName = "languages"
    let searchKeywords = ["번역", "translate", "translation", "ai"]

    let windowController = TranslatorWindowController()

    var hotkeys: [HotkeySpec] {
        [
            HotkeySpec(
                keyCode: UInt16(kVK_ANSI_C),
                modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
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
