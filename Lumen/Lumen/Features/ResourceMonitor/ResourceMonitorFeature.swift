import AppKit

final class ResourceMonitorFeature: BuiltInFeature {
    let name = "리소스 모니터"
    let featureDescription = "Lumen이 쓰는 메모리, CPU, 스레드를 보여줘요"
    let iconName = "gauge"
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
