import AppKit
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    let hotkeyManager = HotkeyManager()
    let searchWindowController = SearchWindowController()
    var appStatusBar: AppStatusBar!
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    private var keyWindowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppResourceMonitor.resetTrace()
        AppResourceMonitor.trace("applicationDidFinishLaunching:start")

        let translator = TranslatorFeature()
        FeatureRegistry.shared.register(translator)
        AppResourceMonitor.trace("feature_registered: Translator")

        let windowMagnet = WindowMagnetFeature()
        FeatureRegistry.shared.register(windowMagnet)
        AppResourceMonitor.trace("feature_registered: WindowMagnet")

        let clipboard = ClipboardFeature()
        FeatureRegistry.shared.register(clipboard)
        AppResourceMonitor.trace("feature_registered: Clipboard")

        let note = NoteFeature()
        FeatureRegistry.shared.register(note)
        AppResourceMonitor.trace("feature_registered: Note")

        let caffeine = CaffeineFeature()
        FeatureRegistry.shared.register(caffeine)
        AppResourceMonitor.trace("feature_registered: Caffeine")

        let jiraDashboard = JiraDashboardFeature()
        FeatureRegistry.shared.register(jiraDashboard)
        AppResourceMonitor.trace("feature_registered: JiraDashboard")

        let colorPicker = ColorPickerFeature()
        FeatureRegistry.shared.register(colorPicker)
        AppResourceMonitor.trace("feature_registered: ColorPicker")

        let resourceMonitor = ResourceMonitorFeature()
        FeatureRegistry.shared.register(resourceMonitor)
        AppResourceMonitor.trace("feature_registered: ResourceMonitor")

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

        // 떠있는 우리 패널로 키보드 포커스 복귀
        hotkeyManager.register(
            keyCode: Constants.focusHotKeyCode,
            modifiers: Constants.focusHotKeyModifiers
        ) {
            PanelWindowController.focusTopVisible()
        }

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
        AppResourceMonitor.trace("hotkeys_registered")
        AppResourceMonitor.trace("availability: jira=\(JiraService.isAvailable) openai=\(OpenAIService.isAvailable) claude=\(ClaudeUsageService.isAvailable)")
        let names = FeatureRegistry.shared.enabledFeatures.map(\.name).joined(separator: ", ")
        AppResourceMonitor.trace("enabled_features: \(names)")

        appStatusBar = AppStatusBar(updater: updaterController.updater)
        AppResourceMonitor.trace("statusbar_ready")

        if ClaudeUsageService.isAvailable {
            Task {
                AppResourceMonitor.trace("fetchHeavy:kickoff")
                await ClaudeUsageService.shared.fetchHeavy()
                AppResourceMonitor.trace("fetchHeavy:done")
            }
        }

        // SwiftUI Settings 창이 열리면 우리 floating panel이 가리므로,
        // non-panel 창이 key가 되는 순간 모든 visible KeyablePanel을 내린다.
        // Cmd+, 의 기본 시스템 경로는 그대로 두고 여기서만 후처리.
        //
        // window.isVisible 가드가 중요: 첫 ⌘Space에 NSApp.activate()가 처음
        // 호출되는 순간 macOS가 보이지 않는 placeholder NSWindow(AppKit 내부
        // helper / Sparkle background updater 등)를 잠깐 key로 만드는 케이스가
        // 있어, 그 알림에 우리 옵저버가 막 떠올린 search panel을 도로 닫아버리는
        // race가 있었다. visible한 NSWindow가 key를 가져갔을 때만 우리 패널을 내린다.
        keyWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow,
                  !(window is KeyablePanel),
                  window.isVisible
            else { return }
            for case let panel as KeyablePanel in NSApp.windows where panel.isVisible {
                panel.activatePreviousAppOnClose = false
                panel.orderOut(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer = keyWindowObserver {
            NotificationCenter.default.removeObserver(observer)
            keyWindowObserver = nil
        }
        hotkeyManager.stop()
        FeatureRegistry.shared.teardownAll()
        ClipboardManager.shared.flushPendingSave()
    }
}
