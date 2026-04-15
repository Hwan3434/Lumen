import AppKit
import SwiftUI

final class JiraDashboardWindowController {
    private var panel: KeyablePanel?
    private var spaceObserver: Any?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    init() {
        // 스페이스 전환 감지 → 이전 앱 복원 비활성화
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.panel?.activatePreviousAppOnClose = false
        }
    }

    deinit {
        if let obs = spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        let isFirstShow = panel == nil
        if isFirstShow { createPanel() }
        guard let panel = panel, let screen = NSScreen.main else { return }

        if isFirstShow {
            let size = NSSize(width: 820, height: 680)
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.midY - size.height / 2
            panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        }

        // 열 때마다: 이전 앱 기록 + 같은 스페이스라고 리셋
        panel.previousApp = NSWorkspace.shared.frontmostApplication
        panel.activatePreviousAppOnClose = true
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func createPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 680),
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
        panel.minSize = NSSize(width: 400, height: 400)
        panel.autoFocusTextField = false

        panel.onKeyEvent = { [weak self] keyCode in
            if keyCode == KeyCode.escape { self?.hide(); return true }
            return false
        }

        let view = JiraDashboardView()
        panel.contentView = NSHostingView(rootView: view)

        self.panel = panel
    }
}
