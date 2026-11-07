import Foundation

// 대한민국 공휴일 — 정적 하드코딩. 일정이 아니라 달력 날짜를 빨갛게 칠하는 데만 쓴다.
// 양력 고정 공휴일은 코드에서 자동 생성, 음력 기반(설/추석/석가탄신일)·대체공휴일·선거일은
// 연도별로 채운다. 2028년까지 들어 있으니 그 전에 다음 해를 더한다.

enum KoreanHolidays {
    /// 어느 날짜가 공휴일이면 이름 반환, 아니면 nil.
    static func name(for date: Date) -> String? {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        return holidayMap[day]
    }

    // MARK: - Build map

    private static let holidayMap: [Date: String] = build()

    private static func build() -> [Date: String] {
        var result: [Date: String] = [:]
        for year in 2026...2028 {
            addFixed(year: year, into: &result)
        }
        add2026(into: &result)
        add2027(into: &result)
        add2028(into: &result)
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

    /// 매년 양력 날짜가 바뀌는 공휴일과 대체공휴일·선거일.
    /// (출처: 행정안전부 2026년 관공서 공휴일.)
    private static func add2026(into dict: inout [Date: String]) {
        put(2026, 2, 16, "설날 연휴", &dict)
        put(2026, 2, 17, "설날", &dict)
        put(2026, 2, 18, "설날 연휴", &dict)
        put(2026, 3, 2, "삼일절 대체공휴일", &dict)         // 3/1 일요일
        put(2026, 5, 24, "부처님 오신 날", &dict)
        put(2026, 5, 25, "부처님 오신 날 대체공휴일", &dict)  // 일요일
        put(2026, 6, 3, "지방선거", &dict)
        put(2026, 8, 17, "광복절 대체공휴일", &dict)        // 8/15 토요일
        put(2026, 9, 24, "추석 연휴", &dict)
        put(2026, 9, 25, "추석", &dict)
        put(2026, 9, 26, "추석 연휴", &dict)
        put(2026, 10, 5, "개천절 대체공휴일", &dict)        // 10/3 토요일
    }

    /// 공식 발표 전이라 음력 날짜와 대체공휴일 규칙으로 계산했다. 발표되면 맞춰 본다.
    private static func add2027(into dict: inout [Date: String]) {
        put(2027, 2, 6, "설날 연휴", &dict)
        put(2027, 2, 7, "설날", &dict)
        put(2027, 2, 8, "설날 연휴", &dict)
        put(2027, 2, 9, "설날 대체공휴일", &dict)          // 설날 일요일
        put(2027, 5, 13, "부처님 오신 날", &dict)
        put(2027, 8, 16, "광복절 대체공휴일", &dict)        // 8/15 일요일
        put(2027, 9, 14, "추석 연휴", &dict)
        put(2027, 9, 15, "추석", &dict)
        put(2027, 9, 16, "추석 연휴", &dict)
        put(2027, 10, 4, "개천절 대체공휴일", &dict)        // 10/3 일요일
        put(2027, 10, 11, "한글날 대체공휴일", &dict)       // 10/9 토요일
        put(2027, 12, 27, "크리스마스 대체공휴일", &dict)    // 12/25 토요일
    }

    /// 공식 발표 전이라 음력 날짜와 대체공휴일 규칙으로 계산했다. 발표되면 맞춰 본다.
    private static func add2028(into dict: inout [Date: String]) {
        put(2028, 1, 25, "설날 연휴", &dict)
        put(2028, 1, 26, "설날", &dict)
        put(2028, 1, 27, "설날 연휴", &dict)
        put(2028, 4, 12, "국회의원 선거", &dict)
        put(2028, 5, 2, "부처님 오신 날", &dict)
        put(2028, 10, 2, "추석 연휴", &dict)
        put(2028, 10, 3, "추석", &dict)                   // 개천절과 겹침
        put(2028, 10, 4, "추석 연휴", &dict)
        put(2028, 10, 5, "개천절 대체공휴일", &dict)
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
