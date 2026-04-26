import SwiftUI

struct PresentColumn: View {
    let data: JiraDashboardData
    @Binding var selectedProject: String

    static let allKey = "ALL"

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    LumenSectionLabel(text: "이번 주")
                    Spacer()
                    ProjectTabBar(selected: $selectedProject)
                }

                StatusGrid(counts: counts)

                IssueListSection(
                    icon: "calendar.badge.exclamationmark",
                    iconColor: LumenTokens.Accent.amber,
                    title: "오늘 마감",
                    items: filterByProject(data.todayIssues),
                    emptyText: "오늘 마감 일감 없음",
                    hideWhenEmpty: true
                )

                IssueListSection(
                    icon: "list.bullet",
                    iconColor: LumenTokens.TextColor.secondary,
                    title: "이번 주 전체",
                    items: filterByProject(data.thisWeekIssues),
                    emptyText: "이번 주 일감 없음"
                )

                IssueListSection(
                    icon: "exclamationmark.triangle",
                    iconColor: LumenTokens.ErrorTone.icon,
                    title: "기한 초과",
                    items: filterByProject(data.overdueIncomplete),
                    emptyText: "기한 초과 없음",
                    hideWhenEmpty: true
                )
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16))
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.012))
    }

    private var counts: JiraStatusCounts {
        if selectedProject == Self.allKey { return data.thisWeekCounts }
        return data.projectStats.first { $0.key == selectedProject }?.counts ?? JiraStatusCounts()
    }

    private func filterByProject(_ issues: [JiraIssue]) -> [JiraIssue] {
        selectedProject == Self.allKey ? issues : issues.filter { $0.projectKey == selectedProject }
    }
}

struct ProjectTabBar: View {
    @Binding var selected: String

    var body: some View {
        HStack(spacing: 4) {
            tab(key: PresentColumn.allKey, color: LumenTokens.TextColor.secondary, label: "ALL", index: 1)
            ForEach(Array(Constants.jiraProjects.enumerated()), id: \.offset) { i, proj in
                tab(key: proj.key, color: proj.color, label: proj.displayName, index: i + 2)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.18))
                .overlay(Capsule().stroke(LumenTokens.stroke, lineWidth: 0.5))
        )
    }

    private func tab(key: String, color: Color, label: String, index: Int) -> some View {
        let active = selected == key
        let bg: Color = active
            ? (key == PresentColumn.allKey ? Color.white.opacity(0.06) : color.opacity(0.10))
            : .clear
        let stroke: Color = active
            ? (key == PresentColumn.allKey ? LumenTokens.strokeStrong : color.opacity(0.33))
            : .clear
        let fg: Color = active
            ? (key == PresentColumn.allKey ? LumenTokens.TextColor.primary : color)
            : LumenTokens.TextColor.muted

        return Button {
            selected = key
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11.5, weight: active ? .semibold : .medium))
                    .lineLimit(1)
                Text("⌘\(index)")
                    .font(.system(size: 9, design: .monospaced))
                    .padding(.horizontal, 3)
                    .frame(minWidth: 13, minHeight: 13)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(LumenTokens.stroke, lineWidth: 0.5)
                    )
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(
                Capsule()
                    .fill(bg)
                    .overlay(Capsule().stroke(stroke, lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
    }
}

struct StatusCellData {
    let key: JiraStatusKey
    let label: String
    let icon: String
    let count: Int
}

struct StatusGrid: View {
    let counts: JiraStatusCounts

    private var cells: [StatusCellData] {
        [
            .init(key: .todo,       label: "해야 할 일", icon: "circle.dashed",     count: counts.todo),
            .init(key: .inProgress, label: "진행중",     icon: "play.circle",       count: counts.inProgress),
            .init(key: .onHold,     label: "보류",       icon: "pause.circle",      count: counts.onHold),
            .init(key: .waiting,    label: "대기",       icon: "hourglass",         count: counts.waiting),
            .init(key: .completed,  label: "완료",       icon: "checkmark.circle",  count: counts.completed),
            .init(key: .cancelled,  label: "취소",       icon: "xmark.circle",      count: counts.cancelled),
        ]
    }

    var body: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 8) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                StatusCard(cell: cell)
            }
        }
    }
}

struct StatusCard: View {
    let cell: StatusCellData

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: cell.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(cell.key.fg)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.20))
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(cell.label.uppercased())
                    .font(.system(size: 10.5, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(cell.key.fg)
                Text("\(cell.count)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.primary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cell.key.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cell.key.fg.opacity(0.20), lineWidth: 0.5)
                )
        )
    }
}
