import SwiftUI

extension Notification.Name {
    /// PanelWindowController가 ⌘1/⌘2/⌘3을 받으면 이 알림을 0/1/2 인덱스로 post한다.
    /// JiraDashboardView가 onReceive로 잡아 activeTab을 바꾼다.
    static let jiraSwitchTab = Notification.Name("com.lumen.jira.switchTab")
}

/// 통합 Jira 패널의 상단 탭. 헤더 가운데 자리에 깔린다.
/// 활성 탭은 violet 배경 + primary text, 비활성은 muted text.
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
        case .dashboard: return "square.grid.2x2"
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
        case .week:  return "calendar.day.timeline.left"
        }
    }
}

struct JiraTabBar: View {
    @Binding var active: JiraTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(JiraTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                )
        )
    }

    private func tabButton(_ tab: JiraTab) -> some View {
        let isActive = (active == tab)
        return Button {
            active = tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 10, weight: .medium))
                Text(tab.label)
                    .font(.system(size: 11.5, weight: isActive ? .semibold : .regular))
            }
            .foregroundStyle(isActive
                             ? LumenTokens.TextColor.primary
                             : LumenTokens.TextColor.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isActive ? LumenTokens.Accent.violet.opacity(0.22) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}
