import SwiftUI
import AppKit

// MARK: - Atoms

struct ProjectChip: View {
    let key: String

    var body: some View {
        let color = jiraProjectColor(key)
        Text(key)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .frame(height: 16)
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

struct PriorityDot: View {
    let priority: String
    var body: some View {
        Circle().fill(jiraPriorityColor(priority)).frame(width: 5, height: 5)
    }
}

struct StatusBadge: View {
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

struct DueLabel: View {
    let date: Date
    let isDone: Bool
    var startDate: Date? = nil

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, design: .monospaced))
            .tracking(0.2)
            .foregroundStyle(jiraDueTone(date, isDone: isDone).color)
    }

    private var text: String {
        let cal = Calendar.current
        let f = LumenDateFormat.monthDay
        if let start = startDate, !cal.isDate(start, inSameDayAs: date) {
            let startStr = f.string(from: start)
            if cal.component(.month, from: start) == cal.component(.month, from: date) {
                return "\(startStr)~\(LumenDateFormat.dayOnly.string(from: date))"
            } else {
                return "\(startStr)~\(f.string(from: date))"
            }
        }
        return f.string(from: date)
    }
}

struct InlineSpinner: View {
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

struct IssueRow: View {
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

struct IssueListSection: View {
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

// MARK: - Full-panel overlays

struct JiraFullPanelLoading: View {
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

struct JiraFullPanelError: View {
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

struct JiraFullPanelEmpty: View {
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

// MARK: - Header

struct JiraHeader: View {
    let lastUpdated: Date
    let refreshing: Bool
    var onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 0) {
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

            HStack(spacing: 12) {
                LegendDot(color: LumenTokens.JiraTrendTone.created, label: "생성")
                LegendDot(color: LumenTokens.JiraTrendTone.completed, label: "완료")
            }
            .padding(.trailing, 18)

            HStack(spacing: 10) {
                if refreshing {
                    HStack(spacing: 6) {
                        InlineSpinner()
                        Text("새로고침 중…")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(LumenTokens.Accent.violetSoft)
                    }
                } else {
                    Text("\(LumenTime.relative(lastUpdated)) 업데이트")
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
}

struct LegendDot: View {
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
