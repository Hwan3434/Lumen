import AppKit
import SwiftUI
import Carbon.HIToolbox

final class JiraDashboardWindowController: PanelWindowController {
    private static let panelSize = NSSize(width: 1160, height: 840)

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
        panel.minSize = NSSize(width: 400, height: 400)
        panel.autoFocusTextField = false

        panel.onKeyEvent = { [weak self, weak panel] keyCode in
            if keyCode == KeyCode.escape {
                // popover가 떠 있을 때는 ESC가 popover를 닫게 양보 — panel 자체는 그대로.
                // SwiftUI popover는 _NSPopoverWindow 라는 별도 NSWindow로 뜨고 panel의
                // childWindows에 들어간다. 그게 있으면 panel hide를 건너뛴다.
                if let panel, panel.childWindows?.contains(where: { $0.isVisible }) == true {
                    return false
                }
                self?.hide()
                return true
            }
            return false
        }

        // ⌘1 / ⌘2 / ⌘3 — 대시보드 / 월간 / 타임라인 탭 이동.
        // panel과 SwiftUI view 사이 통신은 NotificationCenter로 — view의 @State를
        // 외부로 끌어내지 않고 깔끔하게 격리.
        panel.onCommandKey = { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags == .command else { return false }
            let tabIndex: Int
            switch Int(event.keyCode) {
            case kVK_ANSI_1: tabIndex = 0
            case kVK_ANSI_2: tabIndex = 1
            case kVK_ANSI_3: tabIndex = 2
            default: return false
            }
            NotificationCenter.default.post(name: .jiraSwitchTab, object: tabIndex)
            return true
        }

        panel.contentView = NSHostingView(rootView: JiraDashboardView())
        return panel
    }

    override func didCreatePanel(_ panel: KeyablePanel) {
        let frame = NSScreen.underMouse.visibleFrame
        let size = Self.panelSize
        let x = frame.midX - size.width / 2
        let y = frame.midY - size.height / 2
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}
