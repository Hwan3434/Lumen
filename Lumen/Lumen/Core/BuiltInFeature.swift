import AppKit
import SwiftUI

struct HotkeySpec {
    let keyCode: UInt16
    let modifiers: UInt32
    let action: () -> Void
}

protocol BuiltInFeature: AnyObject {
    var name: String { get }
    var featureDescription: String { get }
    var searchKeywords: [String] { get }
    var isEnabled: Bool { get }
    /// Lucide 아이콘 이름 (Assets.xcassets/Icons 의 `lucide-<이름>`).
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

/// 창을 여는 대신 켜고 끄는 기능(카페인, 클램쉘 모드). 검색창 상세 칸에 스위치로 보인다.
/// `activate()`가 켜고 끄기를 맡는다. 검색창이 상태를 바로 따라가도록 구현체는 `@Observable`이어야 한다.
protocol ToggleableFeature: BuiltInFeature, Observable {
    var isOn: Bool { get }
    /// 켜져 있을 때 상세 칸에 보여 줄 상태 한 줄(예: 언제 꺼지는지). 꺼져 있으면 nil.
    var onStatus: String? { get }
    /// 스위치 밑에 붙일 기능 전용 설정(예: 클램쉘 모드의 끄기 시간). 없으면 nil.
    var detailAccessory: AnyView? { get }
}

extension ToggleableFeature {
    var detailAccessory: AnyView? { nil }
}

extension BuiltInFeature {
    func setup() {}
    func teardown() {}
    var hotkeys: [HotkeySpec] { [] }
    var isEnabled: Bool { true }

    func attachStatusBar(_ coordinator: StatusBarCoordinator) {}
}
