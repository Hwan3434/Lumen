import SwiftUI
import AppKit

// MARK: - Window drag handle
//
// `.nonactivatingPanel` 스타일의 NSPanel은 `isMovableByWindowBackground = true`로도 안 움직여
// (`kCGSPreventsActivationTagBit` 이슈), `mouseDown(with:)`이 자기에게 직접 와서 `performDrag`를
// 불러야 AppKit drag tracking이 시작된다. 헤더 같은 특정 영역에만 깔아 그 영역에서만 윈도우 이동.
// 패널 머리 줄은 `LumenPanelHeader`가 이 영역을 깔아 준다. 직접 쓸 때는 ZStack 맨 아래에 깔고,
// 그 위 내용 가운데 누를 수 없는 것에는 `.allowsHitTesting(false)`를 붙여 mouseDown이 여기까지 내려오게 한다.

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        override var mouseDownCanMoveWindow: Bool { true }
    }
}

// MARK: - Panel header

/// 떠 있는 패널의 머리 줄: 아이콘 + 제목 + 보조 표시(`accessory`), 오른쪽 끝에 버튼·단축키(`trailing`), 아래 구분선.
/// 빈 곳을 끌면 창이 움직인다. 왼쪽 내용은 hit-test에서 빠져 끌기를 막지 않고, `trailing`만 누를 수 있다 —
/// 그래서 눌러야 하는 것은 반드시 `trailing`에 둔다.
struct LumenPanelHeader<Accessory: View, Trailing: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let trailing: () -> Trailing

    init(icon: String, title: String,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.icon = icon
        self.title = title
        self.accessory = accessory
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                WindowDragArea()
                HStack(spacing: LumenTokens.Space.s3) {
                    HStack(spacing: LumenTokens.Space.s3) {
                        HStack(spacing: LumenTokens.Space.inline) {
                            LumenIcon(icon)
                                .foregroundStyle(LumenTokens.Palette.inkMuted)
                            Text(title)
                                .lumenText(.body, weight: .semibold)
                                .foregroundStyle(LumenTokens.Palette.ink)
                                .lineLimit(1)
                        }
                        accessory()
                    }
                    .allowsHitTesting(false)
                    Spacer(minLength: 0)
                    trailing()
                }
                .padding(.horizontal, LumenTokens.Space.pad)
            }
            .frame(height: LumenTokens.Space.panelHeader)
            LumenHairline()
        }
    }
}

// MARK: - Relative time formatting (한국어 단축 표기)

enum LumenTime {
    enum Granularity {
        /// "방금" / "N분 전" / "N시간 전" / "N일 전". 일정 갱신 시각, 리소스 이상 기록.
        case minutesAndHours
        /// "방금" / "N분" / "N시간" / "어제" / "N일" — 접미사 "전" 없음. 클립보드/번역 히스토리 톤.
        case shortNoSuffix
        /// "오늘 오후 2:30" / "어제 오후 2:30" / "11. 7 오후 2:30" — 절대 시간. 클립보드 메타, 앱 마지막 실행, 환율 기준 시각.
        case calendar
    }

    /// `now`는 "지금"으로 삼을 시각. 상대 시간(`minutesAndHours`, `shortNoSuffix`)에만 쓰인다.
    static func relative(_ date: Date, granularity: Granularity = .minutesAndHours, now: Date = Date()) -> String {
        switch granularity {
        case .minutesAndHours:   return minutesAndHours(date, now: now)
        case .shortNoSuffix:     return shortNoSuffix(date, now: now)
        case .calendar:          return calendar(date)
        }
    }

    private static func minutesAndHours(_ date: Date, now: Date) -> String {
        let mins = Int(now.timeIntervalSince(date) / 60)
        if mins < 1 { return "방금" }
        if mins < 60 { return "\(mins)분 전" }
        if mins < 60 * 24 { return "\(mins / 60)시간 전" }
        return "\(mins / (60 * 24))일 전"
    }

    private static func shortNoSuffix(_ date: Date, now: Date) -> String {
        let interval = now.timeIntervalSince(date)
        if interval < 60 { return "방금" }
        if interval < 3600 { return "\(Int(interval / 60))분" }
        if interval < 86400 { return "\(Int(interval / 3600))시간" }
        let days = Int(interval / 86400)
        if days == 1 { return "어제" }
        return "\(days)일"
    }

    private static let calendarFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    private static func calendar(_ date: Date) -> String {
        let cal = Calendar.current
        let f = calendarFormatter
        if cal.isDateInToday(date)         { f.dateFormat = "오늘 a h:mm" }
        else if cal.isDateInYesterday(date){ f.dateFormat = "어제 a h:mm" }
        else                               { f.dateFormat = "M. d a h:mm" }
        return f.string(from: date)
    }
}

// MARK: - Shared date formatters (per-render allocation 회피)

enum LumenDateFormat {
    /// "2026. 11. 7 (토)" — Still 날짜 표기.
    static let dayWithWeekday: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "yyyy. M. d (E)"; return f
    }()
    /// "11. 7" — 연도 없는 짧은 날짜.
    static let shortDay: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M. d"; return f
    }()
    /// "11. 7 (토)" — 연도 없는 짧은 날짜에 요일.
    static let shortDayWithWeekday: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M. d (E)"; return f
    }()
    /// "오후 2:30" — Still 시간 표기.
    static let time: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "a h:mm"; return f
    }()
    /// "2026년 11월" — 달력 헤더.
    static let yearMonthKo: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "yyyy년 M월"; return f
    }()
    /// "11월 7일" — 월간 달력 날짜 표기.
    static let monthDayKo: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M월 d일"; return f
    }()
    /// "7일" — 타임라인 날짜 칸.
    static let dayKo: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "d일"; return f
    }()
    /// "11월" — 타임라인 월 경계 표기.
    static let monthKo: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M월"; return f
    }()
}

// MARK: - Kbd

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

// MARK: - LumenFooterBar
//
// 검색·번역·메모·클립보드 패널이 공유하는 하단 chrome.
// 좌측: "Lumen" 캡션. 우측: 액션 + 단축키 힌트.

struct LumenFooterAction: Identifiable {
    let id = UUID()
    let label: String
    let kbd: String
    var primary: Bool = false
}

struct LumenFooterBar: View {
    let actions: [LumenFooterAction]

    var body: some View {
        HStack(spacing: 0) {
            Text("Lumen")
                .lumenText(.caption, weight: .medium)
                .foregroundStyle(LumenTokens.Palette.inkFaint)
            Spacer()
            HStack(spacing: LumenTokens.Space.s4) {
                ForEach(actions) { action in
                    HStack(spacing: LumenTokens.Space.inline) {
                        Text(action.label)
                            .lumenText(.caption, weight: action.primary ? .medium : .regular)
                            .foregroundStyle(action.primary ? LumenTokens.Palette.ink
                                                            : LumenTokens.Palette.inkMuted)
                        LumenKbd(label: action.kbd, primary: action.primary)
                    }
                }
            }
        }
        .padding(.horizontal, LumenTokens.Space.s4)
        .frame(height: LumenTokens.Space.size(40))
        .background(LumenTokens.Palette.panelSurface)
        .overlay(alignment: .top) { LumenHairline() }
    }
}
