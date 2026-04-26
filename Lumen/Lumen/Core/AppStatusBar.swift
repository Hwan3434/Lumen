import AppKit
import Sparkle

/// 앱의 메뉴바 영역을 한 곳에서 관리.
///   - 메인 Lumen 메뉴 (자기 NSStatusItem)
///   - feature가 요청한 부가 status item들 (StatusBarCoordinator로 위임)
///
/// Feature는 NSStatusBar.system을 직접 호출하지 않는다 — coordinator를 통해서만.
final class AppStatusBar: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let updater: SPUUpdater

    /// Feature가 등록하는 부가 status item을 관리.
    let coordinator = StatusBarCoordinator()

    init(updater: SPUUpdater) {
        self.updater = updater
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Lumen")
        image?.isTemplate = true
        statusItem.button?.image = image

        menu.delegate = self
        statusItem.menu = menu
    }

    /// 등록된 모든 feature에게 status item attach 기회를 준다. setup() 이후에 호출.
    @MainActor
    func attachFeatures(_ features: [BuiltInFeature]) {
        for feature in features {
            feature.attachStatusBar(coordinator)
        }
    }

    /// 앱 종료 시 자체 NSStatusItem과 coordinator가 보유한 모든 status item을 정리.
    @MainActor
    func teardown() {
        coordinator.teardownAll()
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        buildMenu(menu)
    }

    private func buildMenu(_ menu: NSMenu) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let header = NSMenuItem(title: "Lumen \(version)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        for feature in FeatureRegistry.shared.enabledFeatures {
            let item = NSMenuItem(
                title: feature.name,
                action: #selector(activateFeature(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = feature
            if let img = NSImage(systemSymbolName: feature.iconName, accessibilityDescription: feature.name) {
                img.isTemplate = true
                item.image = img
            }
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let loginItem = NSMenuItem(
            title: "로그인 시 시작",
            action: #selector(toggleLoginItem(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = LoginItemManager.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        let updateItem = NSMenuItem(
            title: "업데이트 확인…",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.isEnabled = updater.canCheckForUpdates
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "종료",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func activateFeature(_ sender: NSMenuItem) {
        guard let feature = sender.representedObject as? BuiltInFeature else { return }
        feature.activate()
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        LoginItemManager.toggle()
    }

    @objc private func checkForUpdates(_ sender: NSMenuItem) {
        updater.checkForUpdates()
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }
}
