import SwiftUI
import AppKit

// MARK: - Icon

/// Lucide 아이콘. 선 굵기 1.5, 크기는 16(caption·label 옆) / 20(body·버튼·입력창) / 24(title-3 이상).
/// 에셋 이름은 `lucide-<Lucide 원래 이름>` (Assets.xcassets/Icons).
struct LumenIcon: View {
    enum Size {
        case small, regular, large

        /// Still 16 / 20 / 24. 촘촘한 밀도에서는 글자 크기에 맞춰 함께 줄인다.
        var points: CGFloat {
            switch self {
            case .small:   LumenDensity.current.pick(compact: 12, cozy: 16, regular: 16, spacious: 16)
            case .regular: LumenDensity.current.pick(compact: 14, cozy: 16, regular: 20, spacious: 20)
            case .large:   LumenDensity.current.pick(compact: 18, cozy: 20, regular: 24, spacious: 24)
            }
        }
    }

    let name: String
    var size: Size = .regular

    init(_ name: String, size: Size = .regular) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image("lucide-\(name)")
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .frame(width: size.points, height: size.points)
    }

    /// 메뉴바·메뉴 항목용 템플릿 NSImage. 시스템 영역이라 앱의 화면 밀도와 상관없이 16pt로 고정한다.
    static func nsImage(_ name: String, accessibility: String? = nil) -> NSImage? {
        guard let src = NSImage(named: "lucide-\(name)"), let img = src.copy() as? NSImage else { return nil }
        img.size = NSSize(width: 16, height: 16)
        img.isTemplate = true
        img.accessibilityDescription = accessibility
        return img
    }
}
