import Foundation

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
