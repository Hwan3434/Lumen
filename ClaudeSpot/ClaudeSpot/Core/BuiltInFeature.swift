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
}

extension BuiltInFeature {
    func setup() {}
    func teardown() {}
    var hotkeys: [HotkeySpec] { [] }
    var isEnabled: Bool { true }
    var showInDefaultList: Bool { true }
    var iconName: String { "star.fill" }
}
