import AppKit

struct HotkeySpec {
    let keyCode: UInt16
    let modifiers: UInt32
    let description: String
    let action: () -> Void
}

protocol BuiltInFeature: AnyObject {
    var name: String { get }
    var featureDescription: String { get }
    var searchKeywords: [String] { get }
    var isEnabled: Bool { get }
    var showInDefaultList: Bool { get }
    var iconName: String { get }
    var hotkeys: [HotkeySpec] { get }

    func activate()
    func setup()
    func teardown()

    /// Feature가 메뉴바 NSStatusItem을 띄우고 싶을 때 coordinator에 등록.
    /// 호출 시점은 앱 부팅 후 — coordinator가 lifecycle을 책임지므로 feature는
    /// NSStatusBar.system을 직접 만지지 않는다. 기본 구현은 no-op.
    @MainActor func attachStatusBar(_ coordinator: StatusBarCoordinator)
}

extension BuiltInFeature {
    func setup() {}
    func teardown() {}
    var hotkeys: [HotkeySpec] { [] }
    var isEnabled: Bool { true }
    var showInDefaultList: Bool { true }
    var iconName: String { "star.fill" }

    func attachStatusBar(_ coordinator: StatusBarCoordinator) {}
}
