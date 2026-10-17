import SwiftUI

private typealias P = LumenTokens.Palette

struct FutureColumn: View {
    let data: JiraDashboardData

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: LumenTokens.Space.group) {
                LumenSectionLabel(text: "앞으로")

                IssueListSection(
                    icon: "calendar",
                    title: "다음 주 이슈",
                    items: data.nextWeekIssues,
                    emptyText: "다음 주 일감이 없어요",
                    collapseKey: JiraSectionKey.nextWeek
                )

                backlogSection
                sprintsSection
                epicsSection
            }
            .padding(LumenTokens.Space.pad)
        }
        .frame(width: 380)
    }

    private var backlogSection: some View {
        CollapsibleSection(
            storageKey: JiraSectionKey.backlog,
            icon: "inbox",
            title: "일정 없는 내 백로그"
        ) {
            HStack(spacing: LumenTokens.Space.inline) {
                ForEach(Constants.jiraProjects, id: \.key) { proj in
                    BacklogBox(
                        key: proj.key,
                        count: data.backlogCountByProject[proj.key] ?? 0
                    )
                }
            }
        }
    }

    private var sprintsSection: some View {
        CollapsibleSection(
            storageKey: JiraSectionKey.sprints,
            icon: "circle-dashed",
            title: "진행 중 스프린트",
            count: data.sprintInfos.isEmpty ? nil : data.sprintInfos.count
        ) {
            if data.sprintInfos.isEmpty {
                HStack(spacing: LumenTokens.Space.inline) {
                    LumenIcon("circle-dashed", size: .small)
                        .foregroundStyle(P.inkFaint)
                    Text("진행 중인 스프린트가 없어요")
                        .lumenText(.label, weight: .regular)
                        .foregroundStyle(P.inkFaint)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, LumenTokens.Space.s3)
                .padding(.horizontal, LumenTokens.Space.s4)
                .lumenCard()
            } else {
                VStack(spacing: LumenTokens.Space.inline) {
                    ForEach(data.sprintInfos) { SprintCard(sprint: $0) }
                }
            }
        }
    }

    @ViewBuilder
    private var epicsSection: some View {
        let epics = data.epicInfos.filter { $0.dueDate != nil }
        if !epics.isEmpty {
            CollapsibleSection(
                storageKey: JiraSectionKey.epics,
                icon: "layers",
                title: "활성 에픽",
                count: epics.count
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(epics.enumerated()), id: \.element.id) { idx, epic in
                        if idx > 0 { LumenHairline() }
                        EpicRow(epic: epic)
                    }
                }
                .padding(LumenTokens.Space.s1)
                .lumenCard()
            }
        }
    }
}

struct BacklogBox: View {
    let key: String
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
            HStack(spacing: LumenTokens.Space.s1 + 2) {
                Circle().fill(jiraProjectColor(key)).frame(width: 8, height: 8)
                Text(jiraProjectDisplayName(key))
                    .lumenText(.caption)
                    .foregroundStyle(P.inkFaint)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(count)")
                    .lumenText(.title3)
                    .monospacedDigit()
                    .foregroundStyle(P.ink)
                Text("건")
                    .lumenText(.caption)
                    .foregroundStyle(P.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LumenTokens.Space.s3)
        .lumenCard()
    }
}

struct SprintCard: View {
    let sprint: SprintInfo

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
            HStack(spacing: LumenTokens.Space.inline) {
                ProjectChip(key: sprint.projectKey)
                Text(sprint.name)
                    .lumenText(.body, weight: .medium)
                    .foregroundStyle(P.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(sprint.completionPct)%")
                    .lumenText(.label)
                    .monospacedDigit()
                    .foregroundStyle(P.ink)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(P.chartGrid)
                    Capsule()
                        .fill(jiraProjectColor(sprint.projectKey))
                        .frame(width: geo.size.width * CGFloat(sprint.completionPct) / 100)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(sprint.completedIssues) / \(sprint.totalIssues)건 완료")
                    .lumenText(.caption)
                    .monospacedDigit()
                    .foregroundStyle(P.inkFaint)
                Spacer(minLength: 0)
                if let start = sprint.startDate, let end = sprint.endDate {
                    Text("\(short(start)) – \(short(end))")
                        .lumenText(.caption)
                        .monospacedDigit()
                        .foregroundStyle(P.inkFaint)
                }
            }
        }
        .padding(LumenTokens.Space.s4)
        .lumenCard()
    }

    private func short(_ date: Date) -> String {
        LumenDateFormat.monthDay.string(from: date)
    }
}

struct EpicRow: View {
    let epic: EpicInfo

    var body: some View {
        Button {
            openJira(epic.key)
        } label: {
            VStack(alignment: .leading, spacing: LumenTokens.Space.s1 + 2) {
                Text(epic.summary)
                    .lumenText(.body, weight: .medium)
                    .foregroundStyle(P.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: LumenTokens.Space.inline) {
                    ProjectChip(key: epic.projectKey)
                    Spacer(minLength: 0)
                    if let due = epic.dueDate {
                        DueLabel(date: due, isDone: false)
                    }
                }
            }
            .padding(LumenTokens.Space.s3)
            .contentShape(Rectangle())
        }
        .buttonStyle(LumenListRowStyle())
        .onHover { if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
    }
}
