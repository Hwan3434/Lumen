import SwiftUI

/// JiraStatusCategory(데이터 분류) → 디자인 토큰(fg/bg) 매핑.
/// UI에서 직접 categoryKey 문자열을 쓰지 않도록 이 한 곳에서 색을 결정한다.
enum JiraStatusKey {
    case todo, inProgress, done, undefined

    init(_ category: JiraStatusCategory) {
        switch category {
        case .new:           self = .todo
        case .indeterminate: self = .inProgress
        case .done:          self = .done
        case .undefined:     self = .undefined
        }
    }

    var fg: Color {
        switch self {
        case .todo, .undefined: return LumenTokens.JiraStatusTone.todoFg
        case .inProgress:       return LumenTokens.JiraStatusTone.inProgressFg
        case .done:             return LumenTokens.JiraStatusTone.completedFg
        }
    }

    var bg: Color {
        switch self {
        case .todo, .undefined: return LumenTokens.JiraStatusTone.todoBg
        case .inProgress:       return LumenTokens.JiraStatusTone.inProgressBg
        case .done:             return LumenTokens.JiraStatusTone.completedBg
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
