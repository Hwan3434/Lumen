import AppKit
import Carbon.HIToolbox
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
            case KeyCode.downArrow: return vm.moveDown()
            case KeyCode.upArrow:   return vm.moveUp()
            case KeyCode.escape:    self?.hide();  return true
            default: return false
            }
        }

        // ⌘C: 입력 칸에서 고른 글이 없을 때만 번역 결과를 복사한다. 고른 글이 있으면 평소처럼 그 글을 복사한다.
        panel.onCommandKey = { [weak self, weak panel] event in
            guard let vm = self?.translatorViewModel, !vm.translatedText.isEmpty,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  Int(event.keyCode) == kVK_ANSI_C,
                  let input = panel?.firstResponder as? NSTextView, input.selectedRange().length == 0
            else { return false }
            vm.copyToClipboard()
            LumenToast.show(text: "번역 결과를 복사했어요")
            return true
        }

        return panel
    }

    override func configureBeforeShow(_ panel: KeyablePanel) {
        translatorViewModel?.shownAt = Date()
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
