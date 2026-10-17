import AppKit

// 설정 > UI 탭에서 고르는 화면 밀도와 테마.
// 밀도는 앱을 켤 때 한 번 읽어 토큰(글자 크기, 간격, 창 크기)을 정하므로 바꾸면 재시작해야 반영된다.
// 테마는 NSApp.appearance만 바꾸면 되어 바로 반영된다.

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

    /// 이번 실행 동안 쓰는 밀도. 앱 시작 시 한 번만 읽는다.
    static let current: LumenDensity =
        UserDefaults.standard.string(forKey: key).flatMap(LumenDensity.init(rawValue:)) ?? .spacious

    /// 저장만 한다. 반영은 다음 실행부터.
    static var saved: LumenDensity {
        get { UserDefaults.standard.string(forKey: key).flatMap(LumenDensity.init(rawValue:)) ?? .spacious }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
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
        get { UserDefaults.standard.string(forKey: key).flatMap(LumenAppearance.init(rawValue:)) ?? .system }
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
