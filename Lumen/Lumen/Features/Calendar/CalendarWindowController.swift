import AppKit
import SwiftUI
import Carbon.HIToolbox

final class CalendarWindowController: PanelWindowController {
    private static let panelSize = NSSize(width: 1100, height: 680)

    override func createPanel() -> KeyablePanel {
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = .canJoinAllSpaces
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 720, height: 480)
        panel.autoFocusTextField = false

        panel.onKeyEvent = { [weak self] keyCode in
            if keyCode == KeyCode.escape { self?.hide(); return true }
            return false
        }

        panel.onCommandKey = { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command && event.keyCode == UInt16(kVK_ANSI_W) {
                self?.hide(); return true
            }
            return false
        }

        panel.contentView = NSHostingView(rootView: CalendarView())
        return panel
    }

    override func didCreatePanel(_ panel: KeyablePanel) {
        let frame = NSScreen.underMouse.visibleFrame
        let size = Self.panelSize
        let x = frame.midX - size.width / 2
        let y = frame.midY - size.height / 2
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}
