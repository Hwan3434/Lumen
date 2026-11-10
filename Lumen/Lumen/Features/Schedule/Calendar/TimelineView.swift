import SwiftUI
import AppKit

private typealias P = LumenTokens.Palette

// 타임라인 = 주간 뷰. 한 단위 = 1주(7컬럼). 여러 날에 걸친 항목은 그 주 안에서 *하나의 긴 막대*.
// 같은 항목이 주 경계를 넘으면 각 주에서 잘려 막대가 두 개 그려진다 (월간 그리드와 동일 정책).
//
// 가로 스크롤은 자유 — LazyHStack에 주 단위 컨테이너를 쭉 나열. 한 컬럼 폭 = viewport_width / 7.
// lane 알고리즘은 월간 그리드와 동일하고, 주간은 줄 수 제한 없이 세로 스크롤한다.

struct TimelineView: View {
    @Environment(ScheduleStore.self) private var store
    let items: [ScheduleItem]
    @Binding var anchorDate: Date
    /// 외부에서 "이번 주로 다시 점프" 신호 — 보기 전환 시 부모가 increment.
    var resetToTodayToken: Int = 0
    /// ⌘N 신호 — 오늘 날짜 머리에 새 일정 팝오버를 띄운다.
    var newItemToken: Int = 0

    private var today: Date { store.today }
    @State private var newItemDate: Date? = nil
    @AppStorage(ScheduleView.showLunarKey) private var showLunar = false

    private static let cal = Calendar.current
    private let halfRangeWeeks: Int = 13   // ±3개월
    /// 요일(caption) + 날짜(label) + 공휴일 이름(caption) + 위아래 여백.
    private var dayHeaderHeight: CGFloat { LumenTextStyle.caption.lineHeight * 2 + LumenTextStyle.label.lineHeight + LumenTokens.Space.scaled(12) }
    private var laneHeight: CGFloat { LumenTextStyle.caption.lineHeight + LumenTokens.Space.scaled(10) }
    private let laneSpacing: CGFloat = 2
    /// 주간은 제한 없이 다 보여주기 위해 999로 설정 (세로 스크롤 처리).
    private let maxLanesVisible: Int = 999

    private var firstWeekday: Int { DashboardSettingsStore.shared.settings.weekStartsOn.calendarValue }

    var body: some View {
        let colors = store.groupColors
        return VStack(spacing: 0) {
            weekHeader
            GeometryReader { proxy in
                let dayW = proxy.size.width / 7
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(weeks, id: \.self) { weekStart in
                                weekUnit(weekStart: weekStart, dayWidth: dayW, viewportHeight: proxy.size.height, colors: colors)
                                    .id(weekKey(weekStart))
                            }
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.async {
                            scrollProxy.scrollTo(weekKey(currentWeekStart()), anchor: .leading)
                        }
                    }
                    .onChange(of: resetToTodayToken) { _, _ in
                        anchorDate = Date()
                        withAnimation(LumenTokens.Motion.easeMove()) {
                            scrollProxy.scrollTo(weekKey(currentWeekStart()), anchor: .leading)
                        }
                    }
                    .onChange(of: anchorDate) { _, _ in
                        withAnimation(LumenTokens.Motion.easeMove()) {
                            scrollProxy.scrollTo(weekKey(currentWeekStart()), anchor: .leading)
                        }
                    }
                }
            }
        }
        .onChange(of: newItemToken) { _, _ in
            anchorDate = Date()
            newItemDate = today
        }
    }

    // MARK: - Header

    private var weekHeader: some View {
        HStack(spacing: LumenTokens.Space.s4) {
            Text(weekLabel)
                .lumenText(.title3)
                .foregroundStyle(P.ink)
                .frame(minWidth: LumenTokens.Space.size(140), alignment: .leading)

            Button("오늘") {
                anchorDate = Date()
            }
            .buttonStyle(LumenButtonStyle(variant: .secondary, size: .small))

            GroupChipStrip()
        }
        .padding(.vertical, LumenTokens.Space.s4)
    }

    private var weekLabel: String {
        let weekStart = currentWeekStart()
        let middle = Self.cal.date(byAdding: .day, value: 3, to: weekStart) ?? weekStart
        return LumenDateFormat.yearMonthKo.string(from: middle)
    }

    // MARK: - Week unit (한 주 = 헤더 + 막대 layer)

    private func weekUnit(weekStart: Date, dayWidth: CGFloat, viewportHeight: CGFloat,
                          colors: [ScheduleGroupKey: Color]) -> some View {
        let days = (0..<7).compactMap { Self.cal.date(byAdding: .day, value: $0, to: weekStart) }
        let layout = layoutWeek(weekStart: weekStart, items: items, maxLanes: maxLanesVisible)
        let weekW = dayWidth * 7

        let maxLane = layout.bars.map { $0.lane }.max() ?? -1
        let requiredHeight = CGFloat(maxLane + 1) * (laneHeight + laneSpacing) + LumenTokens.Space.scaled(20)
        let gridHeight = max(viewportHeight - dayHeaderHeight, requiredHeight)

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    dayHeader(day: day).frame(width: dayWidth)
                }
            }
            .frame(height: dayHeaderHeight)
            LumenHairline()

            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    gridLines(days: days, dayWidth: dayWidth, height: gridHeight)

                    ForEach(layout.bars) { bar in
                        CalendarBarButton(
                            item: bar.item,
                            color: colors[bar.item.groupKey] ?? P.chartOther,
                            width: dayWidth * CGFloat(bar.span) - 4,
                            height: laneHeight - 2
                        )
                        .padding(.leading, CGFloat(bar.startCol) * dayWidth + 2)
                        .padding(.top, CGFloat(bar.lane) * (laneHeight + laneSpacing) + LumenTokens.Space.scaled(6))
                    }
                }
                .frame(width: weekW, height: gridHeight, alignment: .topLeading)
            }
            .frame(width: weekW, height: max(0, viewportHeight - dayHeaderHeight), alignment: .topLeading)
        }
        .frame(width: weekW, height: viewportHeight, alignment: .topLeading)
    }

    private func dayHeader(day: Date) -> some View {
        let weekday = Self.cal.component(.weekday, from: day)
        let isToday = Self.cal.isDate(day, inSameDayAs: today)
        let isFirstOfMonth = (Self.cal.component(.day, from: day) == 1)
        let holidayName = KoreanHolidays.name(for: day)
        return VStack(spacing: 0) {
            HStack(spacing: LumenTokens.Space.s1) {
                if isFirstOfMonth {
                    Text(monthShort(day))
                        .lumenText(.caption, weight: .semibold)
                        .foregroundStyle(P.inkMuted)
                }
                Text(CalendarDateUtils.weekdaySymbols(firstWeekday: weekday)[0])
                    .lumenText(.caption, weight: .medium)
                    .foregroundStyle(holidayName != nil
                                     ? P.danger
                                     : CalendarDateUtils.weekdayColor(for: day))
            }
            Text(dayLabel(day))
                .lumenText(.label, weight: isToday ? .bold : .regular)
                .monospacedDigit()
                .foregroundStyle(CalendarDateUtils.dayNumberColor(isToday: isToday, day: day))
            if showLunar, let lunar = CalendarDateUtils.lunarLabel(for: day) {
                Text(lunar)
                    .lumenText(.caption)
                    .monospacedDigit()
                    .foregroundStyle(P.inkFaint)
                    .lineLimit(1)
            }
            if let name = holidayName {
                Text(name)
                    .lumenText(.caption)
                    .foregroundStyle(P.danger)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, LumenTokens.Space.s1)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            newItemDate = day
        }
        .newItemPopover(day: day, selection: $newItemDate, arrowEdge: .bottom)
    }

    private func gridLines(days: [Date], dayWidth: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let weekday = Self.cal.component(.weekday, from: day)
                let isWeekend = (weekday == 1 || weekday == 7)
                let isToday = Self.cal.isDate(day, inSameDayAs: today)
                Rectangle()
                    // 주말 칸은 글래스가 켜져 있으면 깔지 않는다 — 불투명한 `surface`는 비치는 패널 위에서 그 칸만 막힌 판이 된다.
                    .fill(isToday ? P.brandSoft : (isWeekend ? P.panelSurface : Color.clear))
                    .frame(width: dayWidth, height: height)
                    .overlay(alignment: .leading) { LumenHairline(.vertical) }
            }
        }
    }

    // MARK: - Week list

    private var weeks: [Date] {
        let center = currentWeekStart()
        return (-halfRangeWeeks...halfRangeWeeks).compactMap {
            Self.cal.date(byAdding: .day, value: $0 * 7, to: center)
        }
    }

    private func currentWeekStart() -> Date {
        CalendarDateUtils.startOfWeek(of: anchorDate, firstWeekday: firstWeekday)
    }

    // MARK: - Helpers

    private func weekKey(_ d: Date) -> String {
        CalendarDateUtils.key(d, prefix: "wk")
    }

    private func dayLabel(_ d: Date) -> String {
        LumenDateFormat.dayKo.string(from: d)
    }

    private func monthShort(_ d: Date) -> String {
        LumenDateFormat.monthKo.string(from: d)
    }
}
