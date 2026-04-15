import AppKit
import SwiftUI

final class ClipboardWindowController {
    private var panel: KeyablePanel?
    private var clipboardViewModel: ClipboardViewModel?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil {
            createPanel()
        }
        guard let panel = panel, let screen = NSScreen.main else { return }

        let width: CGFloat = 700
        let height: CGFloat = 420
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        let y = screenFrame.midY - height / 2

        panel.previousApp = NSWorkspace.shared.frontmostApplication
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func createPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 420),
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

        let vm = ClipboardViewModel()
        self.clipboardViewModel = vm

        let view = ClipboardView(viewModel: vm)
        panel.contentView = NSHostingView(rootView: view)

        panel.onKeyEvent = { [weak self] keyCode in
            guard let vm = self?.clipboardViewModel else { return false }
            switch keyCode {
            case KeyCode.downArrow: vm.moveDown(); return true
            case KeyCode.upArrow: vm.moveUp(); return true
            case KeyCode.enter:
                vm.selectCurrent()
                self?.hide()
                return true
            case KeyCode.escape: self?.hide(); return true
            default: return false
            }
        }

        self.panel = panel
    }
}
