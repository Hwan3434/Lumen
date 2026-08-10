import AppKit
import SwiftUI

/// 이슈 상세 창을 이슈당 하나씩 띄운다.
///
/// 대시보드 패널이 쓰는 `PanelWindowController`는 인스턴스당 패널 하나에 단일-패널 정책까지
/// 얹혀 있어 "여러 이슈를 나란히 열어두고 비교한다"는 이 창의 목적과 맞지 않는다.
/// 그래서 일반 NSWindow를 직접 관리한다.
@MainActor
final class IssueDetailWindowManager: NSObject, NSWindowDelegate {
    static let shared = IssueDetailWindowManager()

    private static let defaultSize = NSSize(width: 640, height: 780)
    /// 새 창이 앞 창을 완전히 가리지 않도록 조금씩 어긋나게 놓는다.
    private static let cascadeStep: CGFloat = 26

    private var windows: [String: NSWindow] = [:]
    private var cascadeIndex = 0

    private override init() { super.init() }

    func open(issueKey: String) {
        if let existing = windows[issueKey] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = issueKey
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(LumenTokens.BG.windowSolid)
        window.minSize = NSSize(width: 420, height: 360)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: IssueDetailView(issueKey: issueKey))

        position(window)
        windows[issueKey] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func position(_ window: NSWindow) {
        let visible = NSScreen.underMouse.visibleFrame
        let size = Self.defaultSize
        let offset = CGFloat(cascadeIndex % 6) * Self.cascadeStep
        cascadeIndex += 1

        // 화면보다 큰 기본 크기는 줄여서 띄운다 — 작은 디스플레이에서 제목표시줄이 잘리지 않도록.
        let height = min(size.height, visible.height - 40)
        let x = min(visible.midX - size.width / 2 + offset, visible.maxX - size.width - 8)
        let y = max(visible.minY + 8, visible.midY - height / 2 - offset)
        window.setFrame(NSRect(x: max(visible.minX + 8, x), y: y, width: size.width, height: height),
                        display: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closed = notification.object as? NSWindow else { return }
        windows = windows.filter { $0.value !== closed }
    }
}

/// 이슈 상세 창을 연다. 팝오버·행 어디서든 같은 진입점을 쓴다.
@MainActor
func openIssueDetailWindow(_ issueKey: String) {
    IssueDetailWindowManager.shared.open(issueKey: issueKey)
}
