import AppKit
import SwiftUI

final class TranslatorWindowController: PanelWindowController {
    override var densityContentSize: NSSize? { Constants.translatorWindowSize }

    private var translatorViewModel: TranslatorViewModel?
    private var enterMonitor: Any?

    override func createPanel() -> KeyablePanel {
        let panel = makePanel(size: Constants.translatorWindowSize)

        let vm = TranslatorViewModel()
        self.translatorViewModel = vm

        panel.contentView = NSHostingView(rootView: TranslatorView(viewModel: vm))

        panel.onKeyEvent = { [weak self] keyCode in
            guard let vm = self?.translatorViewModel else { return false }
            switch keyCode {
            case KeyCode.downArrow: vm.moveDown(); return true
            case KeyCode.upArrow:   vm.moveUp();   return true
            case KeyCode.escape:    self?.hide();  return true
            default: return false
            }
        }

        return panel
    }

    override func configureBeforeShow(_ panel: KeyablePanel) {
        centerUnderMouse(panel, size: Constants.translatorWindowSize)
    }

    override func didShow(_ panel: KeyablePanel) {
        guard enterMonitor == nil else { return }
        enterMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
            guard let panel, panel.isKeyWindow,
                  event.keyCode == UInt16(KeyCode.enter) else { return event }
            if event.modifierFlags.contains(.shift) { return event }
            self?.translatorViewModel?.translate()
            return nil
        }
    }

    override func willHide() {
        if let monitor = enterMonitor {
            NSEvent.removeMonitor(monitor)
            enterMonitor = nil
        }
    }
}
