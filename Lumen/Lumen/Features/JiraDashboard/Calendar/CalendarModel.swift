import Foundation
import SwiftUI

// 캘린더가 그리는 단위. 스프린트/에픽/이슈 셋을 하나의 시계열 막대로 통일한다.
// Jira 데이터 모델을 그대로 노출하면 뷰가 분기 가득해지므로 어댑터로 평탄화.
enum CalendarItemKind {
    case sprint, epic, task
    /// 사용자가 좌측 사이드바에서 직접 추가한 로컬 이벤트. 월간에서만 노출.
    case local

    var label: String {
        switch self {
        case .sprint: return "스프린트"
        case .epic:   return "에픽"
        case .task:   return "태스크"
        case .local:  return "이벤트"
        }
    }

    /// 종류를 색으로 구분한다. 셀이 좁아 레인 분리는 답답하므로 색이 1차 시그널.
    var color: Color {
        switch self {
        case .sprint: return LumenTokens.Accent.amber
        case .epic:   return LumenTokens.Accent.violet
        case .task:   return LumenTokens.TextColor.secondary
        case .local:  return LumenTokens.TextColor.muted
        }
    }

    var iconName: String {
        switch self {
        case .sprint: return "flag.fill"
        case .epic:   return "rectangle.stack.fill"
        case .task:   return "checkmark.circle"
        case .local:  return "calendar.badge.plus"
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

// MARK: - Filter

struct CalendarFilter: Equatable {
    var showSprint = true
    var showEpic = true
    var showTask = true

    func passes(_ item: CalendarItem) -> Bool {
        switch item.kind {
        case .sprint: return showSprint
        case .epic:   return showEpic
        case .task:   return showTask
        case .local:  return true   // 로컬 이벤트는 사이드바로 따로 관리되니 필터에서 빼지 않는다.
        }
    }
}
