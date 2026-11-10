import AppKit
import SwiftUI

final class WindowMagnetWindowController: PanelWindowController {
    private static var panelSize: NSSize { Constants.magnetWindowSize }
    override var densityContentSize: NSSize? { Self.panelSize }
    private var viewModel: WindowMagnetViewModel?
    private var targetApp: NSRunningApplication?
    private let service: WindowMagnetService

    init(service: WindowMagnetService) {
        self.service = service
        super.init()
    }

    override func createPanel() -> KeyablePanel {
        let panel = makePanel(size: Self.panelSize)

        let vm = WindowMagnetViewModel()
        self.viewModel = vm

        let view = WindowMagnetView(viewModel: vm) { [weak self] direction, ratio in
            guard let self else { return }
            self.service.snapWindowTo(direction: direction, ratio: ratio, targetApp: self.targetApp)
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

        centerUnderMouse(panel, size: Self.panelSize)
    }

    private func selectCurrent() {
        guard let vm = viewModel else { return }
        let opt = vm.selectedOption
        service.snapWindowTo(direction: opt.direction, ratio: opt.ratio, targetApp: targetApp)
        hide()
    }
}
