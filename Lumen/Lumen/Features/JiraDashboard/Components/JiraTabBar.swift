import SwiftUI

/// 통합 Jira 패널의 상단 탭. 헤더 가운데 자리에 깔린다.
/// 활성 탭은 violet 배경 + primary text, 비활성은 muted text.
enum JiraTab: String, CaseIterable, Identifiable {
    case dashboard
    case month
    case timeline

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: return "대시보드"
        case .month:     return "월간"
        case .timeline:  return "타임라인"
        }
    }

    var iconName: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .month:     return "calendar"
        case .timeline:  return "chart.bar.xaxis"
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
