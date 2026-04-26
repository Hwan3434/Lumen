import SwiftUI

struct PastColumn: View {
    let data: JiraDashboardData

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                LumenSectionLabel(text: "지난 30일")

                HStack(spacing: 8) {
                    StatBox(label: "생성", value: "\(data.createdLast30.count)", sub: "reporter 기준")
                    StatBox(label: "완료", value: "\(data.completedLast30.count)", sub: "assignee 기준")
                }

                let (taskCount, bugCount) = taskBugCounts(data.completedLast30)
                HStack(spacing: 8) {
                    StatBox(label: "Task", value: "\(taskCount)", sub: nil, big: false)
                    StatBox(label: "Bug",  value: "\(bugCount)",  sub: nil, big: false)
                }

                projectBars

                if let avg = avgProcessingDays(data.completedLast30) {
                    HStack(spacing: 7) {
                        Image(systemName: "timer")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LumenTokens.Accent.violetSoft)
                        Text("평균 처리 시간")
                            .font(.system(size: 11.5))
                            .foregroundStyle(LumenTokens.TextColor.secondary)
                        Spacer()
                        Text(String(format: "%.1f일", avg))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LumenTokens.TextColor.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.white.opacity(0.018))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(LumenTokens.stroke, lineWidth: 0.5)
                            )
                    )
                }

                IssueListSection(
                    icon: "flame",
                    iconColor: LumenTokens.JiraPriorityTone.highest,
                    title: "Highest 미완료",
                    items: data.highestIncomplete,
                    emptyText: "해당 이슈 없음"
                )
            }
            .padding(14)
        }
        .frame(width: 280)
    }

    private var projectBars: some View {
        let byProject = projectCompletions(data.completedLast30)
        let maxCount = max(byProject.map(\.1).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 8) {
            LumenSectionLabel(text: "프로젝트별 완료")
            VStack(spacing: 7) {
                ForEach(Array(byProject.enumerated()), id: \.offset) { _, item in
                    ProjectBar(key: item.0, count: item.1, maxCount: maxCount)
                }
            }
        }
    }

    private func taskBugCounts(_ issues: [JiraIssue]) -> (Int, Int) {
        var task = 0, bug = 0
        for i in issues {
            switch i.issueType {
            case "Task": task += 1
            case "Bug":  bug += 1
            default: break
            }
        }
        return (task, bug)
    }

    private func avgProcessingDays(_ issues: [JiraIssue]) -> Double? {
        let days = issues.compactMap { i -> Double? in
            guard let c = i.created, let r = i.resolutionDate else { return nil }
            let d = Calendar.current.dateComponents([.day], from: c, to: r).day ?? 0
            return Double(max(d, 0))
        }
        guard !days.isEmpty else { return nil }
        return days.reduce(0, +) / Double(days.count)
    }

    private func projectCompletions(_ issues: [JiraIssue]) -> [(String, Int)] {
        var byProject: [String: Int] = [:]
        for i in issues { byProject[i.projectKey, default: 0] += 1 }
        return Constants.jiraProjects.map { ($0.key, byProject[$0.key] ?? 0) }
    }
}

struct StatBox: View {
    let label: String
    let value: String
    var sub: String? = nil
    var big: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10.5, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(LumenTokens.TextColor.muted)
            Text(value)
                .font(.system(size: big ? 22 : 17, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.primary)
            if let sub {
                Text(sub)
                    .font(.system(size: 10.5))
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(big ? EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
                     : EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                )
        )
    }
}

struct ProjectBar: View {
    let key: String
    let count: Int
    let maxCount: Int

    var body: some View {
        let color = jiraProjectColor(key)
        HStack(spacing: 8) {
            Text(jiraProjectDisplayName(key))
                .font(.system(size: 11))
                .foregroundStyle(LumenTokens.TextColor.secondary)
                .frame(width: 60, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.04))
                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: max(0, geo.size.width * CGFloat(count) / CGFloat(maxCount)))
                        .shadow(color: color.opacity(0.35), radius: 3)
                }
            }
            .frame(height: 6)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(LumenTokens.TextColor.primary)
                .frame(width: 26, alignment: .trailing)
        }
    }
}
