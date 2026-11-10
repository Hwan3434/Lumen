import SwiftUI

// Still 컴포넌트 명세(project/components/*/README.md)를 SwiftUI로 옮긴 공용 부품.

private typealias P = LumenTokens.Palette

// MARK: - Button

struct LumenButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, ghost, danger }
    /// `icon`은 안쪽 여백 없이 라벨 크기 그대로 — IconButton 전용.
    enum Size { case small, regular, icon }

    var variant: Variant = .secondary
    var size: Size = .regular

    func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, variant: variant, size: size)
    }

    private struct StyledButton: View {
        let configuration: Configuration
        let variant: Variant
        let size: Size
        @State private var hovered = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let pad: (CGFloat, CGFloat) = switch size {
            case .small: (LumenTokens.Space.scaled(6), LumenTokens.Space.scaled(12))
            case .regular: (LumenTokens.Space.scaled(10), LumenTokens.Space.scaled(16))
            case .icon: (0, 0)
            }
            configuration.label
                .lumenText(.label, weight: .semibold)
                .labelStyle(LumenInlineLabelStyle(iconSize: size == .small ? .small : .regular))
                .foregroundStyle(foreground)
                .padding(.vertical, pad.0)
                .padding(.horizontal, pad.1)
                .background(background, in: LumenShape.rect(LumenTokens.Radius.md))
                .overlay {
                    if variant == .secondary {
                        LumenShape.rect(LumenTokens.Radius.md).strokeBorder(P.borderSubtle, lineWidth: 1)
                    }
                }
                .contentShape(LumenShape.rect(LumenTokens.Radius.md))
                .scaleEffect(configuration.isPressed ? LumenTokens.Motion.scalePress : 1)
                .animation(LumenTokens.Motion.easeOut(LumenTokens.Motion.fast), value: configuration.isPressed)
                .opacity(isEnabled ? 1 : LumenTokens.State.disabledOpacity)
                .onHover { hovered = $0 }
        }

        private var foreground: Color {
            switch variant {
            case .primary: P.onBrand
            case .secondary: P.ink
            case .ghost: P.inkMuted
            case .danger: P.onDanger
            }
        }

        private var background: Color {
            switch variant {
            case .primary: P.brand
            case .secondary: hovered ? P.surfaceRaised : P.surface
            case .ghost: hovered ? P.hover : .clear
            case .danger: P.danger
            }
        }
    }
}

/// 아이콘 하나로 된 정사각형 버튼(Still 40 × 40, 아이콘 20. 밀도에 맞춰 줄어든다). 접근성 이름은 `.help`로 마우스 올림 때도 보인다.
struct LumenIconButton: View {
    let icon: String
    let label: String
    var variant: LumenButtonStyle.Variant = .ghost
    let action: () -> Void

    static var side: CGFloat { LumenTokens.Space.size(40) }

    /// 목록 줄 안에 넣을 때 쓴다. 버튼이 본문 한 줄보다 높아 줄 높이를 늘리므로, 넘치는 만큼 위아래로 겹치게 한다.
    func inRow() -> some View {
        padding(.vertical, -max(0, (Self.side - LumenTextStyle.body.lineHeight) / 2))
    }

    var body: some View {
        Button(action: action) {
            LumenIcon(icon)
                .frame(width: Self.side, height: Self.side)
        }
        .buttonStyle(LumenButtonStyle(variant: variant, size: .icon))
        .accessibilityLabel(label)
        .help(label)
    }
}

/// 버튼 안 아이콘 + 라벨 사이 `space-inline`.
struct LumenInlineLabelStyle: LabelStyle {
    var iconSize: LumenIcon.Size = .regular
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: LumenTokens.Space.inline) {
            configuration.icon.frame(width: iconSize.points, height: iconSize.points)
            configuration.title
        }
    }
}
