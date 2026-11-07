import AppKit
import SwiftUI
import Carbon.HIToolbox

extension Notification.Name {
    /// 패널이 ⌘1/⌘2를 받으면 `CalendarMode`를 object로 post한다. `ScheduleView`가 onReceive로 잡는다.
    static let scheduleSwitchView = Notification.Name("com.lumen.schedule.switchView")
}

final class ScheduleWindowController: PanelWindowController {
    private static var panelSize: NSSize { Constants.scheduleWindowSize }
    override var densityContentSize: NSSize? { Self.panelSize }

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

        // ⌘1 / ⌘2 — 월간 / 주간. panel과 SwiftUI view 사이는 NotificationCenter로 격리.
        panel.onCommandKey = { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags == .command else { return false }
            let mode: CalendarMode
            switch Int(event.keyCode) {
            case kVK_ANSI_1: mode = .month
            case kVK_ANSI_2: mode = .week
            default: return false
            }
            NotificationCenter.default.post(name: .scheduleSwitchView, object: mode)
            return true
        }

        let rootView = ScheduleView()
            .environment(ScheduleStore.shared)
        panel.contentView = NSHostingView(rootView: rootView)
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
