import SwiftUI

/// 통합 Jira 패널 메인 뷰 — 1160×840pt 글래스 패널, 56pt 통합 헤더 + 탭 컨텐츠.
/// 탭: 대시보드 / 캘린더(월간·주간 토글). 모두 같은 JiraService.shared 데이터 위에서.
///
/// 단축키: ⌘1 = 대시보드, ⌘2 = 캘린더(월간), ⌘3 = 캘린더(주간).
/// ⌘2/⌘3는 같은 캘린더 탭으로 진입하되 모드만 다르게 — 사용자가 잘 쓰던 ⌘1/⌘2/⌘3을 보존.
struct JiraDashboardView: View {
    private var service: JiraService { JiraService.shared }
    @State private var activeTab: JiraTab = .dashboard
    @State private var calendarMode: CalendarMode = .month
    @State private var selectedProject: String = PresentColumn.allKey
    @State private var filter = CalendarFilter()
    @State private var anchorDate: Date = Date()
    /// LocalEventStore / EventKitService 변경을 감지해 캘린더 막대도 즉시 재렌더 되게.
    @State private var localStore = LocalEventStore.shared
    @State private var eventKitService = EventKitService.shared
    /// 캘린더 탭 진입/모드 전환 시 increment — 자식 view가 onChange로 받아 오늘로 점프.
    /// ZStack+opacity로 항상 mount된 채라 onAppear가 첫 한 번만 호출되는 부작용을 보완.
    @State private var monthResetToken: Int = 0
    @State private var weekResetToken: Int = 0

    var body: some View {
        ZStack {
            LumenGlassBackground(radius: LumenTokens.Radius.window)

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
        .frame(width: 1160, height: 840)
        .clipShape(RoundedRectangle(cornerRadius: LumenTokens.Radius.window, style: .continuous))
        .onAppear {
            Task { await service.fetch() }
            Task { await EventKitService.shared.requestAccessAndFetch() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .jiraSwitchTab)) { note in
            // post(object: 0/1/2) — ⌘1/⌘2/⌘3.
            //   0 → 대시보드
            //   1 → 캘린더(월간 모드로 진입)
            //   2 → 캘린더(주간 모드로 진입)
            guard let idx = note.object as? Int else { return }
            switch idx {
            case 0:
                activeTab = .dashboard
            case 1:
                activeTab = .calendar
                calendarMode = .month
            case 2:
                activeTab = .calendar
                calendarMode = .week
            default:
                break
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
                    HStack(spacing: 8) {
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
            LegendDot(color: LumenTokens.JiraTrendTone.created, label: "생성")
            LegendDot(color: LumenTokens.JiraTrendTone.completed, label: "완료")
        case .calendar:
            FilterChip(label: "캘린더",  color: LumenTokens.Accent.teal,           isOn: $filter.showGoogleCalendar)
            FilterChip(label: "에픽",   color: LumenTokens.Accent.violet,          isOn: $filter.showEpic)
            FilterChip(label: "스프린트", color: LumenTokens.Accent.amber,          isOn: $filter.showSprint)
            FilterChip(label: "태스크",  color: LumenTokens.TextColor.secondary,    isOn: $filter.showTask)
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

            MonthGridView(items: calendarItems, resetToTodayToken: monthResetToken)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .opacity(monthVisible ? 1 : 0)
                .allowsHitTesting(monthVisible)

            TimelineView(items: calendarItems, anchorDate: $anchorDate, resetToTodayToken: weekResetToken)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .opacity(weekVisible ? 1 : 0)
                .allowsHitTesting(weekVisible)
        }
    }

    private func visibleCalendarItems(_ data: JiraDashboardData, includeLocal: Bool) -> [CalendarItem] {
        CalendarAdapter.buildItems(from: data, includeLocal: includeLocal).filter { filter.passes($0) }
    }
}

// MARK: - CalendarModeToggle
//
// 캘린더 탭에서 월간/주간 전환. 헤더 우측, 필터칩 옆.

struct CalendarModeToggle: View {
    @Binding var mode: CalendarMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CalendarMode.allCases) { m in
                button(for: m)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                )
        )
    }

    private func button(for m: CalendarMode) -> some View {
        let isActive = (mode == m)
        return Button {
            mode = m
        } label: {
            HStack(spacing: 4) {
                Image(systemName: m.iconName)
                    .font(.system(size: 9, weight: .medium))
                Text(m.label)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
            }
            .foregroundStyle(isActive ? LumenTokens.TextColor.primary : LumenTokens.TextColor.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isActive ? LumenTokens.Accent.violet.opacity(0.22) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let label: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(isOn ? color : color.opacity(0.25))
                    .frame(width: 7, height: 7)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isOn
                                     ? LumenTokens.TextColor.secondary
                                     : LumenTokens.TextColor.muted)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isOn ? color.opacity(0.35) : LumenTokens.divider, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
