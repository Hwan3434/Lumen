import AppKit
import SwiftUI

final class ResourceMonitorWindowController: PanelWindowController {
    private static var panelSize: NSSize { Constants.resourceWindowSize }
    override var densityContentSize: NSSize? { Self.panelSize }

    override func createPanel() -> KeyablePanel {
        let panel = makePanel(size: Self.panelSize)
        panel.autoFocusTextField = false

        panel.onKeyEvent = { [weak self] keyCode in
            if keyCode == KeyCode.escape { self?.hide(); return true }
            return false
        }

        panel.contentView = NSHostingView(rootView: ResourceMonitorView(monitor: .shared, store: .shared))
        return panel
    }

    override func configureBeforeShow(_ panel: KeyablePanel) {
        centerUnderMouse(panel, size: Self.panelSize)
    }

    // 실시간 그래프가 보이는 동안만 촘촘히 샘플링한다. 닫혀 있을 땐 추세 감지용 저빈도로.
    override func didShow(_ panel: KeyablePanel) {
        AppResourceMonitor.shared.setForeground(true)
    }

    override func willHide() {
        AppResourceMonitor.shared.setForeground(false)
    }
}
