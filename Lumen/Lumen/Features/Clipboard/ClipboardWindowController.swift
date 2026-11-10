import AppKit
import SwiftUI

final class ClipboardWindowController: PanelWindowController {
    private static var panelSize: NSSize { Constants.clipboardWindowSize }
    override var densityContentSize: NSSize? { Self.panelSize }
    private var clipboardViewModel: ClipboardViewModel?

    override func createPanel() -> KeyablePanel {
        let panel = makePanel(size: Self.panelSize)

        let vm = ClipboardViewModel()
        self.clipboardViewModel = vm

        panel.contentView = NSHostingView(rootView: ClipboardView(viewModel: vm))

        panel.onKeyEvent = { [weak self, weak panel] keyCode in
            guard let vm = self?.clipboardViewModel else { return false }
            switch keyCode {
            case KeyCode.downArrow: vm.moveDown(); return true
            case KeyCode.upArrow:   vm.moveUp();   return true
            case KeyCode.enter:
                vm.copySelected()
                self?.hide()
                return true
            case KeyCode.escape: self?.hide(); return true
            case KeyCode.delete, KeyCode.forwardDelete:
                // 검색창 포커스 중에는 텍스트 편집용으로 흘려보낸다.
                if let responder = panel?.firstResponder,
                   responder is NSText || responder is NSTextView {
                    return false
                }
                vm.deleteSelected()
                return true
            default: return false
            }
        }

        // 검색창에 포커스가 있어도 선택한 항목을 지울 수 있는 키. 노트의 ⌘⌫(노트 삭제)와 같은 조합이다.
        panel.onCommandKey = { [weak self] event in
            guard let vm = self?.clipboardViewModel,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  Int(event.keyCode) == KeyCode.delete else { return false }
            vm.deleteSelected()
            return true
        }

        return panel
    }

    override func configureBeforeShow(_ panel: KeyablePanel) {
        clipboardViewModel?.panelWillShow()
        centerUnderMouse(panel, size: Self.panelSize)
    }

    override func willHide() {
        clipboardViewModel?.panelDidHide()
    }
}
