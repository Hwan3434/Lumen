import AppKit
import SwiftUI

final class ClipboardWindowController: PanelWindowController {
    private static let panelSize = NSSize(width: 800, height: 640)
    private var clipboardViewModel: ClipboardViewModel?

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

        let vm = ClipboardViewModel()
        self.clipboardViewModel = vm

        panel.contentView = NSHostingView(rootView: ClipboardView(viewModel: vm))

        panel.onKeyEvent = { [weak self, weak panel] keyCode in
            guard let vm = self?.clipboardViewModel else { return false }
            switch keyCode {
            case KeyCode.downArrow: vm.moveDown(); return true
            case KeyCode.upArrow:   vm.moveUp();   return true
            case KeyCode.enter:
                vm.selectCurrent()
                self?.hide()
                return true
            case KeyCode.escape: self?.hide(); return true
            case KeyCode.delete, KeyCode.forwardDelete:
                // 검색창 포커스 중에는 텍스트 편집용으로 흘려보낸다.
                if let responder = panel?.firstResponder,
                   responder is NSText || responder is NSTextView {
                    return false
                }
                vm.deleteCurrent()
                return true
            default: return false
            }
        }

        return panel
    }

    override func configureBeforeShow(_ panel: KeyablePanel) {
        let frame = NSScreen.underMouse.visibleFrame
        let size = Self.panelSize
        let x = frame.midX - size.width / 2
        let y = frame.midY - size.height / 2
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    override func willHide() {
        clipboardViewModel?.query = ""
    }
}
