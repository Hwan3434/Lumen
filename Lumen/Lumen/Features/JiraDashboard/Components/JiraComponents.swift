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
    /// 표시 라벨 — 워크스페이스가 보내준 status.name 원문.
    let label: String
    /// 색상 분류용 — Atlassian 표준 statusCategory.
    let category: JiraStatusCategory

    var body: some View {
        let key = JiraStatusKey(category)
        Text(label)
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

/// 클릭 시점의 ⌘ 여부. 이슈를 여는 지점이 목록·월간·주간·오늘 일정으로 흩어져 있어
/// 각 호출부에서 제스처를 새로 짜는 대신 클릭 순간의 수정자 플래그를 읽는다.
@MainActor
var isCommandClick: Bool {
    NSEvent.modifierFlags.contains(.command)
}

struct IssueRow: View {
    let issue: JiraIssue
    @State private var hovered = false
    @State private var showingPreview = false
    @State private var showingComments = false

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ProjectChip(key: issue.projectKey)
                if let number = issueNumber {
                    Text(number)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }
            }
            PriorityDot(priority: issue.priority)
            Text(issue.summary)
                .font(.system(size: 12))
                .foregroundStyle(textColor)
                .strikethrough(issue.isDone)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let due = issue.dueDate {
                DueLabel(date: due, isDone: issue.isDone, startDate: issue.startDate)
            }
            StatusBadge(label: issue.status, category: issue.statusCategory)
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(hovered ? Color.white.opacity(0.04) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0; if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        .onTapGesture {
            if isCommandClick { showingComments = true } else { showingPreview = true }
        }
        .help("클릭: 미리보기 · ⌘클릭: 댓글")
        .issuePreviewPopover(issueKey: issue.key, isPresented: $showingPreview)
        .issueCommentsPopover(issueKey: issue.key, isPresented: $showingComments)
    }

    private var textColor: Color {
        issue.isDone ? LumenTokens.TextColor.muted : LumenTokens.TextColor.primary
    }

    /// "ABC-123" → "-123". 앞의 프로젝트 칩이 이미 프로젝트 키를 보여주므로 번호 부분만 이어 붙인다.
    private var issueNumber: String? {
        guard let dash = issue.key.lastIndex(of: "-") else { return nil }
        return String(issue.key[dash...])
    }
}

struct IssueListSection: View {
    let icon: String
    var iconColor: Color = LumenTokens.TextColor.muted
    let title: String
    let items: [JiraIssue]
    var emptyText: String = "없음"
    var hideWhenEmpty: Bool = false
    /// 지정하면 헤더를 눌러 접을 수 있고, 펼침 여부가 이 키로 기억된다. nil이면 항상 펼친 고정 섹션.
    var collapseKey: String? = nil

    var body: some View {
        if hideWhenEmpty && items.isEmpty {
            EmptyView()
        } else if let collapseKey {
            CollapsibleSection(storageKey: collapseKey, icon: icon, iconColor: iconColor,
                               title: title, count: items.count) {
                IssueListItems(items: items, emptyText: emptyText)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                IssueListHeader(icon: icon, iconColor: iconColor, title: title, count: items.count)
                    .padding(.horizontal, 4)
                IssueListItems(items: items, emptyText: emptyText)
            }
        }
    }
}

/// 대시보드 섹션 헤더의 공통 모양 — 아이콘 + 제목 + (개수).
private struct IssueListHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    /// nil이면 개수를 숨긴다 — 셀 수 있는 목록이 아닌 섹션용.
    let count: Int?
    /// 접기 가능한 섹션에서만 회전하는 chevron을 앞에 붙인다.
    var showsChevron: Bool = false
    var expanded: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .frame(width: 8)
            }
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.secondary)
            if let count {
                Text("\(count)")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
        }
    }
}

private struct IssueListItems: View {
    let items: [JiraIssue]
    let emptyText: String

    var body: some View {
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

/// 대시보드 섹션의 공통 껍데기 — 헤더를 눌러 접고, 펼침 여부를 storageKey로 기억한다.
/// 이슈 목록뿐 아니라 백로그·스프린트·에픽처럼 내용이 임의인 섹션도 감쌀 수 있다.
struct CollapsibleSection<Content: View>: View {
    @AppStorage private var expanded: Bool
    private let icon: String
    private let iconColor: Color
    private let title: String
    private let count: Int?
    private let spacing: CGFloat
    private let content: () -> Content

    init(storageKey: String,
         icon: String,
         iconColor: Color = LumenTokens.TextColor.muted,
         title: String,
         count: Int? = nil,
         spacing: CGFloat = 6,
         @ViewBuilder content: @escaping () -> Content) {
        // 기본은 펼침 — 처음 보는 사용자에게 대시보드가 비어 보이지 않도록.
        _expanded = AppStorage(wrappedValue: true, storageKey)
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.count = count
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) { expanded.toggle() }
            } label: {
                IssueListHeader(icon: icon, iconColor: iconColor, title: title,
                                count: count, showsChevron: true, expanded: expanded)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(expanded ? "접기" : "펼치기")

            if expanded { content() }
        }
    }
}

/// 섹션 펼침 상태 저장 키. 한곳에 모아 중복·오타를 막는다.
enum JiraSectionKey {
    /// 1.0.104에서 나간 키 — 값을 바꾸면 사용자가 접어둔 상태가 초기화되므로 그대로 둔다.
    static let overdue  = "jiraOverdueSectionExpanded"
    static let thisWeek = "jiraSectionThisWeekExpanded"
    static let highest  = "jiraSectionHighestExpanded"
    static let nextWeek = "jiraSectionNextWeekExpanded"
    static let backlog  = "jiraSectionBacklogExpanded"
    static let sprints  = "jiraSectionSprintsExpanded"
    static let epics    = "jiraSectionEpicsExpanded"
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

/// 통합 Jira 패널의 56pt 헤더. 좌측(타이틀+프로젝트), 가운데(탭/임의), 우측(controls + refresh)
/// 세 영역을 가진다. 가운데와 우측-controls는 호출자가 ViewBuilder로 채운다 — 탭별로 다른
/// 컨트롤(범례 / 필터 칩 등)을 노출하기 위함.
struct JiraHeader<LeadingNav: View, TrailingControls: View>: View {
    let lastUpdated: Date
    let refreshing: Bool
    var onRefresh: () -> Void
    /// 좌측 타이틀 옆에 인라인으로 깔리는 네비게이션 영역 — 탭바 + (캘린더 모드일 때) 모드 토글.
    @ViewBuilder var leadingNav: () -> LeadingNav
    @ViewBuilder var trailingControls: () -> TrailingControls

    var body: some View {
        HStack(spacing: 0) {
            // 좌측: 타이틀 + 탭/모드 인라인
            HStack(spacing: 14) {
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

                leadingNav()
            }

            Spacer()

            HStack(spacing: 12) {
                trailingControls()
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
