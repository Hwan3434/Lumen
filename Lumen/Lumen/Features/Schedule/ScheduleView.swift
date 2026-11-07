import SwiftUI

private typealias P = LumenTokens.Palette

/// 일정 대시보드 패널의 루트 뷰. 헤더(제목, 월간/주간, 갱신 상태) 아래에 캘린더가 온다.
/// 모든 데이터는 `ScheduleStore.visibleItems` 하나에서 온다.
struct ScheduleView: View {
    @Environment(ScheduleStore.self) private var store

    @State private var mode: CalendarMode
    @State private var anchorDate: Date = Date()
    /// 보기 전환 시 increment — 자식 view가 onChange로 받아 오늘로 점프.
    /// ZStack+opacity로 항상 mount된 채라 onAppear가 첫 한 번만 호출되는 부작용을 보완.
    @State private var monthResetToken: Int = 0
    @State private var weekResetToken: Int = 0

    init() {
        _mode = State(initialValue: DashboardSettingsStore.shared.settings.defaultView)
    }

    var body: some View {
        ZStack {
            LumenPanelBackground()
            VStack(spacing: 0) {
                header
                LumenHairline()
                calendarBody
            }
        }
        .frame(width: Constants.scheduleWindowSize.width, height: Constants.scheduleWindowSize.height)
        .clipShape(LumenShape.rect(LumenTokens.Radius.xl))
        .onAppear {
            Task { await store.refreshStale() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scheduleSwitchView)) { note in
            guard let newMode = note.object as? CalendarMode else { return }
            mode = newMode
        }
        .onChange(of: mode) { _, _ in fireReset() }
    }

    private func fireReset() {
        switch mode {
        case .month: monthResetToken &+= 1
        case .week:  weekResetToken &+= 1
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: LumenTokens.Space.group) {
            VStack(alignment: .leading, spacing: 0) {
                Text("일정")
                    .lumenText(.title3)
                    .foregroundStyle(P.ink)
                Text(LumenDateFormat.dayWithWeekday.string(from: Date()))
                    .lumenText(.caption)
                    .monospacedDigit()
                    .foregroundStyle(P.inkFaint)
            }

            LumenSegmentedControl(
                items: CalendarMode.allCases.map { .init(value: $0, label: $0.label, icon: $0.iconName) },
                selection: $mode
            )

            Spacer()

            HStack(spacing: LumenTokens.Space.inline) {
                ForEach(store.failures) { failure in
                    LumenBadge(text: "\(failure.plugin.displayName) 오류", tone: .danger)
                        .help(failure.message)
                }
                if store.isRefreshing {
                    HStack(spacing: LumenTokens.Space.s1) {
                        LumenIcon("rotate-cw", size: .small)
                            .foregroundStyle(P.inkFaint)
                            .accessibilityLabel("불러오는 중")
                        Text("새로고침하고 있어요")
                            .lumenText(.caption)
                            .foregroundStyle(P.inkFaint)
                    }
                } else if let updated = store.lastUpdated {
                    Text("\(LumenTime.relative(updated)) 업데이트")
                        .lumenText(.caption)
                        .foregroundStyle(P.inkFaint)
                }
                LumenIconButton(icon: "rotate-cw", label: "새로고침", variant: .secondary) {
                    Task { await store.refreshAll(force: true) }
                }
            }
        }
        .padding(.horizontal, LumenTokens.Space.pad)
        .frame(height: LumenTokens.Space.size(72))
    }

    // MARK: - Calendar

    /// 두 보기를 모두 mount된 채로 두고 active만 보여 준다 — 전환 시 onAppear 재호출에 의한
    /// scroll 깜빡임을 없앰. resetToTodayToken으로 명시적 리셋만.
    @ViewBuilder
    private var calendarBody: some View {
        let items = store.visibleItems
        ZStack {
            MonthGridView(items: items, resetToTodayToken: monthResetToken)
                .padding(.horizontal, LumenTokens.Space.pad)
                .padding(.bottom, LumenTokens.Space.pad)
                .opacity(mode == .month ? 1 : 0)
                .allowsHitTesting(mode == .month)

            TimelineView(items: items, anchorDate: $anchorDate, resetToTodayToken: weekResetToken)
                .padding(.horizontal, LumenTokens.Space.pad)
                .padding(.bottom, LumenTokens.Space.pad)
                .opacity(mode == .week ? 1 : 0)
                .allowsHitTesting(mode == .week)
        }
    }
}
