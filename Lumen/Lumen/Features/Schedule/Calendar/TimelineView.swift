import SwiftUI
import AppKit
import Combine

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

    @State private var today: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedID: String? = nil
    @State private var selectedVariant: ScheduleDetailVariant = .primary
    @State private var newItemDate: Date? = nil

    private static let cal = Calendar.current
    private let halfRangeWeeks: Int = 13   // ±3개월
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    /// 요일(caption) + 날짜(label) + 공휴일 이름(caption) + 위아래 여백.
    private var dayHeaderHeight: CGFloat { LumenTextStyle.caption.lineHeight * 2 + LumenTextStyle.label.lineHeight + 12 }
    private var laneHeight: CGFloat { LumenTextStyle.caption.lineHeight + 10 }
    private let laneSpacing: CGFloat = 3
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
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            let newToday = Calendar.current.startOfDay(for: Date())
            if newToday != today { today = newToday }
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
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        let weekStart = currentWeekStart()
        let middle = Self.cal.date(byAdding: .day, value: 3, to: weekStart) ?? weekStart
        return f.string(from: middle)
    }

    // MARK: - Week unit (한 주 = 헤더 + 막대 layer)

    private func weekUnit(weekStart: Date, dayWidth: CGFloat, viewportHeight: CGFloat,
                          colors: [ScheduleGroupKey: Color]) -> some View {
        let days = (0..<7).compactMap { Self.cal.date(byAdding: .day, value: $0, to: weekStart) }
        let layout = layoutWeek(weekStart: weekStart, items: items, maxLanes: maxLanesVisible)
        let weekW = dayWidth * 7

        let maxLane = layout.bars.map { $0.lane }.max() ?? -1
        let requiredHeight = CGFloat(maxLane + 1) * (laneHeight + laneSpacing) + 20
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
                        barView(bar: bar, dayWidth: dayWidth, color: colors[bar.item.groupKey] ?? P.chartOther)
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
                Text(weekdays[(weekday - 1) % 7])
                    .lumenText(.caption, weight: .medium)
                    .foregroundStyle(holidayName != nil
                                     ? P.danger
                                     : CalendarDateUtils.weekdayColor(for: day))
            }
            Text(dayLabel(day))
                .lumenText(.label, weight: isToday ? .bold : .regular)
                .monospacedDigit()
                .foregroundStyle(dayNumberColor(isToday: isToday, holidayName: holidayName))
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
        .popover(isPresented: Binding(
            get: { newItemDate != nil && Self.cal.isDate(newItemDate!, inSameDayAs: day) },
            set: { if !$0 { newItemDate = nil } }
        ), arrowEdge: .bottom) {
            if let view = store.newItemView(on: day, dismiss: { newItemDate = nil }) {
                view
            }
        }
    }

    /// 날짜 숫자의 색 우선순위: today > 공휴일 > 기본. (MonthGridView와 같은 정책)
    private func dayNumberColor(isToday: Bool, holidayName: String?) -> Color {
        if isToday { return P.brand }
        if holidayName != nil { return P.danger }
        return P.ink
    }

    private func gridLines(days: [Date], dayWidth: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let weekday = Self.cal.component(.weekday, from: day)
                let isWeekend = (weekday == 1 || weekday == 7)
                let isToday = Self.cal.isDate(day, inSameDayAs: today)
                Rectangle()
                    .fill(isToday ? P.brandSoft : (isWeekend ? P.surface : Color.clear))
                    .frame(width: dayWidth, height: height)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(P.borderSubtle).frame(width: 1, height: height)
                    }
            }
        }
    }

    // MARK: - Bar view

    private func barView(bar: LaidOutBar, dayWidth: CGFloat, color: Color) -> some View {
        let item = bar.item
        let leading = CGFloat(bar.startCol) * dayWidth + 2
        let width = dayWidth * CGFloat(bar.span) - 4
        let topOffset = CGFloat(bar.lane) * (laneHeight + laneSpacing) + 6

        return Button {
            selectedVariant = isCommandClick ? .secondary : .primary
            selectedID = item.id
        } label: {
            CalendarBarView(
                spec: item.barSpec(color: color),
                cornerRadius: LumenTokens.Radius.xs,
                height: laneHeight - 2
            )
            .frame(width: width)
        }
        .buttonStyle(.plain)
        .scheduleDetailPopover(item: item, variant: selectedVariant, isPresented: Binding(
            get: { selectedID == item.id },
            set: { if !$0 { selectedID = nil } }
        ))
        .padding(.leading, leading)
        .padding(.top, topOffset)
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
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "d일"
        return f.string(from: d)
    }

    private func monthShort(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월"
        return f.string(from: d)
    }
}
