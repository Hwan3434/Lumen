import AppKit
import IOKit.pwr_mgt

@Observable
final class CaffeineFeature: ToggleableFeature {
    let featureDescription = "슬립 방지 (카페인)"
    let iconName = "coffee"
    let searchKeywords = ["카페인", "caffeine", "슬립", "sleep", "잠금", "화면"]

    @ObservationIgnored private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false
    @ObservationIgnored private var statusHandle: StatusBarItemHandle?

    let name = "카페인"

    var isOn: Bool { isActive }
    var onStatus: String? { isActive ? "직접 끌 때까지 화면이 잠들지 않아요" : nil }

    func activate() {
        toggle()
    }

    func teardown() {
        if isActive { deactivateSleep() }
        // status item 정리는 coordinator.teardownAll()이 일괄 처리.
    }

    func attachStatusBar(_ coordinator: StatusBarCoordinator) {
        // 카페인은 평소엔 메뉴바에 없음. 활성화 시점에 show() 한다.
        statusHandle = coordinator.addItem(
            initialIcon: "coffee",
            accessibility: "카페인",
            visible: false,
            onClick: { [weak self] in self?.toggle() }
        )
        // 앱 시작 시 자동 활성화 — 사용자가 끌 때까지 유지.
        if !isActive { activateSleep() }
    }

    private func toggle() {
        if isActive {
            deactivateSleep()
        } else {
            activateSleep()
        }
    }

    private func activateSleep() {
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Lumen Caffeine" as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            isActive = true
            statusHandle?.show()
        }
    }

    private func deactivateSleep() {
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
        statusHandle?.hide()
    }
}
