import SwiftUI
import AppKit

/// Jira 대시보드 메인 뷰. 1160×840pt 글래스 패널.
///
/// 레이아웃: 56pt 헤더 → 3-column body (past 280 / present 480 / future 320)
///         → 102pt 하단 trend 차트.
///
/// 시간 축(과거 / 현재 / 미래)을 공간에 그대로 매핑해 사용자가 클릭 없이
/// 시선만 옮겨 정보를 스캔할 수 있게 한다.
struct JiraDashboardView: View {
    private static let allKey = "ALL"
    private var service: JiraService { JiraService.shared }
    @State private var selectedProject: String = Self.allKey

    var body: some View {
        ZStack {
            LumenGlassBackground(radius: LumenTokens.Radius.window)

            if service.isLoading && service.data == nil {
                FullPanelLoading()
            } else if let msg = service.errorMessage, service.data == nil {
                FullPanelError(message: msg) {
                    Task { await service.fetch(force: true) }
                }
            } else if let data = service.data {
                content(data)
            } else {
                FullPanelEmpty()
            }
        }
        .frame(width: 1160, height: 840)
        .clipShape(RoundedRectangle(cornerRadius: LumenTokens.Radius.window, style: .continuous))
        .onAppear { Task { await service.fetch() } }
    }

    @ViewBuilder
    private func content(_ data: JiraDashboardData) -> some View {
        VStack(spacing: 0) {
            JiraHeader(
                lastUpdated: data.lastUpdated,
                refreshing: service.isLoading,
                onRefresh: { Task { await service.fetch(force: true) } }
            )
            LumenHairline()
            HStack(spacing: 0) {
                PastColumn(data: data)
                Rectangle().fill(LumenTokens.divider).frame(width: 0.5)
                PresentColumn(
                    data: data,
                    selectedProject: $selectedProject
                )
                Rectangle().fill(LumenTokens.divider).frame(width: 0.5)
                FutureColumn(data: data)
            }
            .frame(maxHeight: .infinity)
            TrendChart(
                created: data.createdLast30,
                completed: data.completedLast30
            )
        }
    }
}

// MARK: - Header

private struct JiraHeader: View {
    let lastUpdated: Date
    let refreshing: Bool
    var onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Identity
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(red: 0x5B/255, green: 0xA8/255, blue: 1.0).opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color(red: 0x5B/255, green: 0xA8/255, blue: 1.0).opacity(0.30), lineWidth: 0.5)
                        )
                    Image(systemName: "rhombus.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0x5B/255, green: 0xA8/255, blue: 1.0))
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Jira 대시보드")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LumenTokens.TextColor.primary)
                    Text(Constants.jiraProjects.map(\.displayName).joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Trend legend mirror
            HStack(spacing: 12) {
                LegendDot(color: LumenTokens.JiraTrendTone.created, label: "생성")
                LegendDot(color: LumenTokens.JiraTrendTone.completed, label: "완료")
            }
            .padding(.trailing, 18)

            // Last updated + refresh
            HStack(spacing: 10) {
                if refreshing {
                    HStack(spacing: 6) {
                        InlineSpinner()
                        Text("새로고침 중…")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(LumenTokens.Accent.violetSoft)
                    }
                } else {
                    Text("\(relativeTime(lastUpdated)) 업데이트")
                        .font(.system(size: 11.5))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LumenTokens.TextColor.secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.02))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(Color.white.opacity(0.012))
    }

    private func relativeTime(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "방금" }
        if mins < 60 { return "\(mins)분 전" }
        return "\(mins / 60)시간 전"
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.4), radius: 3)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
    }
}

// MARK: - Issue mapping helpers

/// "완료"/"진행중"/... 한국어 status string을 토큰 색·배경으로 매핑.
private enum JiraStatusKey {
    case todo, inProgress, onHold, waiting, completed, cancelled

    init(_ status: String) {
        switch status {
        case "완료":   self = .completed
        case "진행중": self = .inProgress
        case "보류":   self = .onHold
        case "대기":   self = .waiting
        case "취소":   self = .cancelled
        default:       self = .todo
        }
    }

    var label: String {
        switch self {
        case .todo: return "할 일"
        case .inProgress: return "진행중"
        case .onHold: return "보류"
        case .waiting: return "대기"
        case .completed: return "완료"
        case .cancelled: return "취소"
        }
    }

    var fg: Color {
        switch self {
        case .todo:       return LumenTokens.JiraStatusTone.todoFg
        case .inProgress: return LumenTokens.JiraStatusTone.inProgressFg
        case .onHold:     return LumenTokens.JiraStatusTone.onHoldFg
        case .waiting:    return LumenTokens.JiraStatusTone.waitingFg
        case .completed:  return LumenTokens.JiraStatusTone.completedFg
        case .cancelled:  return LumenTokens.JiraStatusTone.cancelledFg
        }
    }

    var bg: Color {
        switch self {
        case .todo:       return LumenTokens.JiraStatusTone.todoBg
        case .inProgress: return LumenTokens.JiraStatusTone.inProgressBg
        case .onHold:     return LumenTokens.JiraStatusTone.onHoldBg
        case .waiting:    return LumenTokens.JiraStatusTone.waitingBg
        case .completed:  return LumenTokens.JiraStatusTone.completedBg
        case .cancelled:  return LumenTokens.JiraStatusTone.cancelledBg
        }
    }
}

private func priorityColor(_ priority: String) -> Color {
    switch priority {
    case "Highest": return LumenTokens.JiraPriorityTone.highest
    case "High":    return LumenTokens.JiraPriorityTone.high
    case "Low":     return LumenTokens.JiraPriorityTone.low
    case "Lowest":  return LumenTokens.JiraPriorityTone.lowest
    default:        return LumenTokens.JiraPriorityTone.medium
    }
}

private enum DueTone {
    case past, today, future, done

    var color: Color {
        switch self {
        case .past:   return LumenTokens.ErrorTone.icon
        case .today:  return LumenTokens.Accent.amber
        case .future: return LumenTokens.TextColor.muted
        case .done:   return LumenTokens.TextColor.muted.opacity(0.55)
        }
    }
}

private func dueTone(_ date: Date, isDone: Bool) -> DueTone {
    if isDone { return .done }
    if date < Date() { return .past }
    if Calendar.current.isDateInToday(date) { return .today }
    return .future
}

private func projectChipAlias(for key: String) -> String {
    // 사용자가 alias를 입력했더라도 chip은 짧은 식별자(key)를 그대로 노출 — 정직하고 일관됨.
    key
}

private func projectColor(_ key: String) -> Color {
    Constants.jiraProjects.first { $0.key == key }?.color ?? LumenTokens.Accent.violetSoft
}

private func projectDisplayName(_ key: String) -> String {
    Constants.jiraProjects.first { $0.key == key }?.displayName ?? key
}

// MARK: - Atomic components

private struct ProjectChip: View {
    let key: String
    var size: ChipSize = .small

    enum ChipSize { case small, medium }

    var body: some View {
        let color = projectColor(key)
        let h: CGFloat = size == .small ? 16 : 20
        let px: CGFloat = size == .small ? 6 : 8
        let fs: CGFloat = size == .small ? 10 : 11

        Text(projectChipAlias(for: key))
            .font(.system(size: fs, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, px)
            .frame(height: h)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(color.opacity(0.33), lineWidth: 0.5)
                    )
            )
    }
}

private struct PriorityDot: View {
    let priority: String
    var body: some View {
        Circle().fill(priorityColor(priority)).frame(width: 5, height: 5)
    }
}

private struct StatusBadge: View {
    let status: String

    var body: some View {
        let key = JiraStatusKey(status)
        Text(key.label)
            .font(.system(size: 10, weight: .medium))
            .tracking(0.1)
            .foregroundStyle(key.fg)
            .padding(.horizontal, 6)
            .frame(height: 16)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(key.bg)
            )
    }
}

private struct DueLabel: View {
    let date: Date
    let isDone: Bool
    var startDate: Date? = nil

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, design: .monospaced))
            .tracking(0.2)
            .foregroundStyle(dueTone(date, isDone: isDone).color)
    }

    private var text: String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        if let start = startDate, !cal.isDate(start, inSameDayAs: date) {
            let startStr = f.string(from: start)
            if cal.component(.month, from: start) == cal.component(.month, from: date) {
                let dayF = DateFormatter(); dayF.dateFormat = "dd"
                return "\(startStr)~\(dayF.string(from: date))"
            } else {
                return "\(startStr)~\(f.string(from: date))"
            }
        }
        return f.string(from: date)
    }
}

private struct InlineSpinner: View {
    @State private var angle: Double = 0
    var size: CGFloat = 11

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(LumenTokens.Accent.violetSoft, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(angle))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

// MARK: - Issue row & list

private struct IssueRow: View {
    let issue: JiraIssue
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 8) {
            ProjectChip(key: issue.projectKey)
            PriorityDot(priority: issue.priority)
            Text(issue.summary)
                .font(.system(size: 12))
                .foregroundStyle(textColor)
                .strikethrough(issue.isCancelled)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let due = issue.dueDate {
                DueLabel(date: due, isDone: issue.isDone, startDate: issue.startDate)
            }
            StatusBadge(status: issue.status)
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(hovered ? Color.white.opacity(0.04) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0; if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        .onTapGesture { openJira(issue.key) }
    }

    private var textColor: Color {
        switch JiraStatusKey(issue.status) {
        case .completed, .cancelled: return LumenTokens.TextColor.muted
        default:                     return LumenTokens.TextColor.primary
        }
    }
}

private struct IssueListSection: View {
    let icon: String
    var iconColor: Color = LumenTokens.TextColor.muted
    let title: String
    let items: [JiraIssue]
    var emptyText: String = "없음"
    var hideWhenEmpty: Bool = false

    var body: some View {
        if hideWhenEmpty && items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(iconColor)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LumenTokens.TextColor.secondary)
                    Text("\(items.count)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }
                .padding(.horizontal, 4)

                if items.isEmpty {
                    Text(emptyText)
                        .font(.system(size: 11))
                        .italic()
                        .foregroundStyle(LumenTokens.TextColor.muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 1) {
                        ForEach(items) { IssueRow(issue: $0) }
                    }
                }
            }
        }
    }
}

// MARK: - Past column

private struct PastColumn: View {
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

                IssueListSection(
                    icon: "pause.circle",
                    iconColor: LumenTokens.Accent.amber,
                    title: "차단됨 (보류·대기)",
                    items: data.blockedIssues,
                    emptyText: "차단된 이슈 없음"
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
            case "작업", "Task": task += 1
            case "버그", "Bug":  bug += 1
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

private struct StatBox: View {
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

private struct ProjectBar: View {
    let key: String
    let count: Int
    let maxCount: Int

    var body: some View {
        let color = projectColor(key)
        HStack(spacing: 8) {
            Text(projectDisplayName(key))
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

// MARK: - Present column

private struct PresentColumn: View {
    let data: JiraDashboardData
    @Binding var selectedProject: String
    private static let allKey = "ALL"

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

private struct ProjectTabBar: View {
    @Binding var selected: String
    private static let allKey = "ALL"

    var body: some View {
        HStack(spacing: 4) {
            tab(key: Self.allKey, color: LumenTokens.TextColor.secondary, label: "ALL", index: 1)
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
            ? (key == Self.allKey ? Color.white.opacity(0.06) : color.opacity(0.10))
            : .clear
        let stroke: Color = active
            ? (key == Self.allKey ? LumenTokens.strokeStrong : color.opacity(0.33))
            : .clear
        let fg: Color = active
            ? (key == Self.allKey ? LumenTokens.TextColor.primary : color)
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

private struct StatusCellData {
    let key: JiraStatusKey
    let label: String
    let icon: String
    let count: Int
}

private struct StatusGrid: View {
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

private struct StatusCard: View {
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

// MARK: - Future column

private struct FutureColumn: View {
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

    private var epicsSection: some View {
        let epics = data.epicInfos.filter { $0.dueDate != nil }
        return Group {
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
}

private struct BacklogBox: View {
    let key: String
    let count: Int

    var body: some View {
        let color = projectColor(key)
        VStack(alignment: .leading, spacing: 2) {
            Text(projectDisplayName(key))
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

private struct SprintCard: View {
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
        let f = DateFormatter(); f.dateFormat = "MM/dd"
        return f.string(from: date)
    }
}

private struct EpicRow: View {
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

// MARK: - Trend chart

private struct TrendChart: View {
    let created: [JiraIssue]
    let completed: [JiraIssue]

    var body: some View {
        let createdCounts = dailyCounts(created, dateOf: { $0.created })
        let completedCounts = dailyCounts(completed, dateOf: { $0.resolutionDate })
        let max = Swift.max(1, (createdCounts + completedCounts).max() ?? 1)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dates = (0..<30).map { cal.date(byAdding: .day, value: $0 - 29, to: today) ?? today }

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                Text("30일 일별 추이")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.0)
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .textCase(.uppercase)
            }

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // Gridlines at 33% / 67%
                    ForEach([0.33, 0.67], id: \.self) { frac in
                        Path { p in
                            let y = geo.size.height * (1 - CGFloat(frac))
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(LumenTokens.JiraTrendTone.grid)
                    }

                    // Bars
                    Canvas { ctx, size in
                        let slotW = size.width / 30
                        let barW = Swift.max((slotW - 5) / 2, 2)
                        for i in 0..<30 {
                            let cx = CGFloat(i) * slotW + slotW / 2
                            if createdCounts[i] > 0 {
                                let bh = Swift.max(size.height * CGFloat(createdCounts[i]) / CGFloat(max), 1.5)
                                ctx.fill(
                                    Path(roundedRect: CGRect(x: cx - barW - 1, y: size.height - bh, width: barW, height: bh),
                                         cornerSize: CGSize(width: 1.5, height: 1.5)),
                                    with: .color(LumenTokens.JiraTrendTone.created.opacity(0.85))
                                )
                            }
                            if completedCounts[i] > 0 {
                                let bh = Swift.max(size.height * CGFloat(completedCounts[i]) / CGFloat(max), 1.5)
                                ctx.fill(
                                    Path(roundedRect: CGRect(x: cx + 1, y: size.height - bh, width: barW, height: bh),
                                         cornerSize: CGSize(width: 1.5, height: 1.5)),
                                    with: .color(LumenTokens.JiraTrendTone.completed.opacity(0.85))
                                )
                            }
                        }
                    }
                }
            }
            .frame(height: 60)

            HStack(spacing: 0) {
                ForEach(0..<30) { i in
                    if i % 5 == 0 || i == 29 {
                        Text(short(dates[i]))
                            .font(.system(size: 8.5, design: .monospaced))
                            .tracking(0.2)
                            .foregroundStyle(LumenTokens.TextColor.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 12)
        }
        .padding(EdgeInsets(top: 8, leading: 18, bottom: 12, trailing: 18))
        .frame(height: 102)
        .background(Color.black.opacity(0.10))
        .overlay(alignment: .top) {
            Rectangle().fill(LumenTokens.divider).frame(height: 0.5)
        }
    }

    private func dailyCounts(_ issues: [JiraIssue], dateOf: (JiraIssue) -> Date?) -> [Int] {
        var counts = Array(repeating: 0, count: 30)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for i in issues {
            guard let date = dateOf(i) else { continue }
            let diff = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: today).day ?? -1
            guard diff >= 0 && diff < 30 else { continue }
            counts[29 - diff] += 1
        }
        return counts
    }

    private func short(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MM/dd"
        return f.string(from: date)
    }
}

// MARK: - Loading / Error / Empty overlays

private struct FullPanelLoading: View {
    @State private var angle: Double = 0

    var body: some View {
        VStack(spacing: 14) {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(LumenTokens.Accent.violetSoft, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(angle))
                .onAppear {
                    withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                }
            Text("Jira 데이터 불러오는 중…")
                .font(.system(size: 13))
                .foregroundStyle(LumenTokens.TextColor.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FullPanelError: View {
    let message: String
    var onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LumenTokens.ErrorTone.icon)
                Text("불러오기 실패")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LumenTokens.ErrorTone.title)
            }
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(LumenTokens.TextColor.secondary)
                .lineSpacing(3)

            Button(action: onRetry) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("다시 시도")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .foregroundStyle(LumenTokens.ErrorTone.title)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LumenTokens.ErrorTone.bg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(LumenTokens.ErrorTone.border, lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22))
        .frame(maxWidth: 480)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(LumenTokens.ErrorTone.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(LumenTokens.ErrorTone.border, lineWidth: 0.5)
                )
        )
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FullPanelEmpty: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 20))
                .foregroundStyle(LumenTokens.TextColor.muted)
            Text("데이터 없음")
                .font(.system(size: 12))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helpers

private func openJira(_ key: String) {
    if let url = URL(string: Constants.jiraBrowseURL + key) {
        NSWorkspace.shared.open(url)
        if let panel = NSApp.keyWindow as? KeyablePanel {
            panel.activatePreviousAppOnClose = false
            panel.orderOut(nil)
        }
    }
}
