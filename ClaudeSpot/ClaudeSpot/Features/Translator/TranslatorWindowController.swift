import AppKit
import SwiftUI

final class TranslatorWindowController {
    private var panel: KeyablePanel?
    private var translatorViewModel: TranslatorViewModel?
    private var enterMonitor: Any?

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

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - Constants.translatorWindowWidth / 2
        let y = screenFrame.midY - Constants.translatorWindowHeight / 2

        panel.setFrame(
            NSRect(x: x, y: y, width: Constants.translatorWindowWidth, height: Constants.translatorWindowHeight),
            display: true
        )
        panel.previousApp = NSWorkspace.shared.frontmostApplication
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()

        if enterMonitor == nil {
            enterMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
                guard let panel = panel, panel.isKeyWindow,
                      event.keyCode == UInt16(KeyCode.enter) else { return event }
                if event.modifierFlags.contains(.shift) {
                    return event
                }
                self?.translatorViewModel?.translate()
                return nil
            }
        }
    }

    func hide() {
        if let monitor = enterMonitor {
            NSEvent.removeMonitor(monitor)
            enterMonitor = nil
        }
        panel?.orderOut(nil)
    }

    private func createPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: Constants.translatorWindowWidth, height: Constants.translatorWindowHeight),
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

        let vm = TranslatorViewModel()
        self.translatorViewModel = vm

        let translatorView = TranslatorView(viewModel: vm)
        panel.contentView = NSHostingView(rootView: translatorView)

        panel.onKeyEvent = { [weak self] keyCode in
            guard let vm = self?.translatorViewModel else { return false }
            switch keyCode {
            case KeyCode.downArrow: vm.moveDown(); return true
            case KeyCode.upArrow: vm.moveUp(); return true
            case KeyCode.escape: self?.hide(); return true
            default: return false
            }
        }

        self.panel = panel
    }
}
