import AppKit

final class ResourceMonitorFeature: BuiltInFeature {
    let name = "리소스 모니터"
    let featureDescription = "이 앱의 메모리/CPU/스레드 실시간 모니터링"
    let iconName = "gauge.with.dots.needle.67percent"
    let searchKeywords = ["리소스", "모니터", "monitor", "resource", "cpu", "ram", "memory", "메모리", "성능"]

    let windowController = ResourceMonitorWindowController()

    func setup() {
        AppResourceMonitor.shared.start()
    }

    func teardown() {
        AppResourceMonitor.shared.stop()
    }

    func activate() {
        windowController.toggle()
    }
}
