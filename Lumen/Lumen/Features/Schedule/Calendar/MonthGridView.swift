import SwiftUI
import AppKit

private typealias P = LumenTokens.Palette

// 월간 캘린더 — iCalendar 스타일 무한 스크롤.
// ±3개월(=약 26주)의 주들을 LazyVStack으로 이어 붙이고, 각 주 위에 막대(bar) layer를 깔아
// 여러 날에 걸친 항목이 셀 경계에서 끊기지 않고 하나의 막대로 표현되게 한다.
//
// 데이터는 onAppear/onChange 시점에 weekLayouts 사전을 한 번만 만들어 매 body 호출의 filter
// 비용을 없앤다 — 121개 항목 × 42셀 × 6주를 매번 도는 게 탭 전환 시 버벅임의 주 원인이었다.

struct MonthGridView: View {
    @Environment(ScheduleStore.self) private var store
    let items: [ScheduleItem]
    /// 외부에서 "오늘로 다시 점프" 신호 — 보기 전환 시 부모가 increment.
    /// ZStack+opacity로 view가 항상 mount된 채라 onAppear가 한 번만 호출됨 → 매번 트리거 필요.
    var resetToTodayToken: Int = 0
    /// ⌘N 신호 — 오늘 칸에 새 일정 팝오버를 띄운다.
    var newItemToken: Int = 0

    /// 날짜 줄 + 막대 4줄 + "+N" 줄. WeekRow의 치수와 맞춘다.
    private var weekRowHeight: CGFloat {
        WeekRow.topPadding + CGFloat(WeekRow.maxLanes) * (WeekRow.laneHeight + WeekRow.laneSpacing)
            + LumenTextStyle.caption.lineHeight + LumenTokens.Space.s1
    }

    /// 가시 중앙 주의 시작일 — onScrollGeometryChange로 갱신.
    @State private var visibleAnchor: Date = Calendar.current.startOfDay(for: Date())
    @State private var weeks: [Date] = []
    /// 주 시작일 → 그 주에 그릴 막대 layout. items가 바뀔 때만 재계산.
    @State private var layoutByWeek: [Date: WeekLayout] = [:]
    @State private var scrollTarget: Date? = nil
    @State private var newItemDate: Date? = nil

    private var firstWeekday: Int { DashboardSettingsStore.shared.settings.weekStartsOn.calendarValue }

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
            weeks = buildWeeks()
            rebuildLayout()
        }
        .onChange(of: items) { _, _ in
            rebuildLayout()
        }
        .onChange(of: firstWeekday) { _, _ in
            weeks = buildWeeks()
            rebuildLayout()
            scrollTarget = startOfWeek(Date())
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
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        // 같은 주에 두 달이 걸쳐있으면 가운데 날(네 번째 날) 기준으로 결정.
        let cal = Calendar.current
        let middle = cal.date(byAdding: .day, value: 3, to: visibleAnchor) ?? visibleAnchor
        return f.string(from: middle)
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
                        WeekRow(
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

    private func buildWeeks() -> [Date] {
        let cal = Calendar.current
        let today = Date()
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
            dict[weekStart] = layoutWeek(weekStart: weekStart, items: items, maxLanes: WeekRow.maxLanes)
        }
        layoutByWeek = dict
    }

    private func weekKey(_ d: Date) -> String {
        CalendarDateUtils.key(d, prefix: "w")
    }
}

// MARK: - WeekRow

private struct WeekRow: View {
    @Environment(ScheduleStore.self) private var store
    let weekStart: Date
    let layout: WeekLayout
    let today: Date
    let colors: [ScheduleGroupKey: Color]
    /// 셀 더블클릭·⌘N 시 새 항목 popover의 anchor 날짜. 부모가 들고 있어야 ⌘N이 아직 안 그려진 주에도 닿는다.
    @Binding var newItemDate: Date?

    /// 한 주에 보일 수 있는 막대(레인) 최대 갯수. 넘는 건 그 날짜 칸 아래 "+N".
    static let maxLanes = 4
    static var laneHeight: CGFloat { LumenTextStyle.caption.lineHeight + 6 }
    static let laneSpacing: CGFloat = 2
    static var topPadding: CGFloat { LumenTextStyle.caption.lineHeight + 12 }  // 날짜 숫자 자리
    private var laneHeight: CGFloat { Self.laneHeight }
    private var laneSpacing: CGFloat { Self.laneSpacing }
    private var topPadding: CGFloat { Self.topPadding }

    /// 막대 클릭 시 상세를 띄울 항목 id — nil이면 닫힘. ⌘클릭이면 secondary(Jira 댓글).
    @State private var selectedID: String? = nil
    @State private var selectedVariant: ScheduleDetailVariant = .primary
    /// "+N"을 눌러 그날 일정 전체를 볼 날짜.
    @State private var overflowDay: Date? = nil
    @AppStorage("schedule.showLunar") private var showLunar = false

    var body: some View {
        let cal = Calendar.current
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }

        return GeometryReader { proxy in
            let cellW = proxy.size.width / 7
            ZStack(alignment: .topLeading) {
                // 1) 셀 배경 (날짜 숫자 + 격자)
                HStack(spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        cellBackground(day: day, cellWidth: cellW, cellHeight: proxy.size.height)
                    }
                }

                // 2) 막대 layer
                ForEach(layout.bars) { bar in
                    barView(bar: bar, cellW: cellW)
                }

                // 3) 넘친 일정 — 누르면 그날 일정 전체를 팝오버로
                ForEach(Array(layout.overflowByCol.keys), id: \.self) { col in
                    if let n = layout.overflowByCol[col], let day = days[safe: col] {
                        overflowButton(count: n, day: day)
                            .padding(.leading, CGFloat(col) * cellW + LumenTokens.Space.scaled(4))
                            .padding(.top, topPadding + CGFloat(Self.maxLanes) * (laneHeight + laneSpacing))
                    }
                }
            }
        }
    }

    private func overflowButton(count: Int, day: Date) -> some View {
        Button {
            overflowDay = day
        } label: {
            Text("+\(count)")
                .lumenText(.caption, weight: .medium)
                .monospacedDigit()
                .foregroundStyle(P.inkFaint)
                .padding(.horizontal, LumenTokens.Space.s1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(LumenDateFormat.shortDay.string(from: day)) 일정 \(count)개 더 보기")
        .accessibilityLabel("\(LumenDateFormat.shortDay.string(from: day)) 일정 \(count)개 더 보기")
        .popover(isPresented: Binding(
            get: { overflowDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false },
            set: { if !$0 { overflowDay = nil } }
        ), arrowEdge: .top) {
            DayItemsPopover(day: day).environment(store)
        }
    }

    private func cellBackground(day: Date, cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDate(cal.startOfDay(for: day), inSameDayAs: today)
        let dayNum = cal.component(.day, from: day)
        let isFirstOfMonth = (dayNum == 1)
        let holidayName = KoreanHolidays.name(for: day)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: LumenTokens.Space.s1) {
                if isFirstOfMonth {
                    Text(monthDayLabel(day))
                        .lumenText(.caption, weight: .semibold)
                        .monospacedDigit()
                        .foregroundStyle(dayNumberColor(isToday: isToday, day: day))
                } else {
                    Text("\(dayNum)")
                        .lumenText(.caption, weight: isToday ? .bold : .regular)
                        .monospacedDigit()
                        .foregroundStyle(dayNumberColor(isToday: isToday, day: day))
                }
                if let name = holidayName {
                    Text(name)
                        .lumenText(.caption)
                        .foregroundStyle(P.danger)
                        .lineLimit(1)
                }
                Spacer()
                if showLunar, let lunar = CalendarDateUtils.lunarLabel(for: day) {
                    Text(lunar)
                        .lumenText(.caption)
                        .monospacedDigit()
                        .foregroundStyle(P.inkFaint)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(LumenTokens.Space.scaled(6))
        .frame(width: cellWidth, height: cellHeight, alignment: .topLeading)
        .background(isToday ? P.brandSoft : .clear)
        .overlay(Rectangle().strokeBorder(P.borderSubtle, lineWidth: 0.5))
        .contentShape(Rectangle())
        // 셀 빈 영역 더블클릭 → 그 날짜로 새 항목 popover.
        // 막대(Button)가 그 위에 있으면 막대가 hit-test 우선이라 그 영역은 빠진다.
        .onTapGesture(count: 2) {
            newItemDate = day
        }
        .popover(isPresented: Binding(
            get: { newItemDate != nil && Calendar.current.isDate(newItemDate!, inSameDayAs: day) },
            set: { if !$0 { newItemDate = nil } }
        ), arrowEdge: .top) {
            if let view = store.newItemView(on: day, dismiss: { newItemDate = nil }) {
                view
            }
        }
    }

    private func barView(bar: LaidOutBar, cellW: CGFloat) -> some View {
        let leading = CGFloat(bar.startCol) * cellW + 2
        let width = cellW * CGFloat(bar.span) - 4
        let topOffset = topPadding + CGFloat(bar.lane) * (laneHeight + laneSpacing)
        let color = colors[bar.item.groupKey] ?? P.chartOther

        return Button {
            selectedVariant = isCommandClick ? .secondary : .primary
            selectedID = bar.item.id
        } label: {
            CalendarBarView(
                spec: bar.item.barSpec(color: color),
                cornerRadius: LumenTokens.Radius.xs,
                height: laneHeight - 2
            )
            .frame(width: width)
        }
        .buttonStyle(.plain)
        // 상세는 조회를 마친 뒤에 뜬다 — 팝오버는 표시 시점 크기로 고정되므로.
        .scheduleDetailPopover(item: bar.item, variant: selectedVariant, isPresented: Binding(
            get: { selectedID == bar.item.id },
            set: { if !$0 { selectedID = nil } }
        ))
        .padding(.leading, leading)
        .padding(.top, topOffset)
    }

    private func monthDayLabel(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: day)
    }

    /// 날짜 숫자의 색 우선순위: today > 토·일·공휴일 > 기본.
    private func dayNumberColor(isToday: Bool, day: Date) -> Color {
        if isToday { return P.brand }
        if CalendarDateUtils.isRedDay(day) { return P.danger }
        return P.ink
    }
}
