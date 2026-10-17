import SwiftUI

/// 대시보드 탭 전환용 라우트 정의 (단축키 1, 2, 3 매핑)
enum JiraRoute: Int {
    case dashboard = 0
    case calendarMonth = 1
    case calendarWeek = 2
}

/// JiraStatusCategory(데이터 분류) → Still 상태 톤 매핑.
/// UI에서 직접 categoryKey 문자열을 쓰지 않도록 이 한 곳에서 톤을 결정한다.
/// 할 일 = 분류(무채색), 진행 중 = info, 완료 = success. 상태에 brand는 쓰지 않는다.
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

    var tone: LumenTone {
        switch self {
        case .todo, .undefined: return .category
        case .inProgress:       return .info
        case .done:             return .success
        }
    }

    /// 상태는 색만으로 구분하지 않도록 아이콘을 함께 붙인다.
    var icon: String {
        switch self {
        case .todo, .undefined: return "circle-dashed"
        case .inProgress:       return "circle-play"
        case .done:             return "circle-check"
        }
    }

    var fg: Color { tone.color }
    var bg: Color { tone.soft }
}

/// 우선순위 → 상태 톤. 높음 계열은 danger/warning, 낮음 계열은 무채색.
func jiraPriorityTone(_ priority: String) -> LumenTone? {
    switch priority {
    case "Highest": return .danger
    case "High":    return .warning
    default:        return nil
    }
}

enum JiraDueTone {
    case past, today, future, done

    var color: Color {
        switch self {
        case .past:   return LumenTokens.Palette.danger
        case .today:  return LumenTokens.Palette.warning
        case .future: return LumenTokens.Palette.inkMuted
        case .done:   return LumenTokens.Palette.inkFaint
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
    Constants.jiraProjects.first { $0.key == key }?.color ?? LumenTokens.Palette.chartOther
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
