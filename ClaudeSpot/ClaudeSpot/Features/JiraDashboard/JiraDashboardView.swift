import SwiftUI
import AppKit

struct JiraDashboardView: View {
    private var service: JiraService { JiraService.shared }

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.10, blue: 0.13).ignoresSafeArea()

            if service.isLoading && service.data == nil {
                loadingView
            } else if let msg = service.errorMessage, service.data == nil {
                errorView(msg)
            } else if let data = service.data {
                contentView(data)
            } else {
                emptyView
            }
        }
        .frame(width: 820, height: 680)
        .onAppear { Task { await service.fetch() } }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(0.8).tint(.gray)
            Text("Jira 데이터 불러오는 중...")
                .font(.system(size: 12)).foregroundColor(.gray)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle").foregroundColor(.orange).font(.system(size: 20))
            Text("불러오기 실패").font(.system(size: 13, weight: .medium)).foregroundColor(.white)
            Text(msg).font(.system(size: 11)).foregroundColor(.gray)
                .multilineTextAlignment(.center).padding(.horizontal, 20)
            Button("다시 시도") { Task { await service.fetch(force: true) } }
                .buttonStyle(.plain).font(.system(size: 11)).foregroundColor(.blue).padding(.top, 4)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray").foregroundColor(.gray).font(.system(size: 20))
            Text("데이터 없음").font(.system(size: 12)).foregroundColor(.gray)
        }
    }

    // MARK: - Content

    private func contentView(_ data: JiraDashboardData) -> some View {
        VStack(spacing: 0) {
            headerBar(data)
            HStack(alignment: .top, spacing: 0) {
                leftPanel(data)
                Divider().background(Color.white.opacity(0.08))
                rightPanel(data.projectStats)
            }
        }
    }

    // MARK: - Header

    private func headerBar(_ data: JiraDashboardData) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2").font(.system(size: 11)).foregroundColor(.blue.opacity(0.8))
                Text("Jira 대시보드").font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                Text(Constants.jiraProjects.joined(separator: " · ")).font(.system(size: 10)).foregroundColor(.gray)
            }
            Spacer()
            HStack(spacing: 8) {
                if service.isLoading {
                    ProgressView().scaleEffect(0.5).tint(.gray)
                } else {
                    Text(relativeTime(data.lastUpdated)).font(.system(size: 10)).foregroundColor(.gray.opacity(0.6))
                }
                Button { Task { await service.fetch(force: true) } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11)).foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Left Panel

    private func leftPanel(_ data: JiraDashboardData) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                summaryCards(data.cards)

                if !data.todayIssues.isEmpty {
                    issueSection(title: "오늘 마감", icon: "calendar.badge.exclamationmark", color: .orange, issues: data.todayIssues)
                }

                issueSection(title: "이번 주", icon: "calendar", color: .blue, issues: data.thisWeekIssues, emptyText: "이번 주 일감 없음")

                if !data.highestIncomplete.isEmpty {
                    issueSection(title: "Highest 미완료", icon: "exclamationmark.2", color: .purple, issues: data.highestIncomplete)
                }

                if !data.overdueIncomplete.isEmpty {
                    issueSection(title: "기한 초과", icon: "clock.badge.xmark", color: .red, issues: data.overdueIncomplete)
                }
            }
            .padding(14)
        }
        .frame(width: 510)
    }

    // MARK: - Summary Cards (2 rows × 3)

    private func summaryCards(_ cards: JiraSummaryCards) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                summaryCard(value: cards.completedThisWeek,  label: "금주 완료",  color: .green,  icon: "checkmark.circle")
                summaryCard(value: cards.inProgressThisWeek, label: "금주 진행중", color: .blue,   icon: "arrow.triangle.2.circlepath")
                summaryCard(value: cards.pendingThisWeek,    label: "금주 대기",  color: .gray,   icon: "clock")
            }
            HStack(spacing: 6) {
                summaryCard(value: cards.onHoldThisWeek,     label: "금주 보류",  color: .orange, icon: "pause.circle")
                summaryCard(value: cards.thisWeekTotal,      label: "금주 전체",  color: .cyan,   icon: "calendar")
                summaryCard(value: cards.nextWeekTotal,      label: "차주 전체",  color: .purple, icon: "calendar.badge.plus")
            }
        }
    }

    private func summaryCard(value: Int, label: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9)).foregroundColor(color.opacity(0.8))
                Text(label).font(.system(size: 9)).foregroundColor(.gray)
            }
            Text("\(value)").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(color.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Issue Section

    private func issueSection(title: String, icon: String, color: Color, issues: [JiraIssue], emptyText: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
                Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(issues.count)")
                    .font(.system(size: 10)).foregroundColor(.gray)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.white.opacity(0.07)).clipShape(Capsule())
            }
            if issues.isEmpty {
                if let text = emptyText {
                    Text(text).font(.system(size: 11)).foregroundColor(.gray.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 6)
                }
            } else {
                VStack(spacing: 1) {
                    ForEach(issues) { issue in issueRow(issue, accentColor: color) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func issueRow(_ issue: JiraIssue, accentColor: Color) -> some View {
        HStack(spacing: 7) {
            Text(issue.projectKey)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(projectColor(issue.projectKey).opacity(0.9))
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(projectColor(issue.projectKey).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Circle().fill(priorityColor(issue.priority)).frame(width: 5, height: 5)

            Text(issue.summary)
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.85))
                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)

            if let due = issue.dueDate {
                Text(shortDate(due)).font(.system(size: 10)).foregroundColor(dueDateColor(due, isDone: issue.isDone))
            }

            statusBadge(issue)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.white.opacity(0.03))
        .contentShape(Rectangle())
        .onTapGesture { openJira(issue.key) }
        .cursor(.pointingHand)
    }

    private func statusBadge(_ issue: JiraIssue) -> some View {
        let (text, color): (String, Color) = {
            if issue.isOnHold    { return ("보류", .orange) }
            if issue.isInProgress { return ("진행", .blue) }
            if issue.isDone       { return ("완료", .green) }
            return ("대기", .gray)
        }()
        return Text(text).font(.system(size: 9)).foregroundColor(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.15)).clipShape(Capsule())
    }

    // MARK: - Right Panel (프로젝트별)

    private func rightPanel(_ stats: [ProjectWeekStats]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("프로젝트별 (금주)").font(.system(size: 10, weight: .medium)).foregroundColor(.gray)
                ForEach(stats) { stat in
                    projectCard(stat)
                }
            }
            .padding(14)
        }
        .frame(width: 309)
    }

    private func projectCard(_ stats: ProjectWeekStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 헤더
            HStack {
                Text(stats.key).font(.system(size: 13, weight: .semibold)).foregroundColor(projectColor(stats.key))
                Spacer()
                Text("\(stats.total)건").font(.system(size: 10)).foregroundColor(.gray)
            }

            if stats.total == 0 {
                Text("이번주 일감 없음").font(.system(size: 11)).foregroundColor(.gray.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 8)
            } else {
                // 도넛 차트 + 범례
                HStack(spacing: 16) {
                    DonutChartView(
                        segments: [
                            .init(value: Double(stats.completed),  color: .green,  label: "완료"),
                            .init(value: Double(stats.inProgress), color: .blue,   label: "진행"),
                            .init(value: Double(stats.pending),    color: Color.gray.opacity(0.5), label: "대기"),
                            .init(value: Double(stats.onHold),     color: .orange, label: "보류"),
                        ],
                        centerText: "\(Int(stats.completionRate * 100))%",
                        size: 80
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        legendRow("완료",  count: stats.completed,  color: .green)
                        legendRow("진행중", count: stats.inProgress, color: .blue)
                        legendRow("대기",  count: stats.pending,    color: .gray)
                        if stats.onHold > 0 {
                            legendRow("보류", count: stats.onHold, color: .orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 가로 스택 바
                stackBar(stats)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(projectColor(stats.key).opacity(0.2), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func legendRow(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 10)).foregroundColor(.gray)
            Spacer()
            Text("\(count)").font(.system(size: 10, weight: .medium)).foregroundColor(.white)
        }
    }

    private func stackBar(_ stats: ProjectWeekStats) -> some View {
        GeometryReader { geo in
            let total = max(stats.total, 1)
            let w = geo.size.width
            HStack(spacing: 1) {
                if stats.completed > 0 {
                    RoundedRectangle(cornerRadius: 2).fill(Color.green)
                        .frame(width: w * CGFloat(stats.completed) / CGFloat(total))
                }
                if stats.inProgress > 0 {
                    RoundedRectangle(cornerRadius: 2).fill(Color.blue)
                        .frame(width: w * CGFloat(stats.inProgress) / CGFloat(total))
                }
                if stats.pending > 0 {
                    RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.4))
                        .frame(width: w * CGFloat(stats.pending) / CGFloat(total))
                }
                if stats.onHold > 0 {
                    RoundedRectangle(cornerRadius: 2).fill(Color.orange)
                        .frame(width: w * CGFloat(stats.onHold) / CGFloat(total))
                }
            }
        }
        .frame(height: 5)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    // MARK: - Helpers

    private func projectColor(_ key: String) -> Color {
        key.contains("AI") ? .purple : .cyan
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "Highest": return .red
        case "High":    return .orange
        case "Low":     return .blue.opacity(0.7)
        default:        return .gray.opacity(0.6)
        }
    }

    private func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "MM/dd"
        return fmt.string(from: date)
    }

    private func dueDateColor(_ date: Date, isDone: Bool) -> Color {
        if isDone { return .gray.opacity(0.5) }
        if date < Date() { return .red.opacity(0.9) }
        if Calendar.current.isDateInToday(date) { return .orange }
        return .gray.opacity(0.6)
    }

    private func relativeTime(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "방금" }
        if mins < 60 { return "\(mins)분 전" }
        return "\(mins / 60)시간 전"
    }

    private func openJira(_ key: String) {
        if let url = URL(string: "https://bankx-playplanet.atlassian.net/browse/\(key)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Donut Chart

struct DonutChartView: View {
    struct Segment {
        let value: Double
        let color: Color
        let label: String
    }

    let segments: [Segment]
    let centerText: String
    let size: CGFloat

    private var total: Double { max(segments.reduce(0) { $0 + $1.value }, 1) }
    private var nonZero: [Segment] { segments.filter { $0.value > 0 } }

    private struct Slice { let start: Double; let end: Double; let color: Color }

    private var slices: [Slice] {
        var result: [Slice] = []
        var cumulative = 0.0
        for seg in nonZero {
            let start = cumulative / total
            cumulative += seg.value
            result.append(Slice(start: start, end: cumulative / total, color: seg.color))
        }
        return result
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: size * 0.18)
                .frame(width: size * 0.76, height: size * 0.76)

            ForEach(Array(slices.enumerated()), id: \.offset) { _, slice in
                Circle()
                    .trim(from: slice.start, to: slice.end)
                    .stroke(slice.color, style: StrokeStyle(lineWidth: size * 0.18, lineCap: .butt))
                    .frame(width: size * 0.76, height: size * 0.76)
                    .rotationEffect(.degrees(-90))
            }

            Text(centerText)
                .font(.system(size: size * 0.18, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Cursor modifier

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}
