import SwiftUI

private typealias P = LumenTokens.Palette

/// 통합 Jira 패널 메인 뷰 — 1320×860pt 패널, 통합 헤더 + 탭 컨텐츠.
/// 탭: 대시보드 / 캘린더(월간·주간 토글). 모두 같은 JiraService.shared 데이터 위에서.
///
/// 단축키: ⌘1 = 대시보드, ⌘2 = 캘린더(월간), ⌘3 = 캘린더(주간).
/// ⌘2/⌘3는 같은 캘린더 탭으로 진입하되 모드만 다르게 — 사용자가 잘 쓰던 ⌘1/⌘2/⌘3을 보존.
struct JiraDashboardView: View {
    @Environment(JiraService.self) private var service
    @Environment(LocalEventStore.self) private var localStore
    @Environment(EventKitService.self) private var eventKitService
    
    @State private var activeTab: JiraTab = .dashboard
    @State private var calendarMode: CalendarMode = .month
    @State private var selectedProject: String = PresentColumn.allKey
    @State private var filter: CalendarFilter = {
        var f = CalendarFilter()
        f.disabledProjectKeys = CredentialsStore.shared.calendarDisabledProjectKeys
        return f
    }()
    @State private var anchorDate: Date = Date()
    /// 캘린더 탭 진입/모드 전환 시 increment — 자식 view가 onChange로 받아 오늘로 점프.
    /// ZStack+opacity로 항상 mount된 채라 onAppear가 첫 한 번만 호출되는 부작용을 보완.
    @State private var monthResetToken: Int = 0
    @State private var weekResetToken: Int = 0

    var body: some View {
        ZStack {
            LumenPanelBackground()

            if service.isLoading && service.data == nil {
                JiraFullPanelLoading()
            } else if let msg = service.errorMessage, service.data == nil {
                JiraFullPanelError(message: msg) {
                    Task { await service.fetch(force: true) }
                }
            } else if let data = service.data {
                content(data)
            } else {
                JiraFullPanelEmpty()
            }
        }
        .frame(width: 1320, height: 860)
        .clipShape(LumenShape.rect(LumenTokens.Radius.xl))
        .onAppear {
            Task { await service.fetch() }
            Task { await eventKitService.requestAccessAndFetch() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .jiraSwitchTab)) { note in
            guard let route = note.object as? JiraRoute else { return }
            switch route {
            case .dashboard:
                activeTab = .dashboard
            case .calendarMonth:
                activeTab = .calendar
                calendarMode = .month
            case .calendarWeek:
                activeTab = .calendar
                calendarMode = .week
            }
        }
        .onChange(of: activeTab) { _, newTab in
            // 캘린더 탭 진입 시 현재 모드의 view를 오늘로 리셋.
            if newTab == .calendar { fireReset() }
        }
        .onChange(of: calendarMode) { _, _ in
            if activeTab == .calendar { fireReset() }
        }
    }

    private func fireReset() {
        switch calendarMode {
        case .month: monthResetToken &+= 1
        case .week:  weekResetToken &+= 1
        }
    }

    @ViewBuilder
    private func content(_ data: JiraDashboardData) -> some View {
        VStack(spacing: 0) {
            JiraHeader(
                lastUpdated: data.lastUpdated,
                refreshing: service.isLoading,
                onRefresh: { Task { await service.fetch(force: true) } },
                leadingNav: {
                    HStack(spacing: LumenTokens.Space.inline) {
                        JiraTabBar(active: $activeTab)
                        if activeTab == .calendar {
                            CalendarModeToggle(mode: $calendarMode)
                        }
                    }
                },
                trailingControls: { trailingControls }
            )
            LumenHairline()
            tabBody(data)
        }
    }

    @ViewBuilder
    private var trailingControls: some View {
        switch activeTab {
        case .dashboard:
            LegendDot(color: P.chart1, label: "생성")
            LegendDot(color: P.chart2, label: "완료")
        case .calendar:
            FilterChip(label: "캘린더",  color: CalendarItemKind.googleCalendar.color, isOn: $filter.showGoogleCalendar)
            FilterChip(label: "에픽",   color: CalendarItemKind.epic.color,           isOn: $filter.showEpic)
            FilterChip(label: "스프린트", color: CalendarItemKind.sprint.color,         isOn: $filter.showSprint)
            FilterChip(label: "태스크",  color: CalendarItemKind.task.color,           isOn: $filter.showTask)
        }
    }

    /// 세 view를 모두 mount된 채로 두고 active만 보여 준다 — 모드 전환 시 onAppear 재호출에 의한
    /// scroll 깜빡임을 없앰. resetToTodayToken으로 명시적 리셋만.
    @ViewBuilder
    private func tabBody(_ data: JiraDashboardData) -> some View {
        let calendarItems = visibleCalendarItems(data, includeLocal: true)
        let monthVisible = (activeTab == .calendar && calendarMode == .month)
        let weekVisible  = (activeTab == .calendar && calendarMode == .week)

        ZStack {
            DashboardContent(data: data, selectedProject: $selectedProject)
                .opacity(activeTab == .dashboard ? 1 : 0)
                .allowsHitTesting(activeTab == .dashboard)

            MonthGridView(items: calendarItems, showLocal: $filter.showLocal, disabledProjectKeys: $filter.disabledProjectKeys, showGoogleCalendar: filter.showGoogleCalendar, resetToTodayToken: monthResetToken)
                .padding(.horizontal, LumenTokens.Space.pad)
                .padding(.bottom, LumenTokens.Space.pad)
                .opacity(monthVisible ? 1 : 0)
                .allowsHitTesting(monthVisible)

            TimelineView(items: calendarItems, anchorDate: $anchorDate, showLocal: $filter.showLocal, disabledProjectKeys: $filter.disabledProjectKeys, showGoogleCalendar: filter.showGoogleCalendar, resetToTodayToken: weekResetToken)
                .padding(.horizontal, LumenTokens.Space.pad)
                .padding(.bottom, LumenTokens.Space.pad)
                .opacity(weekVisible ? 1 : 0)
                .allowsHitTesting(weekVisible)
        }
    }

    private func visibleCalendarItems(_ data: JiraDashboardData, includeLocal: Bool) -> [CalendarItem] {
        CalendarAdapter.buildItems(
            from: data,
            localEvents: includeLocal ? localStore.events : [],
            externalEvents: includeLocal ? eventKitService.events : []
        ).filter { filter.passes($0) }
    }
}

// MARK: - CalendarModeToggle
//
// 캘린더 탭에서 월간/주간 전환. 헤더의 탭 옆.

struct CalendarModeToggle: View {
    @Binding var mode: CalendarMode

    var body: some View {
        LumenSegmentedControl(
            items: CalendarMode.allCases.map { .init(value: $0, label: $0.label, icon: $0.iconName) },
            selection: $mode
        )
    }
}

// MARK: - FilterChip

/// 켜고 끄는 필터. 계열 색은 점에만 쓰고, 꺼지면 점을 비운다(색만으로 상태를 나타내지 않도록 체크 아이콘도 함께).
struct FilterChip: View {
    let label: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: LumenTokens.Space.s1 + 2) {
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .background(Circle().fill(isOn ? color : .clear))
                    .frame(width: 10, height: 10)
                Text(label)
                    .lumenText(.label)
                    .foregroundStyle(isOn ? P.ink : P.inkFaint)
                if isOn {
                    LumenIcon("check", size: .small)
                        .foregroundStyle(P.inkMuted)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(isOn ? P.surface : .clear, in: LumenShape.rect(LumenTokens.Radius.md))
            .overlay(LumenShape.rect(LumenTokens.Radius.md).strokeBorder(P.borderSubtle, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "켜짐" : "꺼짐")
    }
}
