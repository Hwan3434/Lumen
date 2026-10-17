import SwiftUI

private typealias P = LumenTokens.Palette

struct PresentColumn: View {
    let data: JiraDashboardData
    @Binding var selectedProject: String

    static let allKey = "ALL"

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: LumenTokens.Space.group) {
                HStack {
                    LumenSectionLabel(text: "이번 주")
                    Spacer()
                    ProjectTabBar(selected: $selectedProject)
                }

                StatusGrid(counts: counts)

                IssueListSection(
                    icon: "triangle-alert",
                    iconColor: P.danger,
                    title: "기한 초과 미완료",
                    items: filterByProject(data.overdueIncomplete),
                    emptyText: "기한을 넘긴 일이 없어요",
                    hideWhenEmpty: true,
                    collapseKey: JiraSectionKey.overdue
                )

                IssueListSection(
                    icon: "list",
                    title: "이번 주 전체",
                    items: filterByProject(data.thisWeekIssues),
                    emptyText: "이번 주 일감이 없어요",
                    collapseKey: JiraSectionKey.thisWeek
                )
            }
            .padding(LumenTokens.Space.pad)
        }
        .frame(maxWidth: .infinity)
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
        LumenSegmentedControl(
            items: [.init(value: PresentColumn.allKey, label: "전체")]
                + Constants.jiraProjects.map { .init(value: $0.key, label: $0.displayName) },
            selection: $selected
        )
    }
}

struct StatusCellData {
    let key: JiraStatusKey
    let label: String
    let count: Int
}

struct StatusGrid: View {
    let counts: JiraStatusCounts

    private var cells: [StatusCellData] {
        [
            .init(key: .todo,       label: "할 일",  count: counts.todo),
            .init(key: .inProgress, label: "진행 중", count: counts.inProgress),
            .init(key: .done,       label: "완료",   count: counts.done),
        ]
    }

    var body: some View {
        HStack(spacing: LumenTokens.Space.stack) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                StatusCard(cell: cell)
            }
        }
    }
}

/// 상태별 개수 카드. 상태는 아이콘 + 글자로 함께 표시한다.
struct StatusCard: View {
    let cell: StatusCellData

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
            HStack(spacing: LumenTokens.Space.s1 + 2) {
                LumenIcon(cell.key.icon, size: .small)
                    .foregroundStyle(cell.key.tone == .category ? P.inkMuted : cell.key.fg)
                Text(cell.label)
                    .lumenText(.caption)
                    .foregroundStyle(P.inkFaint)
            }
            Text("\(cell.count)")
                .lumenText(.title2)
                .monospacedDigit()
                .foregroundStyle(P.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LumenTokens.Space.s4)
        .lumenCard()
    }
}
