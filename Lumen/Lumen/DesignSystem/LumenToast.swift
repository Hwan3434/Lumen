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

    static func show(text: String, swatch: NSColor? = nil, duration: TimeInterval = 1.2) {
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
                ctx.duration = 0.12
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
            ctx.duration = 0.18
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
        p.hasShadow = true
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
        HStack(spacing: 10) {
            if let swatch {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(swatch)
                    .frame(width: 16, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                    )
            }
            Text(text)
                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                .foregroundStyle(LumenTokens.TextColor.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                LumenTokens.BG.windowSolid.opacity(0.92)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.5)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LumenTokens.strokeStrong, lineWidth: 0.5)
        )
        .fixedSize()
    }
}
