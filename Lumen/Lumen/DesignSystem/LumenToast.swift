import AppKit
import SwiftUI

// 작은 알약 모양의 borderless 패널을 화면 하단 중앙(Dock 위)에 잠깐 띄우는 공용 토스트.
// 시스템 알림(UNUserNotification)을 안 쓰는 이유: 권한 다이얼로그·알림 센터 누적·표시 지연 회피.
//
// 사용:
//   LumenToast.show(text: "#A1B2C3 복사됨", swatch: .red)
//
// 같은 토스트가 빠르게 연속 호출되면 기존 패널을 재사용해 깜빡임 없이 갱신한다.

enum LumenToast {
    @MainActor private static var controller: ToastController?

    static func show(text: String, swatch: NSColor? = nil, duration: TimeInterval = 2) {
        Task { @MainActor in
            let ctrl = controller ?? ToastController()
            controller = ctrl
            ctrl.present(text: text, swatch: swatch.map(Color.init(nsColor:)), duration: duration)
        }
    }
}

@MainActor
private final class ToastController {
    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    func present(text: String, swatch: Color?, duration: TimeInterval) {
        let view = ToastBody(text: text, swatch: swatch)
        let hosting = NSHostingView(rootView: view)
        hosting.layout()
        let size = hosting.fittingSize

        let panel = ensurePanel()
        panel.contentView = hosting
        positionPanel(panel, size: size)

        // fade-out 진행 중에 다시 호출돼도 alpha를 1로 끌어올린다.
        // 새 fade-in 애니메이션이 진행 중인 fade-out animator를 덮어써서 중단시킨다.
        if panel.alphaValue < 1 || !panel.isVisible {
            if !panel.isVisible {
                panel.alphaValue = 0
                panel.orderFrontRegardless()
            }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = LumenTokens.Motion.slow
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.32, 0.72, 0, 1)
                panel.animator().alphaValue = 1
            }
        }

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func dismiss() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = LumenTokens.Motion.base
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 0, 0.75, 0)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            // 완료 시점에 새 present()가 alpha=1로 되돌렸으면 숨기지 않는다.
            // panel 인스턴스는 재사용을 위해 유지 — nil 처리 안 함.
            if panel.alphaValue == 0 { panel.orderOut(nil) }
        })
    }

    private func ensurePanel() -> NSPanel {
        if let p = panel { return p }
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.backgroundColor = .clear
        p.hasShadow = false
        p.isOpaque = false
        p.isReleasedWhenClosed = false
        p.ignoresMouseEvents = true
        panel = p
        return p
    }

    private func positionPanel(_ panel: NSPanel, size: NSSize) {
        let frame = NSScreen.underMouse.visibleFrame
        let x = frame.midX - size.width / 2
        let y = frame.minY + 80
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}

private struct ToastBody: View {
    let text: String
    let swatch: Color?

    var body: some View {
        HStack(spacing: LumenTokens.Space.inline) {
            if let swatch {
                LumenShape.rect(LumenTokens.Radius.xs)
                    .fill(swatch)
                    .frame(width: LumenIcon.Size.regular.points, height: LumenIcon.Size.regular.points)
                    .overlay(LumenShape.rect(LumenTokens.Radius.xs).strokeBorder(LumenTokens.Palette.borderSubtle, lineWidth: 1))
            } else {
                LumenIcon("circle-check").foregroundStyle(LumenTokens.Palette.success)
            }
            Text(text)
                .lumenText(.label, weight: .regular)
                .foregroundStyle(LumenTokens.Palette.ink)
        }
        .padding(.vertical, LumenTokens.Space.scaled(10))
        .padding(.horizontal, LumenTokens.Space.scaled(16))
        .background(LumenTokens.Palette.surfaceRaised, in: Capsule())
        .overlay(Capsule().strokeBorder(LumenTokens.Palette.borderSubtle, lineWidth: 1))
        .lumenElevation(2, radius: LumenTokens.Radius.full)
        .padding(LumenTokens.Space.s5)
        .fixedSize()
    }
}
