import AppKit
import SwiftUI
import Carbon.HIToolbox

final class NoteWindowController: PanelWindowController {
    /// Note는 단일 패널 정책 예외 — 다른 패널과 나란히 떠 있을 수 있고,
    /// 다른 패널이 떠도 자기는 안 닫는다.
    override var isExclusive: Bool { false }

    private static let panelSize = NSSize(width: 580, height: 680)
    private var viewModel: NoteViewModel?
    private var previewMonitor: Any?

    override func createPanel() -> KeyablePanel {
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
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

        let vm = NoteViewModel()
        self.viewModel = vm

        panel.onKeyEvent = { [weak self] keyCode in
            if keyCode == KeyCode.escape { self?.hide(); return true }
            return false
        }

        // 로컬 키 모니터: ⌘⇧E (preview toggle), ⌘W (close).
        // sendEvent 오버라이드 대신 modifier가 들어간 키만 여기서 잡는다 — 단순 키
        // (esc, ↑↓⏎)는 KeyablePanel.onKeyEvent 경로 그대로 사용.
        previewMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
            guard let panel, panel.isKeyWindow else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.command, .shift] && event.keyCode == UInt16(kVK_ANSI_E) {
                self?.viewModel?.togglePreview()
                return nil
            }
            if flags == .command && event.keyCode == UInt16(kVK_ANSI_W) {
                self?.hide()
                return nil
            }
            return event
        }

        panel.contentView = NSHostingView(rootView: NoteView(viewModel: vm))
        return panel
    }

    override func didCreatePanel(_ panel: KeyablePanel) {
        let frame = NSScreen.underMouse.visibleFrame
        let size = Self.panelSize
        let x = frame.midX - size.width / 2
        let y = frame.midY - size.height / 2
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    deinit {
        if let monitor = previewMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
