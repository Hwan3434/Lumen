import AppKit
import SwiftUI
import os

final class SearchWindowController: PanelWindowController {
    private var viewModel: SearchViewModel?

    override func show() {
        let isFirstShow = panel == nil
        LumenLog.ui.notice("search:show enter firstShow=\(isFirstShow)")
        AppResourceMonitor.trace("search:show:enter(firstShow=\(isFirstShow))")
        super.show()
        LumenLog.ui.notice("search:show exit visible=\(self.isVisible)")
        AppResourceMonitor.trace("search:show:exit")
    }

    override func didCreatePanel(_ panel: KeyablePanel) {
        AppResourceMonitor.trace("search:panel_created")
    }

    override func createPanel() -> KeyablePanel {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: Constants.searchWindowWidth, height: Constants.searchWindowHeight),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = .canJoinAllSpaces
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false

        let vm = SearchViewModel()
        self.viewModel = vm

        // Search 고유 키 처리: ↑↓ 이동, ⏎ 실행, esc 닫기.
        // 다른 panel과 동일하게 onKeyEvent로 일관 처리 — KeyablePanel base는
        // Search를 모름.
        panel.onKeyEvent = { [weak self, weak panel] keyCode in
            guard let vm = self?.viewModel, let panel else { return false }
            switch keyCode {
            case KeyCode.downArrow: vm.moveDown(); return true
            case KeyCode.upArrow:   vm.moveUp();   return true
            case KeyCode.enter:
                vm.executeSelected { [weak self] activatePrev in
                    self?.hide(activatePreviousApp: activatePrev)
                }
                return true
            case KeyCode.escape:
                panel.orderOut(nil)
                return true
            default:
                return false
            }
        }

        let searchView = SearchView(viewModel: vm) { [weak self] in
            self?.hide()
        }

        panel.contentView = NSHostingView(rootView: searchView)
        return panel
    }

    override func configureBeforeShow(_ panel: KeyablePanel) {
        AppResourceMonitor.trace("search:configureBeforeShow:enter")
        viewModel?.reset()
        let frame = NSScreen.underMouse.visibleFrame
        let x = frame.midX - Constants.searchWindowWidth / 2
        let y = frame.midY - Constants.searchWindowHeight / 2
        panel.setFrame(
            NSRect(x: x, y: y, width: Constants.searchWindowWidth, height: Constants.searchWindowHeight),
            display: true
        )
    }

    override func didShow(_ panel: KeyablePanel) {
        AppResourceMonitor.trace("search:didShow")
        guard ClaudeUsageService.isAvailable else { return }
        Task { await ClaudeUsageService.shared.fetchLive() }
        Task { await ClaudeUsageService.shared.fetchHeavy() }
    }
}
