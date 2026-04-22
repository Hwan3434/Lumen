import AppKit

final class TranslatorFeature: BuiltInFeature {
    let name = "AI 번역"
    let featureDescription = "한국어 ↔ 영어 번역"
    let iconName = "textformat.abc"
    let searchKeywords = ["번역", "translate", "translation", "ai"]

    var isEnabled: Bool { OpenAIService.isAvailable }

    let windowController = TranslatorWindowController()

    var hotkeys: [HotkeySpec] {
        [
            HotkeySpec(
                keyCode: Constants.translateHotKeyCode,
                modifiers: Constants.translateHotKeyModifiers,
                description: "Cmd+Shift+C",
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
