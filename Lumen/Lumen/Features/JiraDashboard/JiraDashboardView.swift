import SwiftUI

/// 통합 Jira 패널 메인 뷰 — 1160×840pt 글래스 패널, 56pt 통합 헤더 + 탭 컨텐츠.
/// 탭: 대시보드 / 월간 / 타임라인. 모두 같은 JiraService.shared 데이터 위에서 다른 렌더링.
struct JiraDashboardView: View {
    private var service: JiraService { JiraService.shared }
    @State private var activeTab: JiraTab = .dashboard
    @State private var selectedProject: String = PresentColumn.allKey
    @State private var filter = CalendarFilter()
    @State private var anchorDate: Date = Date()
    /// LocalEventStore 변경(추가/편집/삭제)을 감지해 캘린더 막대도 즉시 재렌더 되게.
    @State private var localStore = LocalEventStore.shared

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
        .onAppear { Task { await service.fetch() } }
        .onReceive(NotificationCenter.default.publisher(for: .jiraSwitchTab)) { note in
            guard let idx = note.object as? Int,
                  JiraTab.allCases.indices.contains(idx) else { return }
            activeTab = JiraTab.allCases[idx]
        }
    }

    @ViewBuilder
    private func content(_ data: JiraDashboardData) -> some View {
        VStack(spacing: 0) {
            JiraHeader(
                lastUpdated: data.lastUpdated,
                refreshing: service.isLoading,
                onRefresh: { Task { await service.fetch(force: true) } },
                center: { JiraTabBar(active: $activeTab) },
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
        case .month, .timeline:
            FilterChip(label: "에픽",   color: LumenTokens.Accent.violet,        isOn: $filter.showEpic)
            FilterChip(label: "스프린트", color: LumenTokens.Accent.amber,         isOn: $filter.showSprint)
            FilterChip(label: "태스크",  color: LumenTokens.TextColor.secondary,   isOn: $filter.showTask)
        }
    }

    /// 세 탭의 컨텐츠를 모두 mount된 채로 두고 active만 보여 준다 — 탭 전환 시 첫 mount 비용
    /// (예: 월간의 onAppear scroll-to-today)이 매번 발생하면서 화면이 휙 움직이는 깜빡임을 없앤다.
    @ViewBuilder
    private func tabBody(_ data: JiraDashboardData) -> some View {
        // 월간/타임라인 모두 로컬 이벤트 포함 — 두 탭 데이터 동기화.
        let calendarItems = visibleCalendarItems(data, includeLocal: true)

        ZStack {
            DashboardContent(data: data, selectedProject: $selectedProject)
                .opacity(activeTab == .dashboard ? 1 : 0)
                .allowsHitTesting(activeTab == .dashboard)

            MonthGridView(items: calendarItems)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .opacity(activeTab == .month ? 1 : 0)
                .allowsHitTesting(activeTab == .month)

            TimelineView(items: calendarItems, anchorDate: $anchorDate)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .opacity(activeTab == .timeline ? 1 : 0)
                .allowsHitTesting(activeTab == .timeline)
        }
    }

    private func visibleCalendarItems(_ data: JiraDashboardData, includeLocal: Bool) -> [CalendarItem] {
        CalendarAdapter.buildItems(from: data, includeLocal: includeLocal).filter { filter.passes($0) }
    }
}

// MARK: - FilterChip
//
// 캘린더 탭의 헤더-우측에 들어가는 종류 토글. 색 점 + 라벨 + 외곽선.
// 활성: 색 진하게 + secondary text, 비활성: dim color + muted text.
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
