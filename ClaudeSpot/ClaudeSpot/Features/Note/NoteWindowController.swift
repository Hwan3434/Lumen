import AppKit
import SwiftUI
import Carbon.HIToolbox

final class NoteWindowController {
    private var panel: KeyablePanel?
    private var viewModel: NoteViewModel?

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
        let isFirstShow = panel == nil
        if isFirstShow {
            createPanel()
        }
        guard let panel = panel, let screen = NSScreen.main else { return }

        if isFirstShow {
            let width: CGFloat = 500
            let height: CGFloat = 450
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - width / 2
            let y = screenFrame.midY - height / 2
            panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }

        panel.previousApp = NSWorkspace.shared.frontmostApplication
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func createPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = .canJoinAllSpaces
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 300, height: 250)
        panel.autoFocusTextField = false

        let vm = NoteViewModel()
        self.viewModel = vm

        panel.onKeyEvent = { [weak self] keyCode in
            if keyCode == KeyCode.escape { self?.hide(); return true }
            return false
        }

        // Cmd+Shift+E로 미리보기 토글 (sendEvent 오버라이드 대신 로컬 모니터 사용)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
            guard let panel = panel, panel.isKeyWindow else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.command, .shift] && event.keyCode == UInt16(kVK_ANSI_E) {
                self?.viewModel?.togglePreview()
                return nil
            }
            return event
        }

        let noteView = NoteView(viewModel: vm)
        panel.contentView = NSHostingView(rootView: noteView)

        self.panel = panel
    }
}
