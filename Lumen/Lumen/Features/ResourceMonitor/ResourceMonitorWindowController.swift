import AppKit
import SwiftUI

final class ResourceMonitorWindowController: PanelWindowController {
    private static let panelSize = NSSize(width: 560, height: 680)

    override func createPanel() -> KeyablePanel {
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = .canJoinAllSpaces
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.autoFocusTextField = false

        panel.onKeyEvent = { [weak self] keyCode in
            if keyCode == KeyCode.escape { self?.hide(); return true }
            return false
        }

        panel.contentView = NSHostingView(rootView: ResourceMonitorView())
        return panel
    }

    override func configureBeforeShow(_ panel: KeyablePanel) {
        let frame = NSScreen.underMouse.visibleFrame
        let size = Self.panelSize
        let x = frame.midX - size.width / 2
        let y = frame.midY - size.height / 2
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    // 실시간 그래프가 보이는 동안만 촘촘히 샘플링한다. 닫혀 있을 땐 추세 감지용 저빈도로.
    override func didShow(_ panel: KeyablePanel) {
        AppResourceMonitor.shared.setForeground(true)
    }

    override func willHide() {
        AppResourceMonitor.shared.setForeground(false)
    }
}
