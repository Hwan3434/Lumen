import SwiftUI
import AppKit
import CoreText

// Still 디자인 시스템 토큰 (원본: claude.ai Design System 아티팩트 "Still", project/tokens.json).
// 값은 여기에만 둔다. 뷰에서는 이 토큰과 아래 공용 부품만 조합하고 RGB·크기를 새로 만들지 않는다.
// 색은 시스템 외관(다크/라이트)을 따라 자동으로 바뀐다.

enum LumenTokens {

    // MARK: - Color

    enum Palette {
        static let bg            = dyn(dark: 0x0a0a0b, light: 0xffffff)
        static let surface       = dyn(dark: 0x141415, light: 0xf5f5f7)
        static let surfaceRaised = dyn(dark: 0x1c1c1e, light: 0xffffff)
        static let borderSubtle  = dyn(dark: 0x2c2c2e, light: 0xe5e5ea)
        static let borderStrong  = dyn(dark: 0x6c6c72, light: 0x86868b)

        static let ink           = dyn(dark: 0xf5f5f7, light: 0x111113)
        static let inkMuted      = dyn(dark: 0xa1a1a6, light: 0x5d5d63)
        static let inkFaint      = dyn(dark: 0x8a8a90, light: 0x6e6e73)

        static let brand         = dyn(dark: 0x2fd3b5, light: 0x0a7466)
        static let brandSoft     = dyn(dark: (0x2fd3b5, 0.12), light: (0x0a7466, 0.08))
        static let onBrand       = dyn(dark: 0x0a0a0b, light: 0xffffff)

        static let success       = dyn(dark: 0x4cd471, light: 0x1a7f37)
        static let successSoft   = dyn(dark: (0x4cd471, 0.12), light: (0x1a7f37, 0.08))
        static let warning       = dyn(dark: 0xffb340, light: 0x966300)
        static let warningSoft   = dyn(dark: (0xffb340, 0.12), light: (0x966300, 0.08))
        static let danger        = dyn(dark: 0xff6961, light: 0xcf222e)
        static let dangerSoft    = dyn(dark: (0xff6961, 0.12), light: (0xcf222e, 0.08))
        static let onDanger      = dyn(dark: 0x0a0a0b, light: 0xffffff)
        static let info          = dyn(dark: 0x64a8ff, light: 0x0b67d0)
        static let infoSoft      = dyn(dark: (0x64a8ff, 0.12), light: (0x0b67d0, 0.08))

        static let codeKeyword   = info
        static let codeString    = success
        static let codeNumber    = warning
        static let codeComment   = inkFaint

        static let focusRing     = brand

        static let chart1        = dyn(dark: 0x1aa58f, light: 0x1a9e88)
        static let chart2        = dyn(dark: 0xd95926, light: 0xeb6834)
        static let chart3        = dyn(dark: 0x3987e5, light: 0x2a78d6)
        static let chart4        = dyn(dark: 0xd55181, light: 0xe87ba4)
        static let chart5        = dyn(dark: 0x9085e9, light: 0x6250d6)
        static let chartOther    = dyn(dark: 0x6c6c72, light: 0xa1a1a6)
        static let chartGrid     = borderSubtle
        static let chartAxis     = inkFaint

        static let scrim         = dyn(dark: (0x000000, 0.6), light: (0x111113, 0.32))

        /// 떠 있는 패널 안에 넓게 까는 `surface`(하단 바, 사이드 영역).
        /// 글래스가 켜져 있으면 면을 한 겹 더 깔면 그 영역만 덜 비치므로 깔지 않고, 구분선으로만 나눈다.
        static var panelSurface: Color { LumenGlass.isOn ? .clear : surface }

        /// 차트 범주 색. 항상 앞에서부터 순서대로 쓴다. 다섯을 넘으면 `chartOther`.
        static let chartCategories = [chart1, chart2, chart3, chart4, chart5]
    }

    // MARK: - Spacing (4px 단위)

    /// Still 간격을 화면 밀도(`LumenDensity`)에 맞게 줄인 값. 넓게(spacious)에서는 Still 값 그대로다.
    enum Space {
        private static var d: LumenDensity { LumenDensity.current }

        static var inline:  CGFloat { d.space(8) }
        static var stack:   CGFloat { d.space(12) }
        static var group:   CGFloat { d.space(24) }
        static var pad:     CGFloat { d.space(24) }
        static var section: CGFloat { d.space(64) }
        static var page:    CGFloat { d.space(32) }

        static var s1:  CGFloat { d.space(4) }
        static var s2:  CGFloat { d.space(8) }
        static var s3:  CGFloat { d.space(12) }
        static var s4:  CGFloat { d.space(16) }
        static var s5:  CGFloat { d.space(24) }
        static var s6:  CGFloat { d.space(32) }
        static var s7:  CGFloat { d.space(48) }
        static var s8:  CGFloat { d.space(64) }
        static var s9:  CGFloat { d.space(96) }
        static var s10: CGFloat { d.space(128) }

        /// ListItem 줄의 세로 여백(Still 14).
        static var rowY: CGFloat { d.space(14) }

        /// 위 이름에 없는 Still 치수(헤더 높이, 칸 높이 등)를 밀도에 맞게 줄일 때 쓴다.
        static func scaled(_ base: CGFloat) -> CGFloat { d.space(base) }

        /// 창·열 너비, 헤더 높이 같은 큰 치수(Still 기준)를 밀도에 맞게 줄인다.
        static func size(_ base: CGFloat) -> CGFloat { d.size(base) }
    }

    // MARK: - Radius

    enum Radius {
        /// 태그, 배지, 작은 칩
        static let xs: CGFloat = 6
        /// 썸네일, 아이콘 타일, 작은 버튼
        static let sm: CGFloat = 8
        /// 버튼, 입력창, 팝오버, 메뉴
        static let md: CGFloat = 12
        /// 카드, 리스트 그룹, 섹션 패널
        static let lg: CGFloat = 16
        /// 시트, 모달, 큰 미디어
        static let xl: CGFloat = 22
        /// 페이지 단위 큰 패널
        static let xxl: CGFloat = 28
        static let full: CGFloat = 9999
    }

    // MARK: - Motion

    enum Motion {
        static let fast: Double = 0.15
        static let base: Double = 0.24
        static let slow: Double = 0.36

        static func easeOut(_ d: Double = base) -> Animation { .timingCurve(0.16, 1, 0.3, 1, duration: d) }
        static func easeIn(_ d: Double = base) -> Animation  { .timingCurve(0.5, 0, 0.75, 0, duration: d) }
        static func easeMove(_ d: Double = base) -> Animation { .timingCurve(0.32, 0.72, 0, 1, duration: d) }

        static let moveSm: CGFloat = 8
        static let scaleEnter: CGFloat = 0.96
        static let scalePress: CGFloat = 0.97
    }

    // MARK: - State

    enum State {
        static let focusRingWidth: CGFloat = 2
        static let focusRingOffset: CGFloat = 2
        static let disabledOpacity: Double = 0.4
    }

    // MARK: - Helpers

    private static func dyn(dark: Int, light: Int) -> Color {
        dyn(dark: (dark, 1), light: (light, 1))
    }

    private static func dyn(dark: (Int, Double), light: (Int, Double)) -> Color {
        let d = nsColor(dark.0, dark.1), l = nsColor(light.0, light.1)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? d : l
        })
    }

    private static func nsColor(_ hex: Int, _ alpha: Double) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                green: CGFloat((hex >> 8) & 0xff) / 255,
                blue: CGFloat(hex & 0xff) / 255,
                alpha: alpha)
    }
}

// MARK: - Shape

enum LumenShape {
    /// Still 곡률 규칙: `Radius.lg`(16) 이상은 연속 곡률(squircle), 그 아래는 일반 원호.
    static func rect(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: radius >= LumenTokens.Radius.lg ? .continuous : .circular)
    }
}

// MARK: - Typography

/// Still 타입 스케일 8단계 + 코드. 본문·제목은 SUIT, 코드는 Geist Mono.
enum LumenTextStyle {
    case display, title1, title2, title3, bodyLarge, body, label, caption, codeBlock

    /// 글자 크기와 행간. 넓게·보통은 Still 그대로, 촘촘은 Still 단계 안에서 한 칸씩 작게,
    /// 아주 촘촘은 예전 Lumen 크기(Still 밖)다.
    private var metrics: (size: CGFloat, lineHeight: CGFloat) {
        switch LumenDensity.current {
        case .spacious, .regular:
            switch self {
            case .display: (56, 64)
            case .title1: (40, 48)
            case .title2: (28, 36)
            case .title3: (20, 28)
            case .bodyLarge: (18, 30)
            case .body: (16, 26)
            case .label: (14, 20)
            case .caption: (12, 16)
            case .codeBlock: (14, 22)
            }
        case .cozy:
            switch self {
            case .display: (40, 48)
            case .title1: (28, 36)
            case .title2: (20, 28)
            case .title3: (18, 26)
            case .bodyLarge: (16, 24)
            case .body: (14, 20)
            case .label: (12, 16)
            case .caption: (12, 16)
            case .codeBlock: (12, 18)
            }
        case .compact:
            switch self {
            case .display: (32, 40)
            case .title1: (24, 30)
            case .title2: (18, 24)
            case .title3: (15, 20)
            case .bodyLarge: (14, 20)
            case .body: (13, 18)
            case .label: (12, 16)
            case .caption: (11, 14)
            case .codeBlock: (12, 16)
            }
        }
    }

    var size: CGFloat { metrics.size }
    var lineHeight: CGFloat { metrics.lineHeight }

    /// em 단위 자간. 큰 제목일수록 살짝 좁힌다.
    var tracking: CGFloat {
        switch self {
        case .display: -0.03
        case .title1: -0.025
        case .title2: -0.02
        case .title3: -0.01
        default: 0
        }
    }

    var defaultWeight: LumenWeight {
        switch self {
        case .display, .title1: .bold
        case .title2, .title3: .semibold
        case .label: .medium
        default: .regular
        }
    }

    var isMono: Bool { self == .codeBlock }
}

/// Still이 허용하는 굵기 네 단계.
enum LumenWeight: CGFloat {
    case regular = 400, medium = 500, semibold = 600, bold = 700
}

enum LumenFont {
    private static let wghtAxis = NSNumber(value: 0x77676874) // 'wght'
    private static let registered: Void = {
        for name in ["SUIT-Variable", "GeistMono-Variable"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }()
    @MainActor private static var cache: [String: Font] = [:]

    /// 앱 시작 시 한 번 불러 글꼴을 등록한다. MarkdownUI처럼 이름으로 글꼴을 찾는 곳도 쓸 수 있게.
    static func register() { _ = registered }

    static func sans(_ size: CGFloat, _ weight: LumenWeight = .regular) -> Font {
        font(family: "SUIT Variable", size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, _ weight: LumenWeight = .regular) -> Font {
        font(family: "Geist Mono", size: size, weight: weight)
    }

    static func style(_ style: LumenTextStyle, weight: LumenWeight? = nil) -> Font {
        let w = weight ?? style.defaultWeight
        return style.isMono ? mono(style.size, w) : sans(style.size, w)
    }

    /// AppKit 쪽(NSTextView 등)에서 쓰는 같은 글꼴.
    static func nsFont(family: String = "SUIT Variable", size: CGFloat, weight: LumenWeight = .regular) -> NSFont {
        _ = registered
        let desc = NSFontDescriptor(fontAttributes: [
            .family: family,
            .variation: [wghtAxis: weight.rawValue],
        ])
        return NSFont(descriptor: desc, size: size) ?? .systemFont(ofSize: size)
    }

    @MainActor private static var lineSpacingCache: [String: CGFloat] = [:]

    /// Still 행간(lineHeight)을 맞추려면 글꼴 자체 높이를 뺀 나머지를 lineSpacing으로 준다.
    /// 모든 Text의 body에서 불리므로 스타일별로 한 번만 계산한다.
    static func extraLineSpacing(_ style: LumenTextStyle) -> CGFloat {
        MainActor.assumeIsolated {
            let key = "\(LumenDensity.current.rawValue)|\(style)"
            if let cached = lineSpacingCache[key] { return cached }
            let f = nsFont(family: style.isMono ? "Geist Mono" : "SUIT Variable", size: style.size)
            let spacing = max(0, style.lineHeight - (f.ascender - f.descender + f.leading))
            lineSpacingCache[key] = spacing
            return spacing
        }
    }

    private static func font(family: String, size: CGFloat, weight: LumenWeight) -> Font {
        MainActor.assumeIsolated {
            let key = "\(family)|\(size)|\(weight.rawValue)"
            if let f = cache[key] { return f }
            let f = Font(nsFont(family: family, size: size, weight: weight))
            cache[key] = f
            return f
        }
    }
}

extension View {
    /// Still 글자 스타일: 글꼴 + 행간 + 자간. 한글은 단어 단위 줄바꿈이 SwiftUI 기본이다.
    func lumenText(_ style: LumenTextStyle, weight: LumenWeight? = nil) -> some View {
        self
            .font(LumenFont.style(style, weight: weight))
            .lineSpacing(LumenFont.extraLineSpacing(style))
            .tracking(style.size * style.tracking)
    }
}

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

    /// 층 2: 팝오버, 메뉴, 툴팁. `surface-raised` + `border-subtle` + `elevation-2`.
    func lumenPopover(radius: CGFloat = LumenTokens.Radius.md) -> some View {
        self
            .background(LumenTokens.Palette.surfaceRaised)
            .overlay(LumenShape.rect(radius).strokeBorder(LumenTokens.Palette.borderSubtle, lineWidth: 1))
            .lumenElevation(2, radius: radius)
    }
}

// MARK: - Small shared parts

/// 묶음 이름. `label` 굵기 500 `ink-muted`.
struct LumenSectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .lumenText(.label)
            .foregroundStyle(LumenTokens.Palette.inkMuted)
    }
}

/// 단축키 표시. Still Code 부품(Geist Mono, `surface-raised`, `border-subtle`, `radius-xs`).
struct LumenKbd: View {
    let label: String
    var primary: Bool = false
    var body: some View {
        Text(label)
            .font(LumenFont.mono(LumenTextStyle.caption.size))
            .foregroundStyle(primary ? LumenTokens.Palette.ink : LumenTokens.Palette.inkMuted)
            .padding(.horizontal, LumenTokens.Space.scaled(6))
            .padding(.vertical, LumenTokens.Space.scaled(2))
            .background(LumenTokens.Palette.surfaceRaised, in: LumenShape.rect(LumenTokens.Radius.xs))
            .overlay(LumenShape.rect(LumenTokens.Radius.xs).strokeBorder(LumenTokens.Palette.borderSubtle, lineWidth: 1))
    }
}

/// 1px 구분선 `border-subtle`.
struct LumenHairline: View {
    var body: some View {
        Rectangle()
            .fill(LumenTokens.Palette.borderSubtle)
            .frame(height: 1)
    }
}

/// 떠 있는 패널(런처, 메모 등) 바탕. 층 3: `bg` + `border-subtle`, `radius-xl`.
/// Still은 떠 있는 레이어에 반투명 블러를 허용한다 — 설정 > UI의 글래스 정도만큼 `bg`를 비치게 한다.
/// 그림자는 창 밖으로 그려져야 해서 NSPanel의 `hasShadow`가 맡는다.
struct LumenPanelBackground: View {
    var radius: CGFloat = LumenTokens.Radius.xl

    var body: some View {
        ZStack {
            if LumenGlass.isOn {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
            }
            LumenTokens.Palette.bg.opacity(LumenGlass.backgroundOpacity)
        }
        .clipShape(LumenShape.rect(radius))
        .overlay(LumenShape.rect(radius).strokeBorder(LumenTokens.Palette.borderSubtle, lineWidth: 1))
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
