import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let hotkeyManager = HotkeyManager()
    let searchWindowController = SearchWindowController()
    var appStatusBar: AppStatusBar!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 내장 기능 등록
        let translator = TranslatorFeature()
        FeatureRegistry.shared.register(translator)

        let windowMagnet = WindowMagnetFeature()
        FeatureRegistry.shared.register(windowMagnet)

        let clipboard = ClipboardFeature()
        FeatureRegistry.shared.register(clipboard)

        let note = NoteFeature()
        FeatureRegistry.shared.register(note)

        let caffeine = CaffeineFeature()
        FeatureRegistry.shared.register(caffeine)

        let colorPicker = ColorPickerFeature()
        FeatureRegistry.shared.register(colorPicker)

        // 윈도우 마그넷용 접근성 권한 (단축키와는 무관)
        if windowMagnet.isEnabled {
            AccessibilityHelper.requestAccessIfNeeded()
        }

        // 메인 검색창 단축키
        hotkeyManager.register(
            keyCode: Constants.searchHotKeyCode,
            modifiers: Constants.searchHotKeyModifiers
        ) { [weak self] in
            self?.searchWindowController.toggle()
        }

        // 내장 기능 단축키 등록
        for feature in FeatureRegistry.shared.enabledFeatures {
            for hotkey in feature.hotkeys {
                hotkeyManager.register(
                    keyCode: hotkey.keyCode,
                    modifiers: hotkey.modifiers,
                    action: hotkey.action
                )
            }
        }

        hotkeyManager.start()

        appStatusBar = AppStatusBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
        FeatureRegistry.shared.teardownAll()
    }
}
