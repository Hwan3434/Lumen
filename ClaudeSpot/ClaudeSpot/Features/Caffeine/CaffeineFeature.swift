import AppKit
import IOKit.pwr_mgt

final class CaffeineFeature: BuiltInFeature {
    let featureDescription = "슬립 방지 (카페인)"
    let iconName = "cup.and.saucer"
    let searchKeywords = ["카페인", "caffeine", "슬립", "sleep", "잠금", "화면"]
    let showInDefaultList = false

    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false
    private let statusBar = CaffeineStatusBar()

    var name: String {
        isActive ? "카페인 끄기" : "카페인 켜기"
    }

    func activate() {
        toggle()
    }

    func setup() {
        statusBar.onClick = { [weak self] in
            self?.toggle()
        }
    }

    func teardown() {
        if isActive { deactivateSleep() }
        statusBar.remove()
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
            "ClaudeSpot Caffeine" as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            isActive = true
            statusBar.show(isActive: true)
        }
    }

    private func deactivateSleep() {
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
        statusBar.updateIcon(isActive: false)
    }
}
