import SwiftUI
import AppKit

// Still 디자인 시스템 토큰 (원본: claude.ai Design System 아티팩트 "Still", project/tokens.json).
// 값은 여기에만 둔다. 뷰에서는 이 토큰과 DesignSystem의 공용 부품만 조합하고 RGB·크기를 새로 만들지 않는다.
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

        /// 줄이나 조용한(ghost) 버튼에 마우스를 올렸을 때 덧씌우는 반투명 막. Still에는 없는 Lumen 추가 토큰이다.
        /// Still은 줄에 `surface-raised`, 조용한 버튼에 `surface`를 깔지만, Lumen은 같은 부품을 `bg`·`surface`·`surface-raised`
        /// 위에 모두 올리고 라이트에서는 `surface-raised`와 `bg`가 같은 흰색이라, 불투명 색으로는 안 보이는 자리가 생긴다.
        static let hover         = dyn(dark: (0xffffff, 0.06), light: (0x111113, 0.05))

        static let chart1        = dyn(dark: 0x1aa58f, light: 0x1a9e88)
        static let chart2        = dyn(dark: 0xd95926, light: 0xeb6834)
        static let chart3        = dyn(dark: 0x3987e5, light: 0x2a78d6)
        static let chart4        = dyn(dark: 0xd55181, light: 0xe87ba4)
        static let chart5        = dyn(dark: 0x9085e9, light: 0x6250d6)
        static let chartOther    = dyn(dark: 0x6c6c72, light: 0xa1a1a6)
        static let chartGrid     = borderSubtle

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

        static var s1:  CGFloat { d.space(4) }
        static var s2:  CGFloat { d.space(8) }
        static var s3:  CGFloat { d.space(12) }
        static var s4:  CGFloat { d.space(16) }
        static var s5:  CGFloat { d.space(24) }
        static var s6:  CGFloat { d.space(32) }
        static var s7:  CGFloat { d.space(48) }

        /// ListItem 줄의 세로 여백(Still 14).
        static var rowY: CGFloat { d.space(14) }
        /// 떠 있는 패널 머리 줄의 높이(Still 56). `LumenPanelHeader`와 그 옆에 나란히 놓는 사이드바 머리가 같이 쓴다.
        static var panelHeader: CGFloat { d.size(56) }

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
        static let full: CGFloat = 9999
    }

    // MARK: - Motion

    enum Motion {
        static let fast: Double = 0.15
        static let base: Double = 0.24
        static let slow: Double = 0.36

        static func easeOut(_ d: Double = base) -> Animation { .timingCurve(0.16, 1, 0.3, 1, duration: d) }
        static func easeMove(_ d: Double = base) -> Animation { .timingCurve(0.32, 0.72, 0, 1, duration: d) }

        static let scalePress: CGFloat = 0.97
    }

    // MARK: - State

    enum State {
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
