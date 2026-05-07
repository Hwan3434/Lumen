import EventKit
import Foundation
import SwiftUI

// 캘린더가 그리는 단위. 스프린트/에픽/이슈 셋을 하나의 시계열 막대로 통일한다.
// Jira 데이터 모델을 그대로 노출하면 뷰가 분기 가득해지므로 어댑터로 평탄화.
enum CalendarItemKind {
    case sprint, epic, task
    /// 사용자가 좌측 사이드바에서 직접 추가한 로컬 이벤트. 월간에서만 노출.
    case local
    /// macOS Calendar.app에 연동된 Google Calendar 이벤트.
    case googleCalendar

    var label: String {
        switch self {
        case .sprint:          return "스프린트"
        case .epic:            return "에픽"
        case .task:            return "태스크"
        case .local:           return "이벤트"
        case .googleCalendar:  return "캘린더"
        }
    }

    /// 종류를 색으로 구분한다. 셀이 좁아 레인 분리는 답답하므로 색이 1차 시그널.
    var color: Color {
        switch self {
        case .sprint:          return LumenTokens.Accent.amber
        case .epic:            return LumenTokens.Accent.violet
        case .task:            return LumenTokens.TextColor.secondary
        case .local:           return LumenTokens.TextColor.muted
        case .googleCalendar:  return LumenTokens.Accent.teal
        }
    }

    var iconName: String {
        switch self {
        case .sprint:          return "flag.fill"
        case .epic:            return "rectangle.stack.fill"
        case .task:            return "checkmark.circle"
        case .local:           return "calendar.badge.plus"
        case .googleCalendar:  return "calendar"
        }
    }
}

struct CalendarItem: Identifiable, Hashable {
    let id: String
    let kind: CalendarItemKind
    let title: String
    /// span의 시작·종료. 종료가 nil이면 단일 시점(start만 표시).
    let start: Date
    let end: Date?
    /// Jira 이슈 키 ("PROJ-123"). 클릭 시 openJira(_:)로 전달 — 거기서 URL 빌드 + 패널 닫기까지 처리.
    /// 스프린트는 클릭 동작 없음(nil).
    let issueKey: String?
    let isDone: Bool
    /// 프로젝트별 배경색을 위해 어댑터가 채워준다 — 스프린트는 SprintInfo.projectKey,
    /// 에픽/태스크는 issueKey의 prefix("PROJ-123" → "PROJ")에서 추출.
    let projectKey: String?

    /// 이 항목이 주어진 날짜에 걸쳐 있는가. start만 있으면 그 날짜만, end 있으면 [start, end] inclusive.
    func covers(_ day: Date) -> Bool {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end ?? start)
        return dayStart >= s && dayStart <= e
    }
}

enum CalendarAdapter {
    /// JiraDashboardData에서 캘린더가 쓸 항목 목록을 빌드한다.
    /// - 스프린트: startDate~endDate (둘 다 있어야)
    /// - 에픽: dueDate만 (단일 시점)
    /// - 태스크(이슈): startDate→dueDate 또는 둘 중 하나만 있어도 표시
    /// - 로컬 이벤트: includeLocal일 때만 (월간 탭 한정)
    static func buildItems(from data: JiraDashboardData, includeLocal: Bool = false) -> [CalendarItem] {
        var items: [CalendarItem] = []

        for sprint in data.sprintInfos {
            guard let s = sprint.startDate, let e = sprint.endDate else { continue }
            items.append(CalendarItem(
                id: "sprint-\(sprint.id)",
                kind: .sprint,
                title: sprint.name,
                start: s,
                end: e,
                issueKey: nil,
                isDone: false,
                projectKey: sprint.projectKey
            ))
        }

        for epic in data.epicInfos {
            guard let due = epic.dueDate else { continue }
            items.append(CalendarItem(
                id: "epic-\(epic.key)",
                kind: .epic,
                title: epic.summary,
                start: due,
                end: nil,
                issueKey: epic.key,
                isDone: false,
                projectKey: epic.projectKey
            ))
        }

        if includeLocal {
            for ev in LocalEventStore.shared.events {
                items.append(CalendarItem(
                    id: "local-\(ev.id.uuidString)",
                    kind: .local,
                    title: ev.title,
                    start: ev.start,
                    end: ev.end,
                    issueKey: nil,
                    isDone: false,
                    projectKey: nil
                ))
            }

            for ev in EventKitService.shared.events {
                guard let start = ev.startDate, let end = ev.endDate else { continue }
                let effectiveEnd = ev.isAllDay ? Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end : end
                items.append(CalendarItem(
                    id: "gcal-\(ev.eventIdentifier ?? UUID().uuidString)",
                    kind: .googleCalendar,
                    title: ev.title ?? "(제목 없음)",
                    start: start,
                    end: Calendar.current.isDate(start, inSameDayAs: effectiveEnd) ? nil : effectiveEnd,
                    issueKey: nil,
                    isDone: false,
                    projectKey: nil
                ))
            }
        }

        // ±3개월 윈도우에 들어온 모든 이슈가 단일 소스. dedup 불필요(이미 unique).
        for issue in data.allIssuesInWindow {
            let s = issue.startDate
            let d = issue.dueDate
            // 둘 다 없으면 캘린더에 띄울 근거 없음.
            guard s != nil || d != nil else { continue }
            let start = s ?? d!
            let end = (s != nil && d != nil) ? d : nil
            items.append(CalendarItem(
                id: "task-\(issue.id)",
                kind: .task,
                title: issue.summary,
                start: start,
                end: end,
                issueKey: issue.key,
                isDone: issue.isDone,
                projectKey: issue.projectKey
            ))
        }

        return items
    }
}

// MARK: - Week layout (월간/주간 공통)
//
// 한 주(7컬럼) 안에서 task들을 막대로 배치한다. 월간 그리드와 주간 뷰가 같은 알고리즘을 쓴다 —
// 차이는 maxLanes만 (월간 = 셀 좁아서 4, 주간 = 행 더 많아도 OK라 12).

struct LaidOutBar: Identifiable {
    let item: CalendarItem
    let startCol: Int   // 0...6
    let span: Int       // 1...7
    let lane: Int
    /// id에 lane을 의도적으로 뺀다 — 항목 추가/필터로 lane이 재배치돼도 SwiftUI가 view identity를
    /// 유지해 Y offset을 부드럽게 애니메이션하게 한다.
    var id: String { "\(item.id)|\(startCol)|\(span)" }
}

struct WeekLayout {
    let weekStart: Date
    let bars: [LaidOutBar]
    /// col별로 maxLanes를 넘어 잘려나간 task 갯수.
    let overflowByCol: [Int: Int]
}

/// 우선순위:
///   1) span desc — 긴 task가 위쪽 lane을 먼저 차지 ("오래가는 일이 위로")
///   2) startCol asc — 같은 길이면 시작 빠른 게 먼저
///   3) kind asc (이벤트 → 스프린트 → 에픽 → 태스크)
///   4) title asc — 안정 정렬
///
/// 같은 lane 안에서 task끼리 겹치지 않도록 greedy로 가장 위 비어있는 lane에 배치.
/// lane >= maxLanes면 그 col에 overflow 카운트.
func layoutWeek(weekStart: Date, items: [CalendarItem], maxLanes: Int) -> WeekLayout {
    let cal = Calendar.current
    let weekStartDay = cal.startOfDay(for: weekStart)
    let weekEndDay = cal.date(byAdding: .day, value: 6, to: weekStartDay)!

    struct Candidate {
        let item: CalendarItem
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
    let kindOrder: [CalendarItemKind: Int] = [.local: 0, .sprint: 1, .epic: 2, .task: 3]
    candidates.sort { a, b in
        if a.span != b.span { return a.span > b.span }
        if a.startCol != b.startCol { return a.startCol < b.startCol }
        let oa = kindOrder[a.item.kind] ?? 99
        let ob = kindOrder[b.item.kind] ?? 99
        if oa != ob { return oa < ob }
        return a.item.title < b.item.title
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
    /// 일요일 시작 기준 주의 시작일(자정).
    static func startOfWeek(of date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 1
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }

    /// ScrollViewReader id용 키 — prefix로 호출자별 ID 공간 분리.
    static func key(_ d: Date, prefix: String) -> String {
        let comp = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(prefix)-\(comp.year ?? 0)-\(comp.month ?? 0)-\(comp.day ?? 0)"
    }

    /// 요일별 색 — 일요일은 공휴일 톤보다 옅은 톤, 토요일은 violetSoft, 평일은 muted.
    static func weekdayColor(for date: Date) -> Color {
        let w = Calendar.current.component(.weekday, from: date)
        if w == 1 { return LumenTokens.CalendarTone.sunday }
        if w == 7 { return LumenTokens.Accent.violetSoft }
        return LumenTokens.TextColor.muted
    }
}

// MARK: - Filter

struct CalendarFilter: Equatable {
    var showSprint = true
    var showEpic = true
    var showTask = true
    var showGoogleCalendar = true

    func passes(_ item: CalendarItem) -> Bool {
        switch item.kind {
        case .sprint:         return showSprint
        case .epic:           return showEpic
        case .task:           return showTask
        case .local:          return true
        case .googleCalendar: return showGoogleCalendar
        }
    }
}
