import AppKit
import Carbon.HIToolbox

final class WindowMagnetFeature: BuiltInFeature {
    let name = "윈도우 마그넷"
    let featureDescription = "창을 화면 왼쪽이나 오른쪽에 맞춰 붙여요"
    let iconName = "columns-2"
    let searchKeywords = ["magnet", "마그넷", "윈도우", "window", "스냅", "크기"]

    let service = WindowMagnetService()
    lazy var windowController = WindowMagnetWindowController(service: service)

    private static let hotkeyModifiers = UInt32(NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue)

    var hotkeys: [HotkeySpec] {
        [
            HotkeySpec(
                keyCode: UInt16(kVK_LeftArrow),
                modifiers: Self.hotkeyModifiers,
                action: { [weak self] in
                    self?.service.snapWindow(direction: .left)
                }
            ),
            HotkeySpec(
                keyCode: UInt16(kVK_RightArrow),
                modifiers: Self.hotkeyModifiers,
                action: { [weak self] in
                    self?.service.snapWindow(direction: .right)
                }
            )
        ]
    }

    /// 창을 옮기려면 손쉬운 사용 권한이 필요하다(단축키 자체와는 무관).
    func setup() {
        AccessibilityHelper.requestAccessIfNeeded()
    }

    func activate() {
        windowController.toggle()
    }
}
