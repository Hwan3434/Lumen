import SwiftUI
import AppKit

private typealias P = LumenTokens.Palette

// 월간 캘린더 — iCalendar 스타일 세로 스크롤.
// ±3개월(=약 26주)의 주들을 LazyVStack으로 이어 붙이고, 각 주 위에 막대(bar) layer를 깔아
// 여러 날에 걸친 항목이 셀 경계에서 끊기지 않고 하나의 막대로 표현되게 한다.
//
// 데이터는 onAppear/onChange 시점에 layoutByWeek 사전을 한 번만 만들어 매 body 호출의 filter
// 비용을 없앤다 — 121개 항목 × 42셀 × 6주를 매번 도는 게 탭 전환 시 버벅임의 주 원인이었다.

struct MonthGridView: View {
    @Environment(ScheduleStore.self) private var store
    let items: [ScheduleItem]
    /// 외부에서 "오늘로 다시 점프" 신호 — 보기 전환 시 부모가 increment.
    /// ZStack+opacity로 view가 항상 mount된 채라 onAppear가 한 번만 호출됨 → 매번 트리거 필요.
    var resetToTodayToken: Int = 0
    /// ⌘N 신호 — 오늘 칸에 새 일정 팝오버를 띄운다.
    var newItemToken: Int = 0

    /// 날짜 줄 + 막대 4줄 + "+N" 줄. `MonthWeekRow`의 치수와 맞춘다.
    private var weekRowHeight: CGFloat {
        MonthWeekRow.topPadding + CGFloat(MonthWeekRow.maxLanes) * (MonthWeekRow.laneHeight + MonthWeekRow.laneSpacing)
            + LumenTextStyle.caption.lineHeight + LumenTokens.Space.s1
    }

    /// 가시 중앙 주의 시작일 — onScrollGeometryChange로 갱신.
    @State private var visibleAnchor: Date = Calendar.current.startOfDay(for: Date())
    @State private var weeks: [Date] = []
    /// 주 시작일 → 그 주에 그릴 막대 layout. items나 주 목록이 바뀔 때만 재계산.
    @State private var layoutByWeek: [Date: WeekLayout] = [:]
    @State private var scrollTarget: Date? = nil
    @State private var newItemDate: Date? = nil

    private var firstWeekday: Int { store.firstWeekday }

    private func startOfWeek(_ date: Date) -> Date {
        CalendarDateUtils.startOfWeek(of: date, firstWeekday: firstWeekday)
    }

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayRow
            calendarScroll
        }
        .onAppear {
            visibleAnchor = startOfWeek(Date())
            rebuildWeeks()
        }
        .onChange(of: items) { _, _ in
            rebuildLayout()
        }
        .onChange(of: firstWeekday) { _, _ in
            rebuildWeeks()
            scrollTarget = startOfWeek(Date())
        }
        // 패널은 한 번 만들어 계속 쓰므로 onAppear는 처음 한 번뿐이다. 날짜가 넘어갈 때 주 범위를 다시 잡지 않으면
        // 앱을 켜 둔 날수만큼 범위가 뒤로 밀려 결국 오늘이 달력 밖으로 나간다.
        .onChange(of: store.today) { _, _ in
            rebuildWeeks()
        }
        .onChange(of: newItemToken) { _, _ in
            // ⌘N: 오늘 주로 옮기고, 그 행이 그려지면 바인딩을 보고 팝오버가 뜬다.
            scrollTarget = startOfWeek(store.today)
            newItemDate = store.today
        }
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack(spacing: LumenTokens.Space.s4) {
            Text(monthLabel)
                .lumenText(.title3)
                .foregroundStyle(P.ink)
                .frame(minWidth: LumenTokens.Space.size(140), alignment: .leading)
                .contentTransition(.numericText())

            Button("오늘") {
                let target = startOfWeek(Date())
                visibleAnchor = target
                scrollTarget = target
            }
            .buttonStyle(LumenButtonStyle(variant: .secondary, size: .small))

            GroupChipStrip()
        }
        .padding(.vertical, LumenTokens.Space.s4)
    }

    private var monthLabel: String {
        // 같은 주에 두 달이 걸쳐있으면 가운데 날(네 번째 날) 기준으로 결정.
        let cal = Calendar.current
        let middle = cal.date(byAdding: .day, value: 3, to: visibleAnchor) ?? visibleAnchor
        return LumenDateFormat.yearMonthKo.string(from: middle)
    }

    // MARK: - Weekday row

    private var weekdayRow: some View {
        let symbols = CalendarDateUtils.weekdaySymbols(firstWeekday: firstWeekday)
        return HStack(spacing: 0) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { idx, symbol in
                Text(symbol)
                    .lumenText(.caption, weight: .medium)
                    .foregroundStyle(CalendarDateUtils.weekdayColor(weekday: ((firstWeekday - 1 + idx) % 7) + 1))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, LumenTokens.Space.inline)
    }

    // MARK: - Scroll body

    private var calendarScroll: some View {
        let colors = store.groupColors
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(weeks, id: \.self) { weekStart in
                        MonthWeekRow(
                            weekStart: weekStart,
                            layout: layoutByWeek[weekStart] ?? WeekLayout(weekStart: weekStart, bars: [], overflowByCol: [:]),
                            today: store.today,
                            colors: colors,
                            newItemDate: $newItemDate
                        )
                        .frame(height: weekRowHeight)
                        .id(weekKey(weekStart))
                    }
                }
                .scrollTargetLayout()
            }
            .onScrollGeometryChange(for: Date.self) { geo in
                let centerY = geo.contentOffset.y + geo.containerSize.height / 2
                let idx = Int(centerY / weekRowHeight)
                let clamped = max(0, min(weeks.count - 1, idx))
                return weeks.indices.contains(clamped) ? weeks[clamped] : visibleAnchor
            } action: { _, newValue in
                if !Calendar.current.isDate(newValue, inSameDayAs: visibleAnchor) {
                    visibleAnchor = newValue
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(weekKey(startOfWeek(Date())), anchor: .center)
                }
            }
            .onChange(of: resetToTodayToken) { _, _ in
                // 부모가 token을 증가시키면 오늘로 부드럽게 점프.
                let target = startOfWeek(Date())
                visibleAnchor = target
                withAnimation(LumenTokens.Motion.easeMove()) {
                    proxy.scrollTo(weekKey(target), anchor: .center)
                }
            }
            .onChange(of: scrollTarget) { _, newTarget in
                guard let target = newTarget else { return }
                withAnimation(LumenTokens.Motion.easeMove()) {
                    proxy.scrollTo(weekKey(target), anchor: .center)
                }
                scrollTarget = nil
            }
        }
    }

    // MARK: - Week generation & layout

    private func rebuildWeeks() {
        weeks = buildWeeks()
        rebuildLayout()
    }

    private func buildWeeks() -> [Date] {
        let cal = Calendar.current
        let today = store.today
        let firstWeek = startOfWeek(cal.date(byAdding: .day, value: -90, to: today) ?? today)
        let lastWeek = startOfWeek(cal.date(byAdding: .day, value: +90, to: today) ?? today)
        var result: [Date] = []
        var cursor = firstWeek
        while cursor <= lastWeek {
            result.append(cursor)
            cursor = cal.date(byAdding: .day, value: 7, to: cursor) ?? cursor
        }
        return result
    }

    private func rebuildLayout() {
        var dict: [Date: WeekLayout] = [:]
        for weekStart in weeks {
            dict[weekStart] = layoutWeek(weekStart: weekStart, items: items, maxLanes: MonthWeekRow.maxLanes)
        }
        layoutByWeek = dict
    }

    private func weekKey(_ d: Date) -> String {
        CalendarDateUtils.key(d, prefix: "w")
    }
}
