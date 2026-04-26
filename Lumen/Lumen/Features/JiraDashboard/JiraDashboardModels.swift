import SwiftUI

/// Atlassian의 표준 statusCategory(언어/워크스페이스 무관 식별자)로 분류.
/// `new`/`indeterminate`/`done`/`undefined` 4종 — workspace가 어떤 status 이름을 쓰든
/// 이 카테고리로만 분기한다. 사용자가 보는 라벨은 issue.status 원문을 그대로 표시한다.
enum JiraStatusKey {
    case todo, inProgress, done, undefined

    init(categoryKey: String) {
        switch categoryKey {
        case "new":            self = .todo
        case "indeterminate":  self = .inProgress
        case "done":           self = .done
        default:               self = .undefined
        }
    }

    var fg: Color {
        switch self {
        case .todo:       return LumenTokens.JiraStatusTone.todoFg
        case .inProgress: return LumenTokens.JiraStatusTone.inProgressFg
        case .done:       return LumenTokens.JiraStatusTone.completedFg
        case .undefined:  return LumenTokens.JiraStatusTone.todoFg
        }
    }

    var bg: Color {
        switch self {
        case .todo:       return LumenTokens.JiraStatusTone.todoBg
        case .inProgress: return LumenTokens.JiraStatusTone.inProgressBg
        case .done:       return LumenTokens.JiraStatusTone.completedBg
        case .undefined:  return LumenTokens.JiraStatusTone.todoBg
        }
    }
}

func jiraPriorityColor(_ priority: String) -> Color {
    switch priority {
    case "Highest": return LumenTokens.JiraPriorityTone.highest
    case "High":    return LumenTokens.JiraPriorityTone.high
    case "Low":     return LumenTokens.JiraPriorityTone.low
    case "Lowest":  return LumenTokens.JiraPriorityTone.lowest
    default:        return LumenTokens.JiraPriorityTone.medium
    }
}

enum JiraDueTone {
    case past, today, future, done

    var color: Color {
        switch self {
        case .past:   return LumenTokens.ErrorTone.icon
        case .today:  return LumenTokens.Accent.amber
        case .future: return LumenTokens.TextColor.muted
        case .done:   return LumenTokens.TextColor.muted.opacity(0.55)
        }
    }
}

func jiraDueTone(_ date: Date, isDone: Bool) -> JiraDueTone {
    if isDone { return .done }
    if date < Date() { return .past }
    if Calendar.current.isDateInToday(date) { return .today }
    return .future
}

func jiraProjectColor(_ key: String) -> Color {
    Constants.jiraProjects.first { $0.key == key }?.color ?? LumenTokens.Accent.violetSoft
}

func jiraProjectDisplayName(_ key: String) -> String {
    Constants.jiraProjects.first { $0.key == key }?.displayName ?? key
}

/// 행 클릭 시 jira 웹사이트 열고 패널 닫기. ProjectKey 기반 deep link.
func openJira(_ key: String) {
    let prefix = Constants.jiraBrowseURL
    guard !prefix.isEmpty, let url = URL(string: prefix + key) else { return }
    NSWorkspace.shared.open(url)
    if let panel = NSApp.keyWindow as? KeyablePanel {
        panel.activatePreviousAppOnClose = false
        panel.orderOut(nil)
    }
}
