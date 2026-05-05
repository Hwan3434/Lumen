import Foundation
import SwiftUI

// 캘린더가 그리는 단위. 스프린트/에픽/이슈 셋을 하나의 시계열 막대로 통일한다.
// Jira 데이터 모델을 그대로 노출하면 뷰가 분기 가득해지므로 어댑터로 평탄화.
enum CalendarItemKind {
    case sprint, epic, task

    var label: String {
        switch self {
        case .sprint: return "스프린트"
        case .epic:   return "에픽"
        case .task:   return "태스크"
        }
    }

    /// 종류를 색으로 구분한다. 셀이 좁아 레인 분리는 답답하므로 색이 1차 시그널.
    var color: Color {
        switch self {
        case .sprint: return LumenTokens.Accent.amber
        case .epic:   return LumenTokens.Accent.violet
        case .task:   return LumenTokens.TextColor.secondary
        }
    }

    var iconName: String {
        switch self {
        case .sprint: return "flag.fill"
        case .epic:   return "rectangle.stack.fill"
        case .task:   return "checkmark.circle"
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
    /// Jira에서 열기 위한 키 — 이슈 키 ("PROJ-123") 또는 스프린트 id ("sprint-42").
    let openURL: URL?
    let isDone: Bool

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
    static func buildItems(from data: JiraDashboardData, baseURL: String?) -> [CalendarItem] {
        var items: [CalendarItem] = []

        for sprint in data.sprintInfos {
            guard let s = sprint.startDate, let e = sprint.endDate else { continue }
            items.append(CalendarItem(
                id: "sprint-\(sprint.id)",
                kind: .sprint,
                title: sprint.name,
                start: s,
                end: e,
                openURL: nil,
                isDone: false
            ))
        }

        for epic in data.epicInfos {
            guard let due = epic.dueDate else { continue }
            items.append(CalendarItem(
                id: "epic-\(epic.key)",
                kind: .epic,
                title: "\(epic.key) · \(epic.summary)",
                start: due,
                end: nil,
                openURL: issueURL(key: epic.key, baseURL: baseURL),
                isDone: false
            ))
        }

        var seenIssueIDs = Set<String>()
        for issue in allIssues(data) where !seenIssueIDs.contains(issue.id) {
            seenIssueIDs.insert(issue.id)
            let s = issue.startDate
            let d = issue.dueDate
            // 둘 다 없으면 캘린더에 띄울 근거 없음.
            guard s != nil || d != nil else { continue }
            let start = s ?? d!
            let end = (s != nil && d != nil) ? d : nil
            items.append(CalendarItem(
                id: "task-\(issue.id)",
                kind: .task,
                title: "\(issue.key) · \(issue.summary)",
                start: start,
                end: end,
                openURL: issueURL(key: issue.key, baseURL: baseURL),
                isDone: issue.isDone
            ))
        }

        return items
    }

    private static func allIssues(_ data: JiraDashboardData) -> [JiraIssue] {
        data.todayIssues + data.thisWeekIssues + data.nextWeekIssues
            + data.overdueIncomplete + data.highestIncomplete
            + data.completedLast30 + data.createdLast30
    }

    private static func issueURL(key: String, baseURL: String?) -> URL? {
        guard let baseURL else { return nil }
        let trimmed = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        return URL(string: "\(trimmed)/browse/\(key)")
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
        }
    }
}
