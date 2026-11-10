import SwiftUI

private typealias P = LumenTokens.Palette

/// 월간 달력의 한 주. 날짜 칸 7개 위에 막대 layer를 깔고, 레인을 넘친 일정은 칸 아래 "+N"으로 보여 준다.
struct MonthWeekRow: View {
    @Environment(ScheduleStore.self) private var store
    let weekStart: Date
    let layout: WeekLayout
    let today: Date
    let colors: [ScheduleGroupKey: Color]
    /// 셀 더블클릭·⌘N 시 새 항목 popover의 anchor 날짜. 부모가 들고 있어야 ⌘N이 아직 안 그려진 주에도 닿는다.
    @Binding var newItemDate: Date?

    /// 한 주에 보일 수 있는 막대(레인) 최대 갯수. 넘는 건 그 날짜 칸 아래 "+N".
    static let maxLanes = 4
    static var laneHeight: CGFloat { LumenTextStyle.caption.lineHeight + LumenTokens.Space.scaled(6) }
    static let laneSpacing: CGFloat = 2
    static var topPadding: CGFloat { LumenTextStyle.caption.lineHeight + LumenTokens.Space.scaled(12) }  // 날짜 숫자 자리

    /// "+N"을 눌러 그날 일정 전체를 볼 날짜.
    @State private var overflowDay: Date? = nil
    @AppStorage(ScheduleView.showLunarKey) private var showLunar = false

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
                    CalendarBarButton(
                        item: bar.item,
                        color: colors[bar.item.groupKey] ?? P.chartOther,
                        width: cellW * CGFloat(bar.span) - 4,
                        height: Self.laneHeight - 2
                    )
                    .padding(.leading, CGFloat(bar.startCol) * cellW + 2)
                    .padding(.top, Self.topPadding + CGFloat(bar.lane) * (Self.laneHeight + Self.laneSpacing))
                }

                // 3) 넘친 일정 — 누르면 그날 일정 전체를 팝오버로
                ForEach(Array(layout.overflowByCol.keys), id: \.self) { col in
                    if let n = layout.overflowByCol[col], let day = days[safe: col] {
                        overflowButton(count: n, day: day)
                            .padding(.leading, CGFloat(col) * cellW + LumenTokens.Space.scaled(4))
                            .padding(.top, Self.topPadding + CGFloat(Self.maxLanes) * (Self.laneHeight + Self.laneSpacing))
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
                        .foregroundStyle(CalendarDateUtils.dayNumberColor(isToday: isToday, day: day))
                } else {
                    Text("\(dayNum)")
                        .lumenText(.caption, weight: isToday ? .bold : .regular)
                        .monospacedDigit()
                        .foregroundStyle(CalendarDateUtils.dayNumberColor(isToday: isToday, day: day))
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
        .newItemPopover(day: day, selection: $newItemDate, arrowEdge: .top)
    }

    private func monthDayLabel(_ day: Date) -> String {
        LumenDateFormat.monthDayKo.string(from: day)
    }
}
