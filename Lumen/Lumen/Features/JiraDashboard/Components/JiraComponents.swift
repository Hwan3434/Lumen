import SwiftUI
import AppKit

private typealias P = LumenTokens.Palette

// MARK: - Atoms

/// 프로젝트 표식. 계열 색은 앞의 점에만 쓰고 글자는 무채색(Still 차트 규칙과 같은 방식).
struct ProjectChip: View {
    let key: String

    var body: some View {
        HStack(spacing: LumenTokens.Space.s1 + 2) {
            LumenDot(color: jiraProjectColor(key))
            Text(key)
                .lumenText(.caption, weight: .semibold)
                .foregroundStyle(P.inkMuted)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .overlay(LumenShape.rect(LumenTokens.Radius.xs).strokeBorder(P.borderSubtle, lineWidth: 1))
    }
}

/// 높은 우선순위만 깃발 아이콘으로 표시. 보통·낮음은 자리만 차지한다.
struct PriorityDot: View {
    let priority: String
    var body: some View {
        Group {
            if let tone = jiraPriorityTone(priority) {
                LumenIcon("flag", size: .small)
                    .foregroundStyle(tone.color)
                    .help("우선순위: \(priority)")
                    .accessibilityLabel("우선순위 \(priority)")
            } else {
                Color.clear
            }
        }
        .frame(width: 16, height: 16)
    }
}

struct StatusBadge: View {
    /// 표시 라벨 — 워크스페이스가 보내준 status.name 원문.
    let label: String
    /// 색상 분류용 — Atlassian 표준 statusCategory.
    let category: JiraStatusCategory

    var body: some View {
        let key = JiraStatusKey(category)
        LumenBadge(text: label, tone: key.tone, icon: key.icon)
    }
}

struct DueLabel: View {
    let date: Date
    let isDone: Bool
    var startDate: Date? = nil

    var body: some View {
        let tone = jiraDueTone(date, isDone: isDone)
        HStack(spacing: LumenTokens.Space.s1) {
            switch tone {
            case .past:  LumenIcon("triangle-alert", size: .small)
            case .today: LumenIcon("clock", size: .small)
            default:     EmptyView()
            }
            Text(text)
                .lumenText(.caption)
                .monospacedDigit()
        }
        .foregroundStyle(tone.color)
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

/// 진행 중 표시. Still은 반복 애니메이션을 쓰지 않으므로 정적인 아이콘으로 둔다.
struct InlineSpinner: View {
    var body: some View {
        LumenIcon("rotate-cw", size: .small)
            .foregroundStyle(P.inkFaint)
            .accessibilityLabel("불러오는 중")
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
    @State private var showingPreview = false
    @State private var showingComments = false

    var body: some View {
        Button {
            if isCommandClick { showingComments = true } else { showingPreview = true }
        } label: {
            VStack(alignment: .leading, spacing: LumenTokens.Space.s1 + 2) {
                HStack(spacing: LumenTokens.Space.inline) {
                    PriorityDot(priority: issue.priority)
                    Text(issue.summary)
                        .lumenText(.body, weight: .medium)
                        .foregroundStyle(issue.isDone ? P.inkFaint : P.ink)
                        .strikethrough(issue.isDone)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: LumenTokens.Space.inline) {
                    ProjectChip(key: issue.projectKey)
                    if let number = issueNumber {
                        Text(number)
                            .font(LumenFont.mono(LumenTextStyle.caption.size))
                            .foregroundStyle(P.inkFaint)
                    }
                    Spacer(minLength: 0)
                    if let due = issue.dueDate {
                        DueLabel(date: due, isDone: issue.isDone, startDate: issue.startDate)
                    }
                    StatusBadge(label: issue.status, category: issue.statusCategory)
                }
            }
            .padding(.vertical, LumenTokens.Space.s3)
            .padding(.horizontal, LumenTokens.Space.s3)
            .contentShape(Rectangle())
        }
        .buttonStyle(LumenListRowStyle())
        .onHover { if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        .help("클릭: 미리보기 · ⌘클릭: 댓글")
        .issuePreviewPopover(issueKey: issue.key, isPresented: $showingPreview)
        .issueCommentsPopover(issueKey: issue.key, isPresented: $showingComments)
    }

    /// "ABC-123" → "-123". 앞의 프로젝트 칩이 이미 프로젝트 키를 보여주므로 번호 부분만 이어 붙인다.
    private var issueNumber: String? {
        guard let dash = issue.key.lastIndex(of: "-") else { return nil }
        return String(issue.key[dash...])
    }
}

struct IssueListSection: View {
    let icon: String
    var iconColor: Color = LumenTokens.Palette.inkMuted
    let title: String
    let items: [JiraIssue]
    var emptyText: String = "없어요"
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
            VStack(alignment: .leading, spacing: LumenTokens.Space.inline) {
                IssueListHeader(icon: icon, iconColor: iconColor, title: title, count: items.count)
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
        HStack(spacing: LumenTokens.Space.inline) {
            if showsChevron {
                LumenIcon("chevron-right", size: .small)
                    .foregroundStyle(P.inkFaint)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
            LumenIcon(icon, size: .small)
                .foregroundStyle(iconColor)
            Text(title)
                .lumenText(.label)
                .foregroundStyle(P.inkMuted)
            if let count {
                Text("\(count)")
                    .lumenText(.caption)
                    .monospacedDigit()
                    .foregroundStyle(P.inkFaint)
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
                .lumenText(.label, weight: .regular)
                .foregroundStyle(P.inkFaint)
                .padding(.vertical, LumenTokens.Space.s3)
                .padding(.horizontal, LumenTokens.Space.s4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lumenCard()
        } else {
            LumenList(items, inset: LumenTokens.Space.s1) { IssueRow(issue: $0) }
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
         iconColor: Color = LumenTokens.Palette.inkMuted,
         title: String,
         count: Int? = nil,
         spacing: CGFloat = LumenTokens.Space.inline,
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
                withAnimation(LumenTokens.Motion.easeOut()) { expanded.toggle() }
            } label: {
                IssueListHeader(icon: icon, iconColor: iconColor, title: title,
                                count: count, showsChevron: true, expanded: expanded)
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
    var body: some View {
        LumenEmptyState(icon: "rotate-cw", text: "Jira 데이터를 불러오고 있어요")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct JiraFullPanelError: View {
    let message: String
    var onRetry: () -> Void

    var body: some View {
        LumenBanner(tone: .danger, title: "Jira 데이터를 불러오지 못했어요", message: message) {
            Button(action: onRetry) {
                Label { Text("다시 시도") } icon: { LumenIcon("rotate-cw", size: .small) }
            }
            .buttonStyle(LumenButtonStyle(variant: .secondary, size: .small))
        }
        .frame(maxWidth: 480)
        .padding(LumenTokens.Space.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct JiraFullPanelEmpty: View {
    var body: some View {
        LumenEmptyState(icon: "inbox", text: "보여줄 데이터가 없어요")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Header

/// 통합 Jira 패널의 헤더. 좌측(타이틀+프로젝트), 가운데(탭/임의), 우측(controls + refresh)
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
        HStack(spacing: LumenTokens.Space.group) {
            // 좌측: 타이틀 + 탭/모드 인라인
            HStack(spacing: LumenTokens.Space.group) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Jira 대시보드")
                        .lumenText(.title3)
                        .foregroundStyle(P.ink)
                    Text(Constants.jiraProjects.map(\.displayName).joined(separator: " · "))
                        .lumenText(.caption)
                        .foregroundStyle(P.inkFaint)
                        .lineLimit(1)
                }

                leadingNav()
            }

            Spacer()

            HStack(spacing: LumenTokens.Space.s4) {
                trailingControls()
            }

            HStack(spacing: LumenTokens.Space.inline) {
                if refreshing {
                    HStack(spacing: LumenTokens.Space.s1) {
                        InlineSpinner()
                        Text("새로고침하고 있어요")
                            .lumenText(.caption)
                            .foregroundStyle(P.inkFaint)
                    }
                } else {
                    Text("\(LumenTime.relative(lastUpdated)) 업데이트")
                        .lumenText(.caption)
                        .foregroundStyle(P.inkFaint)
                }

                LumenIconButton(icon: "rotate-cw", label: "새로고침", variant: .secondary, action: onRefresh)
            }
        }
        .padding(.horizontal, LumenTokens.Space.pad)
        .frame(height: 72)
    }
}

/// 범례 항목: 계열 색 표식(점) + 무채색 글자.
struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: LumenTokens.Space.s1 + 2) {
            LumenDot(color: color)
            Text(label)
                .lumenText(.caption)
                .foregroundStyle(P.inkMuted)
        }
    }
}
