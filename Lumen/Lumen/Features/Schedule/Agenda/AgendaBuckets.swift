import Foundation

/// 일정 목록 열의 날짜 묶음. 목록에 나오는 순서와 같다.
nonisolated enum AgendaBucket: String, CaseIterable, Identifiable {
    case overdue, today, tomorrow, thisWeek, nextWeek, later

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overdue:  return "지난 기한"
        case .today:    return "오늘"
        case .tomorrow: return "내일"
        case .thisWeek: return "이번 주"
        case .nextWeek: return "다음 주"
        case .later:    return "그 이후"
        }
    }

    var iconName: String {
        switch self {
        case .overdue:  return "triangle-alert"
        case .today:    return "calendar-check"
        case .tomorrow: return "calendar"
        case .thisWeek, .nextWeek: return "calendar-range"
        case .later:    return "calendar"
        }
    }
}

nonisolated struct AgendaSection: Identifiable {
    let bucket: AgendaBucket
    let items: [ScheduleItem]
    var id: String { bucket.id }
}

/// 보이는 항목을 날짜 묶음으로 나눈다. 네트워크·뷰와 분리된 순수 함수라 경계 규칙을 테스트로 고정한다.
///
/// - 기간 항목(스프린트)은 매일 반복돼 소음이므로 넣지 않는다.
/// - 할 일(마감형)은 마감일로 묶는다. 마감이 지났는데 완료하지 않았으면 "지난 기한", 완료했으면 뺀다.
/// - 일정(이벤트)은 오늘 이후로 처음 걸치는 날로 묶는다. 이미 끝난 일정은 뺀다.
/// - 앞으로의 일은 오늘부터 한 달 뒤 같은 날까지만 넣는다. 지난 기한은 이 제한을 받지 않는다.
nonisolated enum AgendaBuckets {
    static func sections(items: [ScheduleItem], now: Date, firstWeekday: Int) -> [AgendaSection] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        let dayAfter = cal.date(byAdding: .day, value: 2, to: today)!
        let weekStart = CalendarDateUtils.startOfWeek(of: today, firstWeekday: firstWeekday)
        let nextWeekStart = cal.date(byAdding: .day, value: 7, to: weekStart)!
        let laterStart = cal.date(byAdding: .day, value: 14, to: weekStart)!
        let horizon = cal.date(byAdding: .month, value: 1, to: today)!

        var grouped: [AgendaBucket: [ScheduleItem]] = [:]
        for item in items where item.kind != .span {
            let bucket: AgendaBucket?
            switch item.kind {
            case .task:
                let due = item.lastDay
                if due < today {
                    bucket = item.isDone ? nil : .overdue
                } else if due > horizon {
                    bucket = nil
                } else {
                    bucket = dayBucket(due, today: today, tomorrow: tomorrow, dayAfter: dayAfter,
                                       nextWeekStart: nextWeekStart, laterStart: laterStart)
                }
            case .event, .span:
                let ended = item.hasTimeOfDay
                    ? (item.end ?? item.start) <= now
                    : item.lastDay < today
                let firstDay = max(cal.startOfDay(for: item.start), today)
                if ended || firstDay > horizon {
                    bucket = nil
                } else {
                    bucket = dayBucket(firstDay, today: today, tomorrow: tomorrow, dayAfter: dayAfter,
                                       nextWeekStart: nextWeekStart, laterStart: laterStart)
                }
            }
            if let bucket { grouped[bucket, default: []].append(item) }
        }

        return AgendaBucket.allCases.compactMap { bucket in
            guard let items = grouped[bucket], !items.isEmpty else { return nil }
            let ordered = bucket == .overdue
                ? items.sorted { ($0.end ?? $0.start) < ($1.end ?? $1.start) }
                : items.sorted { listOrder($0, $1, today: today) }
            return AgendaSection(bucket: bucket, items: ordered)
        }
    }

    /// 묶음 안의 순서: 목록에 들어온 날(일정은 오늘 이후 첫날, 할 일은 마감일) → 시간 일정 먼저, 시작 시각순 → 제목.
    /// 며칠 전에 시작한 종일 일정이 오늘의 시간 일정보다 앞서지 않도록 시작일 대신 들어온 날로 비교한다.
    private static func listOrder(_ lhs: ScheduleItem, _ rhs: ScheduleItem, today: Date) -> Bool {
        let cal = Calendar.current
        func listDay(_ item: ScheduleItem) -> Date {
            item.kind == .task
                ? item.lastDay
                : max(cal.startOfDay(for: item.start), today)
        }
        let lDay = listDay(lhs), rDay = listDay(rhs)
        if lDay != rDay { return lDay < rDay }
        if lhs.hasTimeOfDay != rhs.hasTimeOfDay { return lhs.hasTimeOfDay }
        if lhs.hasTimeOfDay, lhs.start != rhs.start { return lhs.start < rhs.start }
        let titleOrder = lhs.title.localizedStandardCompare(rhs.title)
        if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
        return lhs.id < rhs.id
    }

    private static func dayBucket(_ day: Date, today: Date, tomorrow: Date, dayAfter: Date,
                                  nextWeekStart: Date, laterStart: Date) -> AgendaBucket {
        if day < tomorrow { return .today }
        if day < dayAfter { return .tomorrow }
        if day < nextWeekStart { return .thisWeek }
        if day < laterStart { return .nextWeek }
        return .later
    }
}
