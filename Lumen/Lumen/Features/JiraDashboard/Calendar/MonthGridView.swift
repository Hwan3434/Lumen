import SwiftUI
import AppKit
import EventKit

// 월간 캘린더 — iCalendar 스타일 무한 스크롤.
// ±3개월(=약 26주)의 주들을 LazyVStack으로 이어 붙이고, 각 주 위에 막대(bar) layer를 깔아
// 다일 task가 셀 경계에서 끊기지 않고 하나의 막대로 표현되게 한다.
//
// 데이터는 init/onChange 시점에 weekLayouts 사전을 한 번만 만들어 매 body 호출의 filter
// 비용을 없앤다 — 121개 task × 42셀 × 6주를 매번 도는 게 탭 전환 시 버벅임의 주 원인이었다.

struct MonthGridView: View {
    let items: [CalendarItem]
    @Binding var showLocal: Bool
    @Binding var disabledProjectKeys: Set<String>
    let showGoogleCalendar: Bool
    /// 외부에서 "오늘로 다시 점프" 신호 — 탭 활성화 시 부모가 increment.
    /// ZStack+opacity로 view가 항상 mount된 채라 onAppear가 한 번만 호출됨 → 매번 트리거 필요.
    var resetToTodayToken: Int = 0

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    private let weekRowHeight: CGFloat = 110
    /// 한 주에 보일 수 있는 막대(레인) 최대 갯수. 넘는 건 "+N" 으로.
    private let maxLanesPerWeek: Int = 4

    /// 가시 중앙 주의 시작일 — onScrollGeometryChange로 갱신.
    @State private var visibleAnchor: Date = CalendarDateUtils.startOfWeek(of: Date())
    @State private var weeks: [Date] = []
    /// 주 시작일 → 그 주에 그릴 막대 layout. items가 바뀔 때만 재계산.
    @State private var layoutByWeek: [Date: WeekLayout] = [:]
    @State private var scrollTarget: Date? = nil

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayRow
            calendarScroll
        }
        .onAppear {
            weeks = buildWeeks()
            rebuildLayout()
        }
        .onChange(of: items) { _, _ in
            rebuildLayout()
        }
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack(spacing: 12) {
            Text(monthLabel)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.primary)
                .frame(minWidth: 110, alignment: .leading)
                .contentTransition(.numericText())

            Button("오늘") {
                let today = CalendarDateUtils.startOfWeek(of: Date())
                visibleAnchor = today
                scrollTarget = today
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(LumenTokens.Accent.violetSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(LumenTokens.stroke, lineWidth: 0.5)
            )

            CalendarVisibilityStrip(showLocal: $showLocal, disabledProjectKeys: $disabledProjectKeys, showGoogleCalendar: showGoogleCalendar)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        // 같은 주에 두 달이 걸쳐있으면 *목요일* 기준으로 결정 (ISO week 정통).
        let cal = Calendar.current
        let thursday = cal.date(byAdding: .day, value: 3, to: visibleAnchor) ?? visibleAnchor
        return f.string(from: thursday)
    }

    // MARK: - Weekday row

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { idx, w in
                Text(w)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(weekdayColor(idx))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    /// weekdayRow는 날짜 없이 0~6 인덱스만 가지므로 idx 기반 분기를 그대로 둔다 (Date 기반 helper 부적합).
    private func weekdayColor(_ index: Int) -> Color {
        if index == 0 { return LumenTokens.CalendarTone.sunday }
        if index == 6 { return LumenTokens.Accent.violetSoft }
        return LumenTokens.TextColor.muted
    }

    // MARK: - Scroll body

    private var calendarScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(weeks, id: \.self) { weekStart in
                        WeekRow(
                            weekStart: weekStart,
                            layout: layoutByWeek[weekStart] ?? WeekLayout(weekStart: weekStart, bars: [], overflowByCol: [:])
                        )
                        .frame(height: weekRowHeight)
                        .id(weekKey(weekStart))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
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
                    proxy.scrollTo(weekKey(CalendarDateUtils.startOfWeek(of: Date())), anchor: .center)
                }
            }
            .onChange(of: resetToTodayToken) { _, _ in
                // 부모가 token을 증가시키면 오늘로 부드럽게 점프.
                let target = CalendarDateUtils.startOfWeek(of: Date())
                visibleAnchor = target
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(weekKey(target), anchor: .center)
                }
            }
            .onChange(of: scrollTarget) { _, newTarget in
                guard let target = newTarget else { return }
                withAnimation(.easeOut(duration: 0.25)) {
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
        let firstWeek = CalendarDateUtils.startOfWeek(of: cal.date(byAdding: .day, value: -90, to: today) ?? today)
        let lastWeek = CalendarDateUtils.startOfWeek(of: cal.date(byAdding: .day, value: +90, to: today) ?? today)
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
            dict[weekStart] = layoutWeek(weekStart: weekStart, items: items, maxLanes: maxLanesPerWeek)
        }
        layoutByWeek = dict
    }

    private func weekKey(_ d: Date) -> String {
        CalendarDateUtils.key(d, prefix: "w")
    }
}


// MARK: - WeekRow

private struct WeekRow: View {
    let weekStart: Date
    let layout: WeekLayout
    private let laneHeight: CGFloat = 18
    private let laneSpacing: CGFloat = 2
    private let topPadding: CGFloat = 22  // 날짜 숫자 자리
    /// Jira 막대 클릭 시 띄울 popover의 대상 issue key — nil이면 닫힘.
    @State private var previewingKey: String? = nil
    /// 셀 더블클릭 시 새 이벤트 popover의 anchor 날짜.
    @State private var newEventDate: Date? = nil
    /// 로컬 막대 클릭 시 편집 popover의 대상 이벤트.
    @State private var editingEvent: LocalEvent? = nil
    /// EKEvent 막대 클릭 시 띄울 미리보기 — bar.item.id를 anchor로 사용.
    @State private var previewingEKBarID: String? = nil

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

                // 3) overflow 표시
                ForEach(Array(layout.overflowByCol.keys), id: \.self) { col in
                    if let n = layout.overflowByCol[col] {
                        Text("+\(n)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(LumenTokens.TextColor.muted)
                            .padding(.horizontal, 3)
                            .padding(.leading, CGFloat(col) * cellW + 4)
                            .padding(.top, topPadding + CGFloat(4) * (laneHeight + laneSpacing) + 1)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
    }

    private func cellBackground(day: Date, cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(day)
        let dayNum = cal.component(.day, from: day)
        let isFirstOfMonth = (dayNum == 1)
        let holidayName = KoreanHolidays.name(for: day)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if isFirstOfMonth {
                    Text(monthDayLabel(day))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(holidayName != nil ? LumenTokens.CalendarTone.holiday : LumenTokens.Accent.violetSoft)
                } else {
                    Text("\(dayNum)")
                        .font(.system(size: 11, weight: isToday ? .bold : .regular,
                                      design: .monospaced))
                        .foregroundStyle(dayNumberColor(day: day, isToday: isToday, holidayName: holidayName))
                }
                if let name = holidayName {
                    Text(name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(LumenTokens.CalendarTone.holiday)
                        .lineLimit(1)
                }
                Spacer()
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(width: cellWidth, height: cellHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isToday ? LumenTokens.Accent.amber.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(LumenTokens.divider, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        // 셀 빈 영역 더블클릭 → 그 날짜로 새 이벤트 popover.
        // 막대(Button)가 그 위에 있으면 막대가 hit-test 우선이라 그 영역은 빠진다.
        .onTapGesture(count: 2) {
            newEventDate = day
        }
        .popover(isPresented: Binding(
            get: { newEventDate != nil && Calendar.current.isDate(newEventDate!, inSameDayAs: day) },
            set: { if !$0 { newEventDate = nil } }
        ), arrowEdge: .top) {
            NewEventPopover(initialDate: day) { newEventDate = nil }
        }
    }

    private func barView(bar: LaidOutBar, cellW: CGFloat) -> some View {
        let leading = CGFloat(bar.startCol) * cellW + 2
        let width = cellW * CGFloat(bar.span) - 4
        let topOffset = topPadding + CGFloat(bar.lane) * (laneHeight + laneSpacing)
        let isLocal = (bar.item.kind == .local)
        let barColor = bar.item.customColor ?? bar.item.projectKey.map { jiraProjectColor($0) } ?? bar.item.kind.color
        let hasDot = bar.item.customColor == nil

        return Button {
            // 로컬 → 편집 popover, Jira → 이슈 미리보기, EKEvent → 캘린더 이벤트 미리보기.
            if isLocal, let ev = matchingLocalEvent(barID: bar.item.id) {
                editingEvent = ev
            } else if bar.item.kind == .googleCalendar {
                previewingEKBarID = bar.item.id
            } else if let key = bar.item.issueKey {
                previewingKey = key
            }
        } label: {
            HStack(spacing: 4) {
                if hasDot {
                    Circle()
                        .fill(bar.item.kind.color)
                        .frame(width: 5, height: 5)
                }
                Text(bar.item.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(bar.item.isDone
                                     ? LumenTokens.TextColor.muted
                                     : (isLocal ? LumenTokens.TextColor.secondary : LumenTokens.TextColor.primary))
                    .strikethrough(bar.item.isDone, color: LumenTokens.TextColor.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 5)
            .frame(width: width, height: laneHeight - 2, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isLocal ? Color.white.opacity(0.04) : barColor.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(
                        isLocal ? LumenTokens.TextColor.muted.opacity(0.55) : barColor.opacity(0.45),
                        style: StrokeStyle(lineWidth: 0.5, dash: isLocal ? [3, 2] : [])
                    )
            )
        }
        .buttonStyle(.plain)
        .help(bar.item.issueKey.map { "\($0) · \(bar.item.title)" } ?? bar.item.title)
        .popover(isPresented: Binding(
            get: { previewingKey != nil && previewingKey == bar.item.issueKey },
            set: { if !$0 { previewingKey = nil } }
        ), arrowEdge: .top) {
            if let key = bar.item.issueKey {
                IssuePreviewPopover(issueKey: key)
            }
        }
        .popover(isPresented: Binding(
            get: { editingEvent != nil && editingEvent.flatMap { matchingBarID(eventID: $0.id) } == bar.item.id },
            set: { if !$0 { editingEvent = nil } }
        ), arrowEdge: .top) {
            if let ev = editingEvent {
                LocalEventEditPopover(event: ev) { editingEvent = nil }
            }
        }
        .popover(isPresented: Binding(
            get: { previewingEKBarID == bar.item.id },
            set: { if !$0 { previewingEKBarID = nil } }
        ), arrowEdge: .top) {
            if let ev = matchingEKEvent(barID: bar.item.id) {
                EKEventPreviewPopover(event: ev)
            }
        }
        .padding(.leading, leading)
        .padding(.top, topOffset)
    }

    /// CalendarItem.id ("gcal-{eventIdentifier}") → EventKitService에서 EKEvent 조회.
    private func matchingEKEvent(barID: String) -> EKEvent? {
        guard barID.hasPrefix("gcal-") else { return nil }
        let id = String(barID.dropFirst("gcal-".count))
        return EventKitService.shared.event(withIdentifier: id)
    }

    /// CalendarItem.id ("local-{uuid}") → 그 UUID에 해당하는 LocalEvent를 store에서 찾는다.
    private func matchingLocalEvent(barID: String) -> LocalEvent? {
        guard barID.hasPrefix("local-"),
              let uuid = UUID(uuidString: String(barID.dropFirst("local-".count))) else { return nil }
        return LocalEventStore.shared.events.first { $0.id == uuid }
    }

    /// LocalEvent.id → bar.item.id 형식으로 변환.
    private func matchingBarID(eventID: UUID) -> String {
        "local-\(eventID.uuidString)"
    }

    private func monthDayLabel(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: day)
    }

    /// 날짜 숫자의 색 우선순위: today > 공휴일 > 기본.
    private func dayNumberColor(day: Date, isToday: Bool, holidayName: String?) -> Color {
        if isToday { return LumenTokens.Accent.amber }
        if holidayName != nil { return LumenTokens.CalendarTone.holiday }
        return LumenTokens.TextColor.primary
    }
}
