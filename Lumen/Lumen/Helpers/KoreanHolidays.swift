import Foundation

// 대한민국 공휴일 — 정적 하드코딩.
// 양력 고정 공휴일은 코드에서 자동 생성, 음력 기반(설/추석/석가탄신일)과 대체공휴일은
// 연도별로 채운다. 매년 1월쯤 다음 해 데이터 추가 필요.

struct KoreanHoliday: Hashable {
    let date: Date  // 자정 기준
    let name: String
}

enum KoreanHolidays {
    /// 어느 날짜가 공휴일이면 이름 반환, 아니면 nil.
    static func name(for date: Date) -> String? {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        return holidayMap[day]
    }

    static func isHoliday(_ date: Date) -> Bool {
        name(for: date) != nil
    }

    // MARK: - Build map

    private static let holidayMap: [Date: String] = build()

    private static func build() -> [Date: String] {
        var result: [Date: String] = [:]
        // 현재 ±3M 윈도우는 ~2026 한 해 안에 들어가므로 2026 + 2027 1분기까지 채워둔다.
        // 2027 데이터는 매년 갱신 시 확장.
        addFixed(year: 2026, into: &result)
        addLunar2026(into: &result)
        addFixed(year: 2027, into: &result)
        addLunar2027Q1(into: &result)
        return result
    }

    /// 매년 같은 날짜인 공휴일 — 양력 고정.
    private static func addFixed(year: Int, into dict: inout [Date: String]) {
        let entries: [(month: Int, day: Int, name: String)] = [
            (1, 1,  "신정"),
            (3, 1,  "삼일절"),
            (5, 1,  "근로자의 날"),  // 2026년부터 법정 공휴일로 격상
            (5, 5,  "어린이날"),
            (6, 6,  "현충일"),
            (8, 15, "광복절"),
            (10, 3, "개천절"),
            (10, 9, "한글날"),
            (12, 25, "크리스마스"),
        ]
        for e in entries {
            if let d = makeDate(year: year, month: e.month, day: e.day) {
                dict[d] = e.name
            }
        }
    }

    /// 음력 기반 공휴일은 매년 양력 날짜 다름 — 연도별로 직접 박는다.
    /// (출처: 행정안전부 2026년 관공서 공휴일.)
    private static func addLunar2026(into dict: inout [Date: String]) {
        // 설날 연휴 (2026)
        put(2026, 2, 16, "설날 연휴", &dict)
        put(2026, 2, 17, "설날", &dict)
        put(2026, 2, 18, "설날 연휴", &dict)
        // 부처님 오신 날
        put(2026, 5, 24, "부처님 오신 날", &dict)
        put(2026, 5, 25, "부처님 오신 날 대체공휴일", &dict)  // 일요일 대체
        // 어린이날 대체 — 2026/5/5는 화요일이라 대체 없음. (그대로 두기)
        // 추석 연휴 (2026)
        put(2026, 9, 24, "추석 연휴", &dict)
        put(2026, 9, 25, "추석", &dict)
        put(2026, 9, 26, "추석 연휴", &dict)
        // 한글날 대체 — 2026/10/9는 금요일이라 대체 없음.
        // 크리스마스 대체 — 2026/12/25는 금요일이라 대체 없음.
    }

    private static func addLunar2027Q1(into dict: inout [Date: String]) {
        // 설날 (2027)
        put(2027, 2, 6, "설날 연휴", &dict)
        put(2027, 2, 7, "설날", &dict)
        put(2027, 2, 8, "설날 연휴", &dict)
    }

    // MARK: - Helpers

    private static func makeDate(year: Int, month: Int, day: Int) -> Date? {
        let cal = Calendar.current
        return cal.date(from: DateComponents(year: year, month: month, day: day))
    }

    private static func put(_ year: Int, _ month: Int, _ day: Int, _ name: String, _ dict: inout [Date: String]) {
        if let d = makeDate(year: year, month: month, day: day) {
            dict[d] = name
        }
    }
}
