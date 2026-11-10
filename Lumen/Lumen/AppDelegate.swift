import AppKit
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    let hotkeyManager = HotkeyManager()
    let searchWindowController = SearchWindowController()
    var appStatusBar: AppStatusBar!
    /// 테스트는 실제 앱을 호스트로 띄운다(같은 번들 ID·설정·데이터 폴더). 그때 단축키 등록, 클립보드 기록,
    /// 클램쉘 모드 복구(`restoreIfLeftOn`) 같은 시작 작업이 돌면 설치된 Lumen의 상태를 건드린다.
    private static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    let updaterController = SPUStandardUpdaterController(
        startingUpdater: !AppDelegate.isRunningTests,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    private var keyWindowObserver: NSObjectProtocol?
    private var sparkleWindowObserver: NSObjectProtocol?
    /// 같은 SP/SU 창에 중복 적용하지 않도록 한 번 처리한 창은 기억해둔다.
    private var promotedSparkleWindows: Set<ObjectIdentifier> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        MemoryTrace.reset()
        MemoryTrace.record("applicationDidFinishLaunching:start")

        // 글꼴과 테마는 렌더 테스트도 쓰므로 가드보다 먼저 한다.
        LumenFont.register()
        LumenAppearance.saved.apply()
        guard !Self.isRunningTests else { return }

        LumenStorage.purgeRetiredFilesIfNeeded()
        ScheduleMigration.runIfNeeded()

        let translator = TranslatorFeature()
        FeatureRegistry.shared.register(translator)
        MemoryTrace.record("feature_registered: Translator")

        let windowMagnet = WindowMagnetFeature()
        FeatureRegistry.shared.register(windowMagnet)
        MemoryTrace.record("feature_registered: WindowMagnet")

        let clipboard = ClipboardFeature()
        FeatureRegistry.shared.register(clipboard)
        MemoryTrace.record("feature_registered: Clipboard")

        let note = NoteFeature()
        FeatureRegistry.shared.register(note)
        MemoryTrace.record("feature_registered: Note")

        let caffeine = CaffeineFeature()
        FeatureRegistry.shared.register(caffeine)
        MemoryTrace.record("feature_registered: Caffeine")

        // 덮개 모드는 시스템 전역 설정을 바꾸므로 카페인과 달리 자동으로 켜지 않는다.
        FeatureRegistry.shared.register(LidAwakeFeature.shared)
        MemoryTrace.record("feature_registered: LidAwake")

        let schedule = ScheduleFeature()
        FeatureRegistry.shared.register(schedule)
        MemoryTrace.record("feature_registered: Schedule")

        let colorPicker = ColorPickerFeature()
        FeatureRegistry.shared.register(colorPicker)
        MemoryTrace.record("feature_registered: ColorPicker")

        let resourceMonitor = ResourceMonitorFeature()
        FeatureRegistry.shared.register(resourceMonitor)
        MemoryTrace.record("feature_registered: ResourceMonitor")

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
        MemoryTrace.record("hotkeys_registered")

        // Search 입력에서 환율 변환에 쓰는 USD-기준 환율 캐시 — 24h마다 백그라운드 갱신.
        CurrencyService.shared.refreshIfStale()
        let names = FeatureRegistry.shared.enabledFeatures.map(\.name).joined(separator: ", ")
        MemoryTrace.record("enabled_features: \(names)")

        appStatusBar = AppStatusBar(updater: updaterController.updater)
        appStatusBar.attachFeatures(FeatureRegistry.shared.enabledFeatures)
        MemoryTrace.record("statusbar_ready")

        // SwiftUI Settings 창이 열리면 우리 floating panel이 가리므로, non-panel
        // 창이 key가 되는 순간 모든 visible KeyablePanel을 내린다. 두 가지 가드로
        // 부모 앱이 띄우지 않은 transient/framework window는 무시한다:
        //   • isVisible — 보이지 않는 helper window(첫 NSApp.activate 시 잠깐 등장)
        //   • SP/SU prefix — Sparkle 자동 업데이트 알림(SPRoundedWindow 등). 첫
        //     ⌘Space ~300ms 후에 떠서 검색창을 도로 내려버리는 사례가 있었음.
        // Sparkle 창(SP/SU…)을 풀스크린 다른 앱 위로 띄우기 위한 별도 옵저버 — didBecomeKey는
        // "이미 키가 된 후"라 풀스크린 Space에서는 트리거 자체가 늦거나 안 올 수 있다.
        // didBecomeMain은 창이 NSApp에 합류하는 시점에 더 안정적으로 발생한다.
        sparkleWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let window = notification.object as? NSWindow,
                  !(window is KeyablePanel)
            else { return }
            let cls = String(describing: type(of: window))
            guard cls.hasPrefix("SP") || cls.hasPrefix("SU") else { return }
            let id = ObjectIdentifier(window)
            guard !self.promotedSparkleWindows.contains(id) else { return }
            self.promotedSparkleWindows.insert(id)
            // .floating 보다 한 단계 더 위인 .modalPanel이 풀스크린 다른 앱 위로 더 안정적으로 뜬다.
            // .canJoinAllSpaces + .fullScreenAuxiliary 가 풀스크린 Space에 합류하는 핵심 키.
            window.level = .modalPanel
            window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }

        keyWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow,
                  !(window is KeyablePanel),
                  window.isVisible
            else { return }
            let cls = String(describing: type(of: window))
            // Sparkle 업데이트 알림(SP/SU…)은 패널을 내리지 않는다.
            // 풀스크린 위로 올리는 처리는 sparkleWindowObserver가 담당.
            if cls.hasPrefix("SP") || cls.hasPrefix("SU") { return }
            // SwiftUI/AppKit이 패널 안에서 띄우는 보조 윈도우(alert, popover 백업 등)는
            // 우리 패널의 자식이므로 무시 — 닫혀버리면 사용자 입력 흐름이 끊긴다.
            //   • _NSAlertPanel / NSAlertWindow 등 NSAlert 계열
            //   • _NSPopoverWindow (메뉴/툴팁)
            //   • parentWindow가 우리 KeyablePanel인 경우 일반화로 처리
            if cls.contains("Alert") || cls.contains("Popover") { return }
            if window.parent is KeyablePanel { return }
            for case let panel as KeyablePanel in NSApp.windows where panel.isVisible {
                panel.activatePreviousAppOnClose = false
                panel.orderOut(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard !Self.isRunningTests else { return }
        if let observer = keyWindowObserver {
            NotificationCenter.default.removeObserver(observer)
            keyWindowObserver = nil
        }
        if let observer = sparkleWindowObserver {
            NotificationCenter.default.removeObserver(observer)
            sparkleWindowObserver = nil
        }
        hotkeyManager.stop()
        FeatureRegistry.shared.teardownAll()
        appStatusBar?.teardown()
        ClipboardManager.shared.flushPendingSave()
    }
}
