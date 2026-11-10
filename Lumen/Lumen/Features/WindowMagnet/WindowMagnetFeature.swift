import AppKit

final class WindowMagnetFeature: BuiltInFeature {
    let name = "윈도우 마그넷"
    let featureDescription = "창을 화면 왼쪽이나 오른쪽에 맞춰 붙여요"
    let iconName = "columns-2"
    let searchKeywords = ["magnet", "마그넷", "윈도우", "window", "스냅", "크기"]

    var isEnabled: Bool { Constants.magnetEnabled }

    let manager = WindowMagnetManager()
    lazy var windowController = WindowMagnetWindowController(manager: manager)

    var hotkeys: [HotkeySpec] {
        [
            HotkeySpec(
                keyCode: Constants.magnetLeftHotKeyCode,
                modifiers: Constants.magnetLeftHotKeyModifiers,
                description: "Ctrl+Option+Left",
                action: { [weak self] in
                    self?.manager.snapWindow(direction: .left)
                }
            ),
            HotkeySpec(
                keyCode: Constants.magnetRightHotKeyCode,
                modifiers: Constants.magnetRightHotKeyModifiers,
                description: "Ctrl+Option+Right",
                action: { [weak self] in
                    self?.manager.snapWindow(direction: .right)
                }
            )
        ]
    }

    func activate() {
        windowController.toggle()
    }
}
