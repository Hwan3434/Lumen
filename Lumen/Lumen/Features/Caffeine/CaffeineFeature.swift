import AppKit
import IOKit.pwr_mgt

final class CaffeineFeature: BuiltInFeature {
    let featureDescription = "슬립 방지 (카페인)"
    let iconName = "cup.and.saucer"
    let searchKeywords = ["카페인", "caffeine", "슬립", "sleep", "잠금", "화면"]
    let showInDefaultList = false

    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false
    private var statusHandle: StatusBarItemHandle?

    var name: String {
        isActive ? "카페인 끄기" : "카페인 켜기"
    }

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
            initialIcon: "cup.and.saucer.fill",
            accessibility: "카페인",
            visible: false,
            onClick: { [weak self] in self?.toggle() }
        )
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
            statusHandle?.updateIcon("cup.and.saucer.fill")
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
