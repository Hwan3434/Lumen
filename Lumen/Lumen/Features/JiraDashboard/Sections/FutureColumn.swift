import SwiftUI

struct FutureColumn: View {
    let data: JiraDashboardData

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                LumenSectionLabel(text: "앞으로")

                IssueListSection(
                    icon: "calendar",
                    iconColor: LumenTokens.TextColor.secondary,
                    title: "차주 이슈",
                    items: data.nextWeekIssues,
                    emptyText: "차주 일감 없음"
                )

                backlogSection
                sprintsSection
                epicsSection
            }
            .padding(14)
        }
        .frame(width: 320)
    }

    private var backlogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                Text("일정없는 내 백로그")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.secondary)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 6) {
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LumenTokens.Accent.violetSoft)
                Text("진행중 스프린트")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.secondary)
                if !data.sprintInfos.isEmpty {
                    Text("\(data.sprintInfos.count)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }
            }
            .padding(.horizontal, 4)

            if data.sprintInfos.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 12))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                    Text("활성 스프린트 없음")
                        .font(.system(size: 11))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                    Spacer(minLength: 0)
                }
                .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(LumenTokens.stroke)
                        .background(
                            RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.012))
                        )
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(data.sprintInfos) { SprintCard(sprint: $0) }
                }
            }
        }
    }

    @ViewBuilder
    private var epicsSection: some View {
        let epics = data.epicInfos.filter { $0.dueDate != nil }
        if !epics.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "flag")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0x9B/255, green: 0x7B/255, blue: 0xD9/255))
                    Text("활성 에픽")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LumenTokens.TextColor.secondary)
                    Text("\(epics.count)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }
                .padding(.horizontal, 4)
                VStack(spacing: 1) {
                    ForEach(epics) { EpicRow(epic: $0) }
                }
            }
        }
    }
}

struct BacklogBox: View {
    let key: String
    let count: Int

    var body: some View {
        let color = jiraProjectColor(key)
        VStack(alignment: .leading, spacing: 2) {
            Text(jiraProjectDisplayName(key))
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.tail)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(count)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                Text("건")
                    .font(.system(size: 10))
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(color.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(color.opacity(0.20), lineWidth: 0.5)
                )
        )
    }
}

struct SprintCard: View {
    let sprint: SprintInfo
    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                ProjectChip(key: sprint.projectKey)
                Text(sprint.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(sprint.completionPct)%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(toneColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.04))
                    Capsule()
                        .fill(toneColor)
                        .frame(width: geo.size.width * CGFloat(sprint.completionPct) / 100)
                        .shadow(color: toneColor.opacity(0.4), radius: 3)
                }
            }
            .frame(height: 4)

            HStack {
                Text("\(sprint.completedIssues)/\(sprint.totalIssues)건 완료")
                    .font(.system(size: 10.5))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                Spacer(minLength: 0)
                if let start = sprint.startDate, let end = sprint.endDate {
                    Text("\(short(start)) → \(short(end))")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hovered ? Color.white.opacity(0.045) : Color.white.opacity(0.022))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                )
        )
        .onHover { hovered = $0 }
    }

    private var toneColor: Color {
        if sprint.completionPct >= 80 { return LumenTokens.JiraStatusTone.completedFg }
        if sprint.completionPct >= 50 { return LumenTokens.Accent.violetSoft }
        return LumenTokens.Accent.amber
    }

    private func short(_ date: Date) -> String {
        LumenDateFormat.monthDay.string(from: date)
    }
}

struct EpicRow: View {
    let epic: EpicInfo
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 8) {
            ProjectChip(key: epic.projectKey)
            Image(systemName: "flag")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(red: 0x9B/255, green: 0x7B/255, blue: 0xD9/255))
            Text(epic.summary)
                .font(.system(size: 12))
                .foregroundStyle(LumenTokens.TextColor.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let due = epic.dueDate {
                DueLabel(date: due, isDone: false)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(hovered ? Color.white.opacity(0.04) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0; if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        .onTapGesture { openJira(epic.key) }
    }
}
