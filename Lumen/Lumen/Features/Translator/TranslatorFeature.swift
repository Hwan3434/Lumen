import AppKit

final class TranslatorFeature: BuiltInFeature {
    let name = "AI 번역"
    let featureDescription = "한국어와 영어를 서로 번역해요"
    let iconName = "languages"
    let searchKeywords = ["번역", "translate", "translation", "ai"]

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
