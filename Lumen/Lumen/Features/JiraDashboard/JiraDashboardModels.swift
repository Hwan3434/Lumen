import SwiftUI

/// Jira service가 한국어 status string으로 보내주는 값을 디자인 시스템 컬러
/// 토큰으로 매핑하는 단일 게이트웨이.
enum JiraStatusKey {
    case todo, inProgress, onHold, waiting, completed, cancelled

    init(_ status: String) {
        switch status {
        case "완료":   self = .completed
        case "진행중": self = .inProgress
        case "보류":   self = .onHold
        case "대기":   self = .waiting
        case "취소":   self = .cancelled
        default:       self = .todo
        }
    }

    var label: String {
        switch self {
        case .todo: return "할 일"
        case .inProgress: return "진행중"
        case .onHold: return "보류"
        case .waiting: return "대기"
        case .completed: return "완료"
        case .cancelled: return "취소"
        }
    }

    var fg: Color {
        switch self {
        case .todo:       return LumenTokens.JiraStatusTone.todoFg
        case .inProgress: return LumenTokens.JiraStatusTone.inProgressFg
        case .onHold:     return LumenTokens.JiraStatusTone.onHoldFg
        case .waiting:    return LumenTokens.JiraStatusTone.waitingFg
        case .completed:  return LumenTokens.JiraStatusTone.completedFg
        case .cancelled:  return LumenTokens.JiraStatusTone.cancelledFg
        }
    }

    var bg: Color {
        switch self {
        case .todo:       return LumenTokens.JiraStatusTone.todoBg
        case .inProgress: return LumenTokens.JiraStatusTone.inProgressBg
        case .onHold:     return LumenTokens.JiraStatusTone.onHoldBg
        case .waiting:    return LumenTokens.JiraStatusTone.waitingBg
        case .completed:  return LumenTokens.JiraStatusTone.completedBg
        case .cancelled:  return LumenTokens.JiraStatusTone.cancelledBg
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
    if let url = URL(string: Constants.jiraBrowseURL + key) {
        NSWorkspace.shared.open(url)
        if let panel = NSApp.keyWindow as? KeyablePanel {
            panel.activatePreviousAppOnClose = false
            panel.orderOut(nil)
        }
    }
}
