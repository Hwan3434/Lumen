import SwiftUI
import AppKit

// 타임라인 = 주간 뷰. 한 단위 = 1주(7컬럼). 다일 task는 그 주 안에서 *하나의 긴 막대*.
// 같은 task가 주 경계를 넘으면 각 주에서 잘려 막대가 두 개 그려진다 (월간 그리드와 동일 정책).
//
// 가로 스크롤은 자유 — LazyHStack에 주 단위 컨테이너를 쭉 나열, viewAligned 강제 안 함.
// 한 컬럼 폭 = viewport_width / 7. 한 화면에 7일이 fit되되 임의 위치에서 멈출 수 있음.
//
// lane 알고리즘은 월간 그리드와 동일 — 시간상 안 겹치는 task끼리 같은 lane에.
// 우선순위: 막대가 긴 것이 먼저 자리잡고 위에서부터 lane을 쌓음 (사용자 지정 규칙).

struct TimelineView: View {
    let items: [CalendarItem]
    @Binding var anchorDate: Date
    /// 외부에서 "이번 주로 다시 점프" 신호 — 탭 활성화 시 부모가 increment.
    var resetToTodayToken: Int = 0

    @State private var previewingKey: String? = nil
    @State private var editingEvent: LocalEvent? = nil
    @State private var newEventDate: Date? = nil

    private static let cal = Calendar.current
    private let halfRangeWeeks: Int = 13   // ±3개월
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    private let dayHeaderHeight: CGFloat = 44
    private let laneHeight: CGFloat = 22
    private let laneSpacing: CGFloat = 3
    /// lane 너무 많으면 +N으로 잘라낸다.
    private let maxLanesVisible: Int = 12

    var body: some View {
        GeometryReader { proxy in
            let dayW = proxy.size.width / 7
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(weeks, id: \.self) { weekStart in
                            weekUnit(weekStart: weekStart, dayWidth: dayW, viewportHeight: proxy.size.height)
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
                    withAnimation(.easeOut(duration: 0.25)) {
                        scrollProxy.scrollTo(weekKey(currentWeekStart()), anchor: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Week unit (한 주 = 헤더 + 막대 layer)

    private func weekUnit(weekStart: Date, dayWidth: CGFloat, viewportHeight: CGFloat) -> some View {
        let days = (0..<7).compactMap { Self.cal.date(byAdding: .day, value: $0, to: weekStart) }
        let layout = layoutWeek(weekStart: weekStart, items: items, maxLanes: maxLanesVisible)
        let weekW = dayWidth * 7
        return VStack(spacing: 0) {
            // 헤더
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    dayHeader(day: day).frame(width: dayWidth)
                }
            }
            .frame(height: dayHeaderHeight)
            Rectangle().fill(LumenTokens.divider).frame(height: 0.5)

            // 막대 layer + 격자
            ZStack(alignment: .topLeading) {
                gridLines(days: days, dayWidth: dayWidth, height: max(viewportHeight - dayHeaderHeight, 200))

                ForEach(layout.bars) { bar in
                    barView(bar: bar, dayWidth: dayWidth)
                }

                // overflow 표시 — 잘려 안 보이는 task가 있는 col에 +N
                ForEach(Array(layout.overflowByCol.keys), id: \.self) { col in
                    if let n = layout.overflowByCol[col] {
                        Text("+\(n)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(LumenTokens.TextColor.muted)
                            .padding(.leading, CGFloat(col) * dayWidth + 4)
                            .padding(.top, CGFloat(maxLanesVisible) * (laneHeight + laneSpacing) + 4)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
            .frame(width: weekW, alignment: .topLeading)
        }
        .frame(width: weekW, height: viewportHeight, alignment: .topLeading)
    }

    private func dayHeader(day: Date) -> some View {
        let weekday = Self.cal.component(.weekday, from: day)
        let isToday = Self.cal.isDateInToday(day)
        let isFirstOfMonth = (Self.cal.component(.day, from: day) == 1)
        let holidayName = KoreanHolidays.name(for: day)
        return VStack(spacing: 1) {
            HStack(spacing: 4) {
                if isFirstOfMonth {
                    Text(monthShort(day))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(LumenTokens.Accent.violetSoft)
                }
                Text(weekdays[(weekday - 1) % 7])
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(holidayName != nil
                                     ? LumenTokens.CalendarTone.holiday
                                     : CalendarDateUtils.weekdayColor(for: day))
            }
            Text(dayLabel(day))
                .font(.system(size: 12, weight: isToday ? .bold : .regular,
                              design: .monospaced))
                .foregroundStyle(dayNumberColor(isToday: isToday, holidayName: holidayName))
            if let name = holidayName {
                Text(name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(LumenTokens.CalendarTone.holiday)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            newEventDate = day
        }
        .popover(isPresented: Binding(
            get: { newEventDate != nil && Self.cal.isDate(newEventDate!, inSameDayAs: day) },
            set: { if !$0 { newEventDate = nil } }
        ), arrowEdge: .bottom) {
            NewEventPopover(initialDate: day) { newEventDate = nil }
        }
    }

    /// 날짜 숫자의 색 우선순위: today > 공휴일 > 기본. (MonthGridView와 같은 정책)
    private func dayNumberColor(isToday: Bool, holidayName: String?) -> Color {
        if isToday { return LumenTokens.Accent.amber }
        if holidayName != nil { return LumenTokens.CalendarTone.holiday }
        return LumenTokens.TextColor.primary
    }

    private func gridLines(days: [Date], dayWidth: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let weekday = Self.cal.component(.weekday, from: day)
                let isWeekend = (weekday == 1 || weekday == 7)
                let isToday = Self.cal.isDateInToday(day)
                Rectangle()
                    .fill(isToday
                          ? LumenTokens.Accent.amber.opacity(0.06)
                          : (isWeekend ? Color.white.opacity(0.015) : Color.clear))
                    .frame(width: dayWidth, height: height)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(LumenTokens.divider).frame(width: 0.5, height: height)
                    }
            }
        }
    }

    // (lane 배치는 CalendarModel.swift의 layoutWeek(weekStart:items:maxLanes:)을 공유)

    // MARK: - Bar view

    private func barView(bar: LaidOutBar, dayWidth: CGFloat) -> some View {
        let item = bar.item
        let isLocal = (item.kind == .local)
        let projectColor = item.projectKey.map { jiraProjectColor($0) } ?? item.kind.color
        let leading = CGFloat(bar.startCol) * dayWidth + 2
        let width = dayWidth * CGFloat(bar.span) - 4
        let topOffset = CGFloat(bar.lane) * (laneHeight + laneSpacing) + 6

        return Button {
            if isLocal, let ev = matchingLocalEvent(itemID: item.id) {
                editingEvent = ev
            } else if let key = item.issueKey {
                previewingKey = key
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(item.kind.color)
                    .frame(width: 5, height: 5)
                Text(item.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(item.isDone
                                     ? LumenTokens.TextColor.muted
                                     : (isLocal ? LumenTokens.TextColor.secondary : LumenTokens.TextColor.primary))
                    .strikethrough(item.isDone, color: LumenTokens.TextColor.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(width: width, height: laneHeight - 2, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isLocal ? Color.white.opacity(0.04) : projectColor.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(
                        isLocal ? LumenTokens.TextColor.muted.opacity(0.55) : projectColor.opacity(0.45),
                        style: StrokeStyle(lineWidth: 0.5, dash: isLocal ? [3, 2] : [])
                    )
            )
        }
        .buttonStyle(.plain)
        .help(item.issueKey.map { "\($0) · \(item.title)" } ?? item.title)
        .popover(isPresented: Binding(
            get: { previewingKey != nil && previewingKey == item.issueKey },
            set: { if !$0 { previewingKey = nil } }
        ), arrowEdge: .top) {
            if let key = item.issueKey {
                IssuePreviewPopover(issueKey: key)
            }
        }
        .popover(isPresented: Binding(
            get: { editingEvent != nil && editingEvent.flatMap { "local-\($0.id.uuidString)" } == item.id },
            set: { if !$0 { editingEvent = nil } }
        ), arrowEdge: .top) {
            if let ev = editingEvent {
                LocalEventEditPopover(event: ev) { editingEvent = nil }
            }
        }
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
        CalendarDateUtils.startOfWeek(of: anchorDate)
    }

    // MARK: - Helpers

    private func matchingLocalEvent(itemID: String) -> LocalEvent? {
        guard itemID.hasPrefix("local-"),
              let uuid = UUID(uuidString: String(itemID.dropFirst("local-".count))) else { return nil }
        return LocalEventStore.shared.events.first { $0.id == uuid }
    }

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
