import AppKit
import SwiftUI

final class WindowMagnetWindowController: PanelWindowController {
    private static let panelSize = NSSize(width: 300, height: 350)
    private var viewModel: WindowMagnetViewModel?
    private var targetApp: NSRunningApplication?
    private let manager: WindowMagnetManager

    init(manager: WindowMagnetManager) {
        self.manager = manager
        super.init()
    }

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

        let vm = WindowMagnetViewModel()
        self.viewModel = vm

        let view = WindowMagnetView(viewModel: vm) { [weak self] direction, ratio in
            guard let self else { return }
            self.manager.snapWindowTo(direction: direction, ratio: ratio, targetApp: self.targetApp)
            self.hide()
        }
        panel.contentView = NSHostingView(rootView: view)

        panel.onKeyEvent = { [weak self] keyCode in
            guard let vm = self?.viewModel else { return false }
            switch keyCode {
            case KeyCode.downArrow: vm.moveDown(); return true
            case KeyCode.upArrow:   vm.moveUp();   return true
            case KeyCode.enter:     self?.selectCurrent(); return true
            case KeyCode.escape:    self?.hide(); return true
            default: return false
            }
        }

        return panel
    }

    override func configureBeforeShow(_ panel: KeyablePanel) {
        targetApp = NSWorkspace.shared.frontmostApplication
        panel.previousApp = targetApp

        let frame = NSScreen.underMouse.visibleFrame
        let size = Self.panelSize
        let x = frame.midX - size.width / 2
        let y = frame.midY - size.height / 2
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    private func selectCurrent() {
        guard let vm = viewModel else { return }
        let opt = vm.selectedOption
        manager.snapWindowTo(direction: opt.direction, ratio: opt.ratio, targetApp: targetApp)
        hide()
    }
}
