import AppKit
import Sparkle

final class AppStatusBar: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let updater: SPUUpdater

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
