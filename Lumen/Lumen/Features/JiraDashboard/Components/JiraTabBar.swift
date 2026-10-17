import SwiftUI

extension Notification.Name {
    /// PanelWindowController가 ⌘1/⌘2/⌘3을 받으면 이 알림을 0/1/2 인덱스로 post한다.
    /// JiraDashboardView가 onReceive로 잡아 activeTab을 바꾼다.
    static let jiraSwitchTab = Notification.Name("com.lumen.jira.switchTab")
}

/// 통합 Jira 패널의 상단 탭. 헤더 가운데 자리에 깔린다.
/// Still SegmentedControl 모양.
enum JiraTab: String, CaseIterable, Identifiable {
    case dashboard
    case calendar   // 월간/주간을 모두 포함 — 모드는 CalendarMode로 별도 관리.

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: return "대시보드"
        case .calendar:  return "캘린더"
        }
    }

    var iconName: String {
        switch self {
        case .dashboard: return "layout-grid"
        case .calendar:  return "calendar"
        }
    }
}

/// 캘린더 탭 안의 두 모드. 헤더 우측 토글로 전환.
enum CalendarMode: String, CaseIterable, Identifiable {
    case month, week
    var id: String { rawValue }
    var label: String {
        switch self {
        case .month: return "월간"
        case .week:  return "주간"
        }
    }
    var iconName: String {
        switch self {
        case .month: return "calendar"
        case .week:  return "calendar-range"
        }
    }
}

struct JiraTabBar: View {
    @Binding var active: JiraTab

    var body: some View {
        LumenSegmentedControl(
            items: JiraTab.allCases.map { .init(value: $0, label: $0.label, icon: $0.iconName) },
            selection: $active
        )
    }
}
