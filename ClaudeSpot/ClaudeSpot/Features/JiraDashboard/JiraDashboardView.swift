import SwiftUI
import AppKit

struct JiraDashboardView: View {
    private static let allKey = "ALL"
    private var service: JiraService { JiraService.shared }
    @State private var selectedProject: String = Self.allKey

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
        .frame(width: 1160, height: 840)
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
                pastPanel(data)
                Divider().background(Color.white.opacity(0.08))
                centerPanel(data)
                Divider().background(Color.white.opacity(0.08))
                futurePanel(data)
            }
            Divider().background(Color.white.opacity(0.08))
            trendPanel(data)
        }
    }

    // MARK: - Header

    private func headerBar(_ data: JiraDashboardData) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2").font(.system(size: 11)).foregroundColor(.blue.opacity(0.8))
                Text("Jira 대시보드").font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                Text(Constants.jiraProjects.map(\.displayName).joined(separator: " · ")).font(.system(size: 10)).foregroundColor(.gray)
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
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Past Panel (지난 30일)

    private func pastPanel(_ data: JiraDashboardData) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                panelLabel("지난 30일", icon: "clock.arrow.circlepath", color: .purple)

                HStack(spacing: 8) {
                    past30StatBox(
                        label: "생성",
                        count: data.createdLast30.count,
                        sub: "reporter 기준",
                        color: .blue.opacity(0.8)
                    )
                    past30StatBox(
                        label: "완료",
                        count: data.completedLast30.count,
                        sub: "assignee 기준",
                        color: .green.opacity(0.8)
                    )
                }

                let (taskCount, bugCount) = taskBugCounts(data.completedLast30)
                HStack(spacing: 8) {
                    pastTypeBox("Task", count: taskCount, color: .cyan.opacity(0.8),  icon: "checkmark.square")
                    pastTypeBox("Bug",  count: bugCount,  color: .red.opacity(0.75),  icon: "ladybug")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("프로젝트별").font(.system(size: 10, weight: .medium)).foregroundColor(.gray)
                    let byProject = projectCompletions(data.completedLast30)
                    let maxCount = max(byProject.map(\.1).max() ?? 1, 1)
                    ForEach(Array(byProject.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(projectDisplayName(item.0))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(projectColor(item.0))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.1)건").font(.system(size: 10)).foregroundColor(.white)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(projectColor(item.0).opacity(0.6))
                                        .frame(width: geo.size.width * CGFloat(item.1) / CGFloat(maxCount))
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                }

                if let avg = avgProcessingDays(data.completedLast30) {
                    HStack(spacing: 6) {
                        Image(systemName: "timer").font(.system(size: 10)).foregroundColor(.gray)
                        Text("평균 처리 시간").font(.system(size: 10)).foregroundColor(.gray)
                        Spacer()
                        Text(String(format: "%.1f일", avg))
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                if !data.highestIncomplete.isEmpty {
                    issueSection(title: "Highest 미완료", icon: "exclamationmark.2", color: .purple, issues: data.highestIncomplete)
                }

                if !data.blockedIssues.isEmpty {
                    issueSection(title: "차단됨 (보류·대기)", icon: "hand.raised", color: .orange, issues: data.blockedIssues)
                }
            }
            .padding(14)
        }
        .frame(width: 320)
    }

    // MARK: - Center Panel (현재)

    private func centerPanel(_ data: JiraDashboardData) -> some View {
        VStack(spacing: 0) {
            projectTabBar

            ScrollView(.vertical, showsIndicators: false) {
                let isAll           = selectedProject == Self.allKey
                let filteredToday   = filterByProject(data.todayIssues)
                let filteredWeek    = filterByProject(data.thisWeekIssues)
                let filteredOverdue = filterByProject(data.overdueIncomplete)
                let counts          = isAll ? data.thisWeekCounts : data.projectStats.first { $0.key == selectedProject }?.counts ?? JiraStatusCounts()

                VStack(alignment: .leading, spacing: 14) {
                    panelLabel("이번 주", icon: "calendar", color: .blue)
                    summaryCards(counts: counts)

                    if !filteredToday.isEmpty {
                        issueSection(title: "오늘 마감", icon: "calendar.badge.exclamationmark", color: .orange, issues: filteredToday)
                    }

                    issueSection(title: "이번 주 전체", icon: "calendar", color: .blue, issues: filteredWeek, emptyText: "이번 주 일감 없음")

                    if !filteredOverdue.isEmpty {
                        issueSection(title: "기한 초과", icon: "clock.badge.xmark", color: .red, issues: filteredOverdue)
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 520)
    }

    private var projectTabBar: some View {
        HStack(spacing: 0) {
            Button { selectedProject = Self.allKey } label: {
                Text(Self.allKey)
                    .font(.system(size: 11, weight: selectedProject == Self.allKey ? .semibold : .regular))
                    .foregroundColor(selectedProject == Self.allKey ? .white : .gray.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(selectedProject == Self.allKey ? Color.white.opacity(0.15) : Color.clear)
                    .contentShape(Capsule())
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(KeyEquivalent("1"), modifiers: .command)

            ForEach(Array(Constants.jiraProjects.enumerated()), id: \.offset) { idx, proj in
                let button = Button { selectedProject = proj.key } label: {
                    Text(proj.displayName)
                        .font(.system(size: 11, weight: selectedProject == proj.key ? .semibold : .regular))
                        .foregroundColor(selectedProject == proj.key ? proj.color : .gray.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(selectedProject == proj.key ? proj.color.opacity(0.18) : Color.clear)
                        .contentShape(Capsule())
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                if idx + 2 < 10 {
                    button.keyboardShortcut(KeyEquivalent(Character("\(idx + 2)")), modifiers: .command)
                } else {
                    button
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
    }

    // MARK: - Future Panel (앞으로)

    private func futurePanel(_ data: JiraDashboardData) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                panelLabel("앞으로", icon: "arrow.right.circle", color: Color(red: 0.4, green: 0.8, blue: 0.6))

                futureSection(
                    title: "차주 이슈",
                    icon: "calendar.badge.plus",
                    color: Color(red: 0.4, green: 0.8, blue: 0.6),
                    issues: data.nextWeekIssues,
                    emptyText: "차주 일감 없음"
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("일정없는 내 백로그").font(.system(size: 10, weight: .medium)).foregroundColor(.gray)
                    HStack(spacing: 8) {
                        ForEach(Constants.jiraProjects, id: \.key) { proj in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(proj.displayName)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(proj.color)
                                    .lineLimit(1)
                                Text("\(data.backlogCountByProject[proj.key] ?? 0)")
                                    .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                                Text("건").font(.system(size: 9)).foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(proj.color.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(proj.color.opacity(0.2), lineWidth: 0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

                if !data.sprintInfos.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("진행중 스프린트").font(.system(size: 10, weight: .medium)).foregroundColor(.gray)
                        ForEach(data.sprintInfos) { sprint in
                            sprintCard(sprint)
                        }
                    }
                }

                let activeEpics = data.epicInfos.filter { $0.dueDate != nil }
                if !activeEpics.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("활성 에픽").font(.system(size: 10, weight: .medium)).foregroundColor(.gray)
                        ForEach(activeEpics) { epic in
                            epicRow(epic)
                        }
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 320)
    }

    private func sprintCard(_ sprint: SprintInfo) -> some View {
        let completionColor: Color = sprint.completionPct >= 80 ? .green : sprint.completionPct >= 50 ? .blue : .orange
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(projectDisplayName(sprint.projectKey))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(projectColor(sprint.projectKey))
                    .lineLimit(1)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(projectColor(sprint.projectKey).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text(sprint.name).font(.system(size: 11, weight: .medium)).foregroundColor(.white).lineLimit(1)
                Spacer()
                Text("\(sprint.completionPct)%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(completionColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(completionColor.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(sprint.completionPct) / 100)
                }
            }
            .frame(height: 5)

            HStack {
                Text("\(sprint.completedIssues)/\(sprint.totalIssues)건 완료")
                    .font(.system(size: 9)).foregroundColor(.gray)
                Spacer()
                if let start = sprint.startDate, let end = sprint.endDate {
                    Text("\(shortDate(start)) → \(shortDate(end))")
                        .font(.system(size: 9)).foregroundColor(.gray.opacity(0.7))
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(projectColor(sprint.projectKey).opacity(0.2), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func epicRow(_ epic: EpicInfo) -> some View {
        HStack(spacing: 7) {
            Text(projectDisplayName(epic.projectKey))
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(projectColor(epic.projectKey).opacity(0.9))
                .lineLimit(1)
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(projectColor(epic.projectKey).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Text(epic.summary)
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.85))
                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)

            if let due = epic.dueDate {
                Text(shortDate(due))
                    .font(.system(size: 9))
                    .foregroundColor(dueDateColor(due, isDone: false))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.03))
        .contentShape(Rectangle())
        .onTapGesture { openJira(epic.key) }
        .cursor(.pointingHand)
    }

    // MARK: - Summary Cards

    private func summaryCards(counts: JiraStatusCounts) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                summaryCard(value: counts.todo,       label: "해야 할 일", color: .gray,   icon: "circle")
                summaryCard(value: counts.inProgress, label: "진행중",    color: .blue,   icon: "arrow.triangle.2.circlepath")
                summaryCard(value: counts.onHold,     label: "보류",      color: .orange, icon: "pause.circle")
            }
            HStack(spacing: 6) {
                summaryCard(value: counts.waiting,    label: "대기",      color: Color(red: 0.9, green: 0.7, blue: 0.1), icon: "clock")
                summaryCard(value: counts.completed,  label: "완료",      color: .green,  icon: "checkmark.circle")
                summaryCard(value: counts.cancelled,  label: "취소",      color: .red.opacity(0.8), icon: "xmark.circle")
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

    // MARK: - Issue Sections

    private func sectionView<Row: View>(
        title: String, icon: String, color: Color,
        issues: [JiraIssue], emptyText: String? = nil,
        rowView: @escaping (JiraIssue) -> Row
    ) -> some View {
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
                    ForEach(issues) { issue in rowView(issue) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func issueSection(title: String, icon: String, color: Color, issues: [JiraIssue], emptyText: String? = nil) -> some View {
        sectionView(title: title, icon: icon, color: color, issues: issues, emptyText: emptyText) { issue in
            issueRow(issue)
        }
    }

    private func futureSection(title: String, icon: String, color: Color, issues: [JiraIssue], emptyText: String) -> some View {
        sectionView(title: title, icon: icon, color: color, issues: issues, emptyText: emptyText) { issue in
            futureIssueRow(issue)
        }
    }

    private func issueRow(_ issue: JiraIssue) -> some View {
        HStack(spacing: 7) {
            Text(projectDisplayName(issue.projectKey))
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(projectColor(issue.projectKey).opacity(0.9))
                .lineLimit(1)
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(projectColor(issue.projectKey).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Circle().fill(priorityColor(issue.priority)).frame(width: 5, height: 5)

            Text(issue.summary)
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.85))
                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)

            if let due = issue.dueDate {
                Text(dateRangeText(start: issue.startDate, due: due))
                    .font(.system(size: 10)).foregroundColor(dueDateColor(due, isDone: issue.isDone))
                    .lineLimit(1)
            }

            statusBadge(issue)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.white.opacity(0.03))
        .contentShape(Rectangle())
        .onTapGesture { openJira(issue.key) }
        .cursor(.pointingHand)
    }

    private func futureIssueRow(_ issue: JiraIssue) -> some View {
        HStack(spacing: 6) {
            Circle().fill(priorityColor(issue.priority)).frame(width: 5, height: 5)

            Text(issue.summary)
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.85))
                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)

            if let due = issue.dueDate {
                Text(dateRangeText(start: issue.startDate, due: due))
                    .font(.system(size: 10)).foregroundColor(dueDateColor(due, isDone: false))
                    .lineLimit(1)
            } else {
                Text("—").font(.system(size: 10)).foregroundColor(.gray.opacity(0.4))
            }

            statusBadge(issue)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.03))
        .contentShape(Rectangle())
        .onTapGesture { openJira(issue.key) }
        .cursor(.pointingHand)
    }

    private func statusBadge(_ issue: JiraIssue) -> some View {
        let (text, color): (String, Color) = {
            switch issue.status {
            case "완료":   return ("완료", .green)
            case "진행중": return ("진행중", .blue)
            case "보류":   return ("보류", .orange)
            case "대기":   return ("대기", Color(red: 0.9, green: 0.7, blue: 0.1))
            case "취소":   return ("취소", .red.opacity(0.8))
            default:       return ("할 일", .gray)
            }
        }()
        return Text(text).font(.system(size: 9)).foregroundColor(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.15)).clipShape(Capsule())
    }

    // MARK: - Trend Panel (하단 전체)

    private func trendPanel(_ data: JiraDashboardData) -> some View {
        let created   = dailyCounts(data.createdLast30,   dateOf: \.created)
        let completed = dailyCounts(data.completedLast30, dateOf: \.resolutionDate)
        let maxVal    = max((created + completed).max() ?? 1, 1)
        let cal       = Calendar.current
        let today     = cal.startOfDay(for: Date())
        let dates     = (0..<30).map { cal.date(byAdding: .day, value: $0 - 29, to: today) ?? today }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                panelLabel("30일 일별 추이", icon: "chart.bar", color: .gray.opacity(0.8))
                Circle().fill(Color.blue.opacity(0.55)).frame(width: 6, height: 6)
                Text("생성").font(.system(size: 9)).foregroundColor(.blue.opacity(0.7))
                Circle().fill(Color.green.opacity(0.65)).frame(width: 6, height: 6)
                Text("완료").font(.system(size: 9)).foregroundColor(.green.opacity(0.7))
                Spacer()
            }

            GeometryReader { geo in
                let w      = geo.size.width
                let chartH = geo.size.height - 18
                let slotW  = w / 30
                let barW   = max((slotW - 5) / 2, 2)

                ZStack(alignment: .topLeading) {
                    Canvas { ctx, _ in
                        for frac in [0.33, 0.67, 1.0] as [CGFloat] {
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: chartH * (1 - frac)))
                            p.addLine(to: CGPoint(x: w, y: chartH * (1 - frac)))
                            ctx.stroke(p, with: .color(.white.opacity(0.05)), lineWidth: 0.5)
                        }
                        for i in 0..<30 {
                            let cx = CGFloat(i) * slotW + slotW / 2
                            if created[i] > 0 {
                                let bh = max(chartH * CGFloat(created[i]) / CGFloat(maxVal), 2)
                                ctx.fill(Path(CGRect(x: cx - barW - 1, y: chartH - bh, width: barW, height: bh)),
                                         with: .color(.blue.opacity(0.5)))
                            }
                            if completed[i] > 0 {
                                let bh = max(chartH * CGFloat(completed[i]) / CGFloat(maxVal), 2)
                                ctx.fill(Path(CGRect(x: cx + 1, y: chartH - bh, width: barW, height: bh)),
                                         with: .color(.green.opacity(0.6)))
                            }
                        }
                    }
                    .frame(height: chartH)

                    ForEach(0..<30, id: \.self) { i in
                        let cx = CGFloat(i) * slotW + slotW / 2
                        Text(shortDate(dates[i]))
                            .font(.system(size: 8))
                            .foregroundColor(.gray.opacity(0.45))
                            .fixedSize()
                            .offset(x: cx - 14, y: chartH + 3)
                    }
                }
            }
            .frame(height: 100)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.white.opacity(0.02))
    }

    // MARK: - Past Panel Helpers

    private func past30StatBox(label: String, count: Int, sub: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 10)).foregroundColor(.gray)
            Text("\(count)").font(.system(size: 30, weight: .bold)).foregroundColor(.white)
            Text(sub).font(.system(size: 9)).foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.25), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func pastTypeBox(_ label: String, count: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(count)").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                Text(label).font(.system(size: 9)).foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(color.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.2), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func avgProcessingDays(_ issues: [JiraIssue]) -> Double? {
        let days = issues.compactMap { issue -> Double? in
            guard let c = issue.created, let r = issue.resolutionDate else { return nil }
            let d = Calendar.current.dateComponents([.day], from: c, to: r).day ?? 0
            return Double(max(d, 0))
        }
        guard !days.isEmpty else { return nil }
        return days.reduce(0, +) / Double(days.count)
    }

    private func dailyCounts(_ issues: [JiraIssue], dateOf: (JiraIssue) -> Date?) -> [Int] {
        var counts = Array(repeating: 0, count: 30)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for issue in issues {
            guard let date = dateOf(issue) else { continue }
            let diff = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: today).day ?? -1
            guard diff >= 0 && diff < 30 else { continue }
            counts[29 - diff] += 1
        }
        return counts
    }

    private func taskBugCounts(_ issues: [JiraIssue]) -> (Int, Int) {
        var task = 0, bug = 0
        for issue in issues {
            switch issue.issueType {
            case "작업", "Task": task += 1
            case "버그", "Bug":  bug  += 1
            default: break
            }
        }
        return (task, bug)
    }

    private func projectCompletions(_ issues: [JiraIssue]) -> [(String, Int)] {
        var byProject: [String: Int] = [:]
        for issue in issues { byProject[issue.projectKey, default: 0] += 1 }
        return Constants.jiraProjects.map { ($0.key, byProject[$0.key] ?? 0) }
    }

    // MARK: - Shared Helpers

    private func filterByProject(_ issues: [JiraIssue]) -> [JiraIssue] {
        selectedProject == Self.allKey ? issues : issues.filter { $0.projectKey == selectedProject }
    }

    private func panelLabel(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(color.opacity(0.8))
            Text(text).font(.system(size: 11, weight: .semibold)).foregroundColor(color.opacity(0.9))
        }
    }

    private static let projectColorMap: [String: Color] =
        Dictionary(uniqueKeysWithValues: Constants.jiraProjects.map { ($0.key, $0.color) })

    private static let projectNameMap: [String: String] =
        Dictionary(uniqueKeysWithValues: Constants.jiraProjects.map { ($0.key, $0.displayName) })

    private func projectColor(_ key: String) -> Color {
        Self.projectColorMap[key] ?? .cyan
    }

    /// projectKey에 대응하는 표시명(별칭이 있으면 별칭, 없으면 key 자체).
    /// 설정에 없는 key가 들어오면 key를 그대로 반환한다.
    private func projectDisplayName(_ key: String) -> String {
        Self.projectNameMap[key] ?? key
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "Highest": return .red
        case "High":    return .orange
        case "Low":     return .blue.opacity(0.7)
        case "Lowest":  return .blue.opacity(0.4)
        default:        return .gray.opacity(0.6)
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MM/dd"; f.locale = Locale(identifier: "ko_KR"); return f
    }()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd"; f.locale = Locale(identifier: "ko_KR"); return f
    }()

    private func shortDate(_ date: Date) -> String {
        Self.shortDateFormatter.string(from: date)
    }

    private func dateRangeText(start: Date?, due: Date) -> String {
        guard let start, !Calendar.current.isDate(start, inSameDayAs: due) else {
            return shortDate(due)
        }
        let startStr = Self.shortDateFormatter.string(from: start)
        let cal = Calendar.current
        if cal.component(.month, from: start) == cal.component(.month, from: due) {
            return "\(startStr)~\(Self.dayFormatter.string(from: due))"
        } else {
            return "\(startStr)~\(Self.shortDateFormatter.string(from: due))"
        }
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
        if let url = URL(string: Constants.jiraBrowseURL + key) {
            NSWorkspace.shared.open(url)
            if let panel = NSApp.keyWindow as? KeyablePanel {
                panel.activatePreviousAppOnClose = false
                panel.orderOut(nil)
            }
        }
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
