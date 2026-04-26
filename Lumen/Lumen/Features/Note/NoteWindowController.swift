import AppKit
import SwiftUI
import Carbon.HIToolbox

final class NoteWindowController: PanelWindowController {
    /// Note는 단일 패널 정책 예외 — 다른 패널과 나란히 떠 있을 수 있고,
    /// 다른 패널이 떠도 자기는 안 닫는다.
    override var isExclusive: Bool { false }

    private static let panelSize = NSSize(width: 720, height: 680)
    private var viewModel: NotesViewModel?
    private var keyMonitor: Any?

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
        panel.minSize = NSSize(width: 480, height: 320)

        let vm = NotesViewModel()
        self.viewModel = vm

        panel.onKeyEvent = { [weak self] keyCode in
            if keyCode == KeyCode.escape { self?.hide(); return true }
            return false
        }

        // 로컬 키 모니터 — modifier가 들어간 단축키만 잡고, 단순 키는 KeyablePanel.onKeyEvent로.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
            guard let panel, panel.isKeyWindow else { return event }
            return self?.handleKey(event) ?? event
        }

        panel.contentView = NSHostingView(rootView: NoteView(viewModel: vm))
        return panel
    }

    /// 단축키 매핑:
    /// ⌘W      = 패널 닫기
    /// ⌘N      = 새 노트
    /// ⌘1..⌘9  = N번째 탭으로 이동
    /// ⌘⇧]/[   = 다음/이전 탭
    /// ⌘⇧E     = 편집/미리보기 토글
    /// ⌘⌫      = 현재 노트 삭제 (마지막 1개는 거부)
    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard let vm = viewModel else { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let kc = event.keyCode

        if flags == [.command, .shift] && kc == UInt16(kVK_ANSI_E) {
            vm.togglePreview(); return nil
        }
        if flags == .command && kc == UInt16(kVK_ANSI_W) {
            hide(); return nil
        }
        if flags == .command && kc == UInt16(kVK_ANSI_N) {
            vm.createNewNote(activate: true); return nil
        }
        if flags == .command && kc == UInt16(kVK_Delete) {
            vm.deleteCurrent(); return nil
        }
        if flags == [.command, .shift] && kc == UInt16(kVK_ANSI_RightBracket) {
            vm.selectNext(); return nil
        }
        if flags == [.command, .shift] && kc == UInt16(kVK_ANSI_LeftBracket) {
            vm.selectPrev(); return nil
        }

        // ⌘1 ~ ⌘9 — 텍스트 입력 영역 안에서도 노트 전환을 가로채야 한다.
        if flags == .command, let index = digitKeyIndex(kc) {
            vm.selectIndex(index)
            return nil
        }

        return event
    }

    /// kVK_ANSI_1 ~ kVK_ANSI_9 → 0~8 인덱스. 그 외는 nil.
    private func digitKeyIndex(_ keyCode: UInt16) -> Int? {
        switch Int(keyCode) {
        case kVK_ANSI_1: return 0
        case kVK_ANSI_2: return 1
        case kVK_ANSI_3: return 2
        case kVK_ANSI_4: return 3
        case kVK_ANSI_5: return 4
        case kVK_ANSI_6: return 5
        case kVK_ANSI_7: return 6
        case kVK_ANSI_8: return 7
        case kVK_ANSI_9: return 8
        default: return nil
        }
    }

    override func didCreatePanel(_ panel: KeyablePanel) {
        let frame = NSScreen.underMouse.visibleFrame
        let size = Self.panelSize
        let x = frame.midX - size.width / 2
        let y = frame.midY - size.height / 2
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    deinit {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
