import SwiftUI

private typealias P = LumenTokens.Palette

struct PastColumn: View {
    let data: JiraDashboardData

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: LumenTokens.Space.group) {
                LumenSectionLabel(text: "지난 30일")

                HStack(spacing: LumenTokens.Space.stack) {
                    StatBox(label: "생성", value: "\(data.createdLast30.count)", sub: "보고자 기준")
                    StatBox(label: "완료", value: "\(data.completedLast30.count)", sub: "담당자 기준")
                }

                let (taskCount, bugCount) = taskBugCounts(data.completedLast30)
                HStack(spacing: LumenTokens.Space.stack) {
                    StatBox(label: "Task", value: "\(taskCount)", sub: nil, big: false)
                    StatBox(label: "Bug",  value: "\(bugCount)",  sub: nil, big: false)
                }

                projectBars

                if let avg = avgProcessingDays(data.completedLast30) {
                    HStack(spacing: LumenTokens.Space.inline) {
                        LumenIcon("timer")
                            .foregroundStyle(P.inkMuted)
                        Text("평균 처리 시간")
                            .lumenText(.label, weight: .regular)
                            .foregroundStyle(P.inkMuted)
                        Spacer()
                        Text(String(format: "%.1f일", avg))
                            .lumenText(.body, weight: .semibold)
                            .monospacedDigit()
                            .foregroundStyle(P.ink)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, LumenTokens.Space.s4)
                    .lumenCard()
                }

                IssueListSection(
                    icon: "flame",
                    iconColor: P.danger,
                    title: "Highest 미완료",
                    items: data.highestIncomplete,
                    emptyText: "해당 이슈가 없어요",
                    collapseKey: JiraSectionKey.highest
                )
            }
            .padding(LumenTokens.Space.pad)
        }
        .frame(width: 340)
    }

    private var projectBars: some View {
        let byProject = projectCompletions(data.completedLast30)
        let maxCount = max(byProject.map(\.1).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
            LumenSectionLabel(text: "프로젝트별 완료")
            VStack(spacing: LumenTokens.Space.inline) {
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
        VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
            Text(label)
                .lumenText(.caption)
                .foregroundStyle(P.inkFaint)
            Text(value)
                .lumenText(big ? .title2 : .title3)
                .monospacedDigit()
                .foregroundStyle(P.ink)
            if let sub {
                Text(sub)
                    .lumenText(.caption)
                    .foregroundStyle(P.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(big ? LumenTokens.Space.s4 : LumenTokens.Space.s3)
        .lumenCard()
    }
}

/// 가로 막대. 끝은 4 둥글게, 계열 색은 막대에만, 숫자는 글자색.
struct ProjectBar: View {
    let key: String
    let count: Int
    let maxCount: Int

    var body: some View {
        let color = jiraProjectColor(key)
        HStack(spacing: LumenTokens.Space.inline) {
            Text(jiraProjectDisplayName(key))
                .lumenText(.label, weight: .regular)
                .foregroundStyle(P.inkMuted)
                .frame(width: 88, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 0, bottomTrailing: 4, topTrailing: 4))
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(count) / CGFloat(maxCount)))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alignment: .leading) {
                    Rectangle().fill(P.chartGrid).frame(height: 1)
                }
            }
            .frame(height: 8)
            Text("\(count)")
                .lumenText(.label)
                .monospacedDigit()
                .foregroundStyle(P.ink)
                .frame(width: 32, alignment: .trailing)
        }
    }
}
