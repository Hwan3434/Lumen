import AppKit
import SwiftUI

final class WindowMagnetWindowController {
    private var panel: KeyablePanel?
    private var viewModel: WindowMagnetViewModel?
    private var targetApp: NSRunningApplication?
    private let manager: WindowMagnetManager

    init(manager: WindowMagnetManager) {
        self.manager = manager
    }

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
        targetApp = NSWorkspace.shared.frontmostApplication

        if panel == nil {
            createPanel()
        }
        guard let panel = panel, let screen = NSScreen.main else { return }

        let width: CGFloat = 300
        let height: CGFloat = 350
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        let y = screenFrame.midY - height / 2

        panel.previousApp = targetApp
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func selectCurrent() {
        guard let vm = viewModel else { return }
        let opt = vm.selectedOption
        manager.snapWindowTo(direction: opt.direction, ratio: opt.ratio, targetApp: targetApp)
        hide()
    }

    private func createPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 350),
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
            guard let self = self else { return }
            self.manager.snapWindowTo(direction: direction, ratio: ratio, targetApp: self.targetApp)
            self.hide()
        }
        panel.contentView = NSHostingView(rootView: view)

        panel.onKeyEvent = { [weak self] keyCode in
            guard let vm = self?.viewModel else { return false }
            switch keyCode {
            case KeyCode.downArrow: vm.moveDown(); return true
            case KeyCode.upArrow: vm.moveUp(); return true
            case KeyCode.enter: self?.selectCurrent(); return true
            case KeyCode.escape: self?.hide(); return true
            default: return false
            }
        }

        self.panel = panel
    }
}
