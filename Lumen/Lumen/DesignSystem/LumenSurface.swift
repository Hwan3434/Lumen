import SwiftUI
import AppKit

// MARK: - Elevation

/// Still 깊이 3단계. 다크에서는 위쪽 안쪽 하이라이트 + 그림자, 라이트에서는 그림자만.
struct LumenElevation: ViewModifier {
    let level: Int
    let radius: CGFloat
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let dark = scheme == .dark
        content
            .overlay(alignment: .top) {
                if dark {
                    Rectangle()
                        .fill(Color.white.opacity(level == 1 ? 0.04 : 0.06))
                        .frame(height: 1)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(LumenShape.rect(radius))
            .modifier(Shadows(level: level, dark: dark))
    }

    private struct Shadows: ViewModifier {
        let level: Int
        let dark: Bool

        func body(content: Content) -> some View {
            switch (level, dark) {
            case (1, true):
                content
            case (1, false):
                content.shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            case (2, true):
                content.shadow(color: .black.opacity(0.5), radius: 12, y: 8)
            case (2, false):
                content
                    .shadow(color: .black.opacity(0.06), radius: 1.5, y: 1)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 6)
            case (_, true):
                content.shadow(color: .black.opacity(0.6), radius: 32, y: 24)
            default:
                content
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    .shadow(color: .black.opacity(0.14), radius: 24, y: 20)
            }
        }
    }
}

extension View {
    func lumenElevation(_ level: Int, radius: CGFloat) -> some View {
        modifier(LumenElevation(level: level, radius: radius))
    }

    /// 층 1: 카드, 리스트 그룹. `surface` + `border-subtle` + `elevation-1`, `radius-lg`.
    func lumenCard(radius: CGFloat = LumenTokens.Radius.lg) -> some View {
        self
            .background(LumenTokens.Palette.surface)
            .overlay(LumenShape.rect(radius).strokeBorder(LumenTokens.Palette.borderSubtle, lineWidth: 1))
            .lumenElevation(1, radius: radius)
    }
}

// MARK: - Hairline, panel background

/// 1px 구분선 `border-subtle`. 기본은 가로줄, `.vertical`이면 세로줄.
struct LumenHairline: View {
    private let axis: Axis

    init(_ axis: Axis = .horizontal) {
        self.axis = axis
    }

    var body: some View {
        Rectangle()
            .fill(LumenTokens.Palette.borderSubtle)
            .frame(width: axis == .vertical ? 1 : nil, height: axis == .horizontal ? 1 : nil)
    }
}

/// 떠 있는 패널(런처, 메모 등) 바탕. 층 3: `bg` + `border-subtle`, `radius-xl`.
/// Still은 떠 있는 레이어에 반투명 블러를 허용한다 — 설정 > UI의 글래스 정도만큼 `bg`를 비치게 한다.
/// 그림자는 창 밖으로 그려져야 해서 NSPanel의 `hasShadow`가 맡는다.
struct LumenPanelBackground: View {
    /// 끄면 글래스 설정과 상관없이 불투명한 `bg`를 깐다(리소스 모니터).
    var glass = true

    var body: some View {
        let shape = LumenShape.rect(LumenTokens.Radius.xl)
        Group {
            if glass { LumenGlassFill() } else { LumenTokens.Palette.bg }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(LumenTokens.Palette.borderSubtle, lineWidth: 1))
    }
}

extension View {
    /// 떠 있는 패널의 뼈대. 패널 루트 뷰에 한 번 붙인다: `LumenPanelBackground` 위에 내용을 올리고 패널 반경으로 자른다.
    func lumenPanel(glass: Bool = true) -> some View {
        ZStack {
            LumenPanelBackground(glass: glass)
            self
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(LumenShape.rect(LumenTokens.Radius.xl))
    }
}

/// 글래스 바탕: 설정 > UI의 투명도만큼 시스템 블러 위에 `bg`를 깐다. 0%면 불투명한 `bg`.
/// 떠 있는 패널과 설정 창이 같이 쓴다.
struct LumenGlassFill: View {
    var body: some View {
        ZStack {
            if LumenGlass.isOn {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
            }
            LumenTokens.Palette.bg.opacity(LumenGlass.backgroundOpacity)
        }
    }
}

/// NSVisualEffectView를 SwiftUI에서 쓰기 위한 래퍼.
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
