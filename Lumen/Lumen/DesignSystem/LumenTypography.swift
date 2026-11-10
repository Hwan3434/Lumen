import SwiftUI
import AppKit
import CoreText

// MARK: - Typography

/// Still 타입 스케일 가운데 Lumen이 쓰는 7단계 + 코드. 본문·제목은 SUIT, 코드는 Geist Mono.
enum LumenTextStyle {
    case title1, title2, title3, bodyLarge, body, label, caption, codeBlock

    /// 글자 크기와 행간. 넓게·보통은 Still 그대로, 촘촘은 Still 단계 안에서 한 칸씩 작게,
    /// 아주 촘촘은 예전 Lumen 크기(Still 밖)다.
    private var metrics: (size: CGFloat, lineHeight: CGFloat) {
        switch LumenDensity.current {
        case .spacious, .regular:
            switch self {
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
        case .title1: -0.025
        case .title2: -0.02
        case .title3: -0.01
        default: 0
        }
    }

    var defaultWeight: LumenWeight {
        switch self {
        case .title1: .bold
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
        // SUIT는 woff2 판만 빈 한글 글리프를 빼고 배포한다. ttf는 없는 글자를 빈칸으로 그려 시스템 대체 글꼴이 안 붙는다.
        for (name, ext) in [("SUIT-Variable", "woff2"), ("GeistMono-Variable", "ttf")] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
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
