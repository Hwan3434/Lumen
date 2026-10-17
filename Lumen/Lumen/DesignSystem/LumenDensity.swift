import AppKit
import Observation

// 설정 > UI 탭에서 고르는 화면 밀도, 글래스 정도, 테마. 둘 다 바꾸는 즉시 반영된다.
// 밀도와 글래스: 토큰(글자 크기, 간격, 창 크기, 패널 배경)이 `LumenUIStore`를 읽으므로, 토큰을 쓰는 SwiftUI 화면은
// Observation 추적으로 알아서 다시 그려진다. 창 크기는 PanelWindowController가 따로 맞춘다.
// 테마: NSApp.appearance만 바꾸면 된다.

/// 지금 쓰는 밀도와 글래스 정도. body 안에서 토큰을 읽으면 이 값의 접근이 추적되어 바뀔 때 다시 그려진다.
@Observable
final class LumenUIStore {
    static let shared = LumenUIStore()
    var density: LumenDensity = LumenDensity.saved
    var glassTransparency: Double = LumenGlass.saved
}

enum LumenDensity: String, CaseIterable {
    /// 예전 Lumen 밀도. Still 타입 스케일보다 작은 글자를 쓴다.
    case compact
    /// Still 크기 안에서 한 단계씩 작게.
    case cozy
    /// Still 크기 그대로, 간격만 줄임.
    case regular
    /// Still 그대로.
    case spacious

    private static let key = "lumen.ui.density"

    /// 지금 화면이 쓰는 밀도.
    static var current: LumenDensity { LumenUIStore.shared.density }

    /// 저장하고 바로 반영한다.
    static var saved: LumenDensity {
        get { UserDefaults.standard.string(forKey: key).flatMap(LumenDensity.init(rawValue:)) ?? .cozy }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            LumenUIStore.shared.density = newValue
        }
    }

    var label: String {
        switch self {
        case .compact:  "아주 촘촘하게"
        case .cozy:     "촘촘하게"
        case .regular:  "보통"
        case .spacious: "넓게"
        }
    }

    var detail: String {
        switch self {
        case .compact:  "예전 Lumen만큼 작게. Still보다 작은 글자를 써요."
        case .cozy:     "Still 크기 안에서 글자와 간격을 한 단계 줄여요."
        case .regular:  "Still 글자 크기에 간격만 조금 줄여요."
        case .spacious: "Still 그대로. 글자와 여백이 가장 넉넉해요."
        }
    }

    /// 밀도별 값 고르기.
    func pick<T>(compact: T, cozy: T, regular: T, spacious: T) -> T {
        switch self {
        case .compact:  compact
        case .cozy:     cozy
        case .regular:  regular
        case .spacious: spacious
        }
    }

    /// 창·열 너비, 헤더 높이처럼 글자보다 큰 덩어리의 크기를 줄인다. 간격보다 완만하게 줄이고 4 단위로 맞춘다.
    func size(_ base: CGFloat) -> CGFloat {
        let scaled = base * pick(compact: 0.78, cozy: 0.85, regular: 0.92, spacious: 1)
        return (scaled / 4).rounded() * 4
    }

    /// 넓게(Still) 기준 간격을 밀도에 맞게 줄인다. 8 미만은 2 단위, 그 이상은 4 단위로 맞춘다.
    func space(_ base: CGFloat) -> CGFloat {
        let scaled = base * pick(compact: 0.5, cozy: 0.67, regular: 0.75, spacious: 1)
        return scaled < 8 ? max(2, (scaled / 2).rounded() * 2) : (scaled / 4).rounded() * 4
    }
}

enum LumenAppearance: String, CaseIterable {
    case system, dark, light

    private static let key = "lumen.ui.appearance"

    @MainActor static var saved: LumenAppearance {
        get { UserDefaults.standard.string(forKey: key).flatMap(LumenAppearance.init(rawValue:)) ?? .dark }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            newValue.apply()
        }
    }

    var label: String {
        switch self {
        case .system: "시스템 설정 따름"
        case .dark:   "다크"
        case .light:  "라이트"
        }
    }

    /// 앱의 모든 창(NSPanel 포함)에 외관을 적용한다. 토큰 색은 외관을 따라 바로 바뀐다.
    @MainActor func apply() {
        NSApp.appearance = switch self {
        case .system: nil
        case .dark:   NSAppearance(named: .darkAqua)
        case .light:  NSAppearance(named: .aqua)
        }
    }
}

/// 떠 있는 패널(런처, 메모 등) 배경을 얼마나 비치게 할지. 시스템 블러 위에 `bg`를 (1 − 투명도)만큼 깐다.
enum LumenGlass {
    /// 투명도 상한. 이보다 비치면 뒤 화면에 글자가 묻힌다.
    static let maxTransparency = 0.8

    private static let key = "lumen.ui.glass.transparency"

    /// 지금 쓰는 투명도(0 = 불투명, 글래스 끔).
    static var current: Double { LumenUIStore.shared.glassTransparency }

    static var saved: Double {
        get {
            let stored = UserDefaults.standard.object(forKey: key) as? Double ?? 0.7
            return min(max(stored, 0), maxTransparency)
        }
        set {
            let clamped = min(max(newValue, 0), maxTransparency)
            UserDefaults.standard.set(clamped, forKey: key)
            LumenUIStore.shared.glassTransparency = clamped
        }
    }

    static var isOn: Bool { current > 0 }

    /// 블러 위에 까는 `bg`의 불투명도.
    static var backgroundOpacity: Double { 1 - current }
}
