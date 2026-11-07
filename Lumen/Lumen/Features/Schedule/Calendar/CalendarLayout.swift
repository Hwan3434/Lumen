import SwiftUI

// 월간·주간이 함께 쓰는 정렬, 레인 배치, 날짜 도우미. 출처(플러그인)와 무관하다.

nonisolated enum CalendarItemSort {
    /// 캘린더 전역 기본 표시 순서.
    /// 시간 있는 일정은 같은 날짜 안에서 시작 시각순으로 배치하고, 종일·기간 항목은 그 뒤에 안정적으로 둔다.
    static func ordered(_ items: [ScheduleItem]) -> [ScheduleItem] {
        items.sorted(by: areInDisplayOrder)
    }

    static func areInDisplayOrder(_ lhs: ScheduleItem, _ rhs: ScheduleItem) -> Bool {
        let cal = Calendar.current
        let lhsDay = cal.startOfDay(for: lhs.start)
        let rhsDay = cal.startOfDay(for: rhs.start)
        if lhsDay != rhsDay { return lhsDay < rhsDay }

        if lhs.hasTimeOfDay != rhs.hasTimeOfDay { return lhs.hasTimeOfDay }
        if lhs.hasTimeOfDay, lhs.start != rhs.start { return lhs.start < rhs.start }

        let lhsEnd = lhs.end ?? lhs.start
        let rhsEnd = rhs.end ?? rhs.start
        if lhsEnd != rhsEnd { return lhsEnd < rhsEnd }

        let lhsKind = kindOrder(lhs.kind)
        let rhsKind = kindOrder(rhs.kind)
        if lhsKind != rhsKind { return lhsKind < rhsKind }

        let titleOrder = lhs.title.localizedStandardCompare(rhs.title)
        if titleOrder != .orderedSame { return titleOrder == .orderedAscending }

        return lhs.id < rhs.id
    }

    private static func kindOrder(_ kind: ScheduleItem.Kind) -> Int {
        switch kind {
        case .event: return 0
        case .span:  return 1
        case .task:  return 2
        }
    }
}

// MARK: - Week layout (월간/주간 공통)
//
// 한 주(7컬럼) 안에서 항목들을 막대로 배치한다. 월간 그리드와 주간 뷰가 같은 알고리즘을 쓴다 —
// 차이는 maxLanes만 (월간 = 셀 좁아서 4, 주간 = 제한 없음).

nonisolated struct LaidOutBar: Identifiable {
    let item: ScheduleItem
    let startCol: Int   // 0...6
    let span: Int       // 1...7
    let lane: Int
    /// id에 lane을 의도적으로 뺀다 — 항목 추가/필터로 lane이 재배치돼도 SwiftUI가 view identity를
    /// 유지해 Y offset을 부드럽게 애니메이션하게 한다.
    var id: String {
        let startKey = item.start.timeIntervalSinceReferenceDate.bitPattern
        let endKey = item.end?.timeIntervalSinceReferenceDate.bitPattern.description ?? "nil"
        return "\(item.id)|\(startKey)|\(endKey)|\(startCol)|\(span)"
    }
}

nonisolated struct WeekLayout {
    let weekStart: Date
    let bars: [LaidOutBar]
    /// col별로 maxLanes를 넘어 잘려나간 항목 갯수.
    let overflowByCol: [Int: Int]
}

/// 같은 lane 안에서 항목끼리 겹치지 않도록 greedy로 가장 위 비어있는 lane에 배치.
/// lane >= maxLanes면 그 col에 overflow 카운트.
nonisolated func layoutWeek(weekStart: Date, items: [ScheduleItem], maxLanes: Int) -> WeekLayout {
    let cal = Calendar.current
    let weekStartDay = cal.startOfDay(for: weekStart)
    let weekEndDay = cal.date(byAdding: .day, value: 6, to: weekStartDay)!

    struct Candidate {
        let item: ScheduleItem
        let startCol: Int
        let span: Int
    }
    var candidates: [Candidate] = []
    for item in items {
        let s = cal.startOfDay(for: item.start)
        let e = cal.startOfDay(for: item.end ?? item.start)
        if e < weekStartDay || s > weekEndDay { continue }
        let clampedStart = max(s, weekStartDay)
        let clampedEnd = min(e, weekEndDay)
        let startCol = (cal.dateComponents([.day], from: weekStartDay, to: clampedStart).day ?? 0)
        let endCol = (cal.dateComponents([.day], from: weekStartDay, to: clampedEnd).day ?? 0)
        let span = max(1, endCol - startCol + 1)
        candidates.append(Candidate(item: item, startCol: startCol, span: span))
    }
    candidates.sort { a, b in
        if a.startCol != b.startCol { return a.startCol < b.startCol }
        return CalendarItemSort.areInDisplayOrder(a.item, b.item)
    }

    var lanes: [[Bool]] = []
    var bars: [LaidOutBar] = []
    var overflowByCol: [Int: Int] = [:]
    for c in candidates {
        var assigned: Int? = nil
        for laneIdx in 0..<lanes.count {
            var fits = true
            for col in c.startCol..<(c.startCol + c.span) {
                if lanes[laneIdx][col] { fits = false; break }
            }
            if fits { assigned = laneIdx; break }
        }
        let lane = assigned ?? lanes.count
        if assigned == nil { lanes.append(Array(repeating: false, count: 7)) }
        for col in c.startCol..<(c.startCol + c.span) {
            lanes[lane][col] = true
        }
        if lane < maxLanes {
            bars.append(LaidOutBar(item: c.item, startCol: c.startCol, span: c.span, lane: lane))
        } else {
            for col in c.startCol..<(c.startCol + c.span) {
                overflowByCol[col, default: 0] += 1
            }
        }
    }
    return WeekLayout(weekStart: weekStart, bars: bars, overflowByCol: overflowByCol)
}

// MARK: - Shared date helpers (월간/주간 공통)

enum CalendarDateUtils {
    /// 주의 시작일(자정). `firstWeekday`는 `Calendar.firstWeekday` 값(일요일 1, 월요일 2).
    nonisolated static func startOfWeek(of date: Date, firstWeekday: Int) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = firstWeekday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }

    /// ScrollViewReader id용 키 — prefix로 호출자별 ID 공간 분리.
    nonisolated static func key(_ d: Date, prefix: String) -> String {
        let comp = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(prefix)-\(comp.year ?? 0)-\(comp.month ?? 0)-\(comp.day ?? 0)"
    }

    /// 요일 글자 7개를 주 시작 요일부터 돌려 놓는다.
    nonisolated static func weekdaySymbols(firstWeekday: Int) -> [String] {
        let base = ["일", "월", "화", "수", "목", "금", "토"]
        let shift = (firstWeekday - 1) % 7
        return Array(base[shift...] + base[..<shift])
    }

    /// 요일별 색 — 토·일요일 `danger`, 평일 `ink-muted`.
    static func weekdayColor(for date: Date) -> Color {
        weekdayColor(weekday: Calendar.current.component(.weekday, from: date))
    }

    static func weekdayColor(weekday: Int) -> Color {
        if weekday == 1 || weekday == 7 { return LumenTokens.Palette.danger }
        return LumenTokens.Palette.inkMuted
    }

    /// 날짜 숫자를 빨갛게 칠할 날 — 토·일요일과 공휴일.
    static func isRedDay(_ date: Date) -> Bool {
        Calendar.current.isDateInWeekend(date) || KoreanHolidays.name(for: date) != nil
    }
}
