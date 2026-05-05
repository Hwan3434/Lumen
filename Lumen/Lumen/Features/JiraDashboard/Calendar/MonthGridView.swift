import SwiftUI
import AppKit

// 월간 캘린더 — iCalendar 스타일 무한 스크롤.
// ±3개월(=약 26주)의 주들을 LazyVStack으로 이어 붙이고, 각 주 위에 막대(bar) layer를 깔아
// 다일 task가 셀 경계에서 끊기지 않고 하나의 막대로 표현되게 한다.
//
// 데이터는 init/onChange 시점에 weekLayouts 사전을 한 번만 만들어 매 body 호출의 filter
// 비용을 없앤다 — 121개 task × 42셀 × 6주를 매번 도는 게 탭 전환 시 버벅임의 주 원인이었다.

struct MonthGridView: View {
    let items: [CalendarItem]

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    private let weekRowHeight: CGFloat = 110
    /// 한 주에 보일 수 있는 막대(레인) 최대 갯수. 넘는 건 "+N" 으로.
    private let maxLanesPerWeek: Int = 4

    /// 가시 중앙 주의 시작일 — onScrollGeometryChange로 갱신.
    @State private var visibleAnchor: Date = startOfWeek(of: Date())
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
                let today = Self.startOfWeek(of: Date())
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

            Spacer()
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

    private func weekdayColor(_ index: Int) -> Color {
        if index == 0 { return Color(red: 0xE1/255, green: 0xA0/255, blue: 0xA0/255) }
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
                    proxy.scrollTo(weekKey(Self.startOfWeek(of: Date())), anchor: .center)
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
        let firstWeek = Self.startOfWeek(of: cal.date(byAdding: .day, value: -90, to: today) ?? today)
        let lastWeek = Self.startOfWeek(of: cal.date(byAdding: .day, value: +90, to: today) ?? today)
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
        let cal = Calendar.current
        let comp = cal.dateComponents([.year, .month, .day], from: d)
        return "w-\(comp.year ?? 0)-\(comp.month ?? 0)-\(comp.day ?? 0)"
    }

    static func startOfWeek(of date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 1  // 일요일
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }
}

// MARK: - Calendar utility

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

// MARK: - Week layout (one row's worth of bars)

struct LaidOutBar: Identifiable {
    let item: CalendarItem
    let startCol: Int  // 0...6
    let span: Int      // 1...7
    let lane: Int      // 0부터
    var id: String { "\(item.id)|\(startCol)|\(span)" }
}

struct WeekLayout {
    let weekStart: Date
    let bars: [LaidOutBar]
    /// 그 주의 col별로 maxLanes를 넘어 잘려나간 task 갯수.
    let overflowByCol: [Int: Int]
}

/// 주어진 주에 걸쳐 있는 task들을 막대로 배치한다.
/// 알고리즘:
///   1. 주에 걸치는 item만 추출 → (start asc, span desc)로 정렬
///   2. 각 item에 lane 부여 — 가장 위 lane부터 보며 그 구간(startCol..<startCol+span)이 비어있는 첫 lane
///   3. lane >= maxLanes 면 overflow로 카운트 (해당 col별로)
private func layoutWeek(weekStart: Date, items: [CalendarItem], maxLanes: Int) -> WeekLayout {
    let cal = Calendar.current
    let weekStartDay = cal.startOfDay(for: weekStart)
    let weekEndDay = cal.date(byAdding: .day, value: 6, to: weekStartDay)!

    // 후보 — 주에 걸쳐 있는 item만, start asc / span desc 로 정렬해 layout이 안정.
    struct Candidate {
        let item: CalendarItem
        let startCol: Int
        let span: Int
    }
    var candidates: [Candidate] = []
    for item in items {
        let s = cal.startOfDay(for: item.start)
        let e = cal.startOfDay(for: item.end ?? item.start)
        // 주와 안 겹치면 스킵
        if e < weekStartDay || s > weekEndDay { continue }
        // 주에 잘려서 들어오는 시작/끝
        let clampedStart = max(s, weekStartDay)
        let clampedEnd = min(e, weekEndDay)
        let startCol = (cal.dateComponents([.day], from: weekStartDay, to: clampedStart).day ?? 0)
        let endCol = (cal.dateComponents([.day], from: weekStartDay, to: clampedEnd).day ?? 0)
        let span = max(1, endCol - startCol + 1)
        candidates.append(Candidate(item: item, startCol: startCol, span: span))
    }
    candidates.sort { a, b in
        if a.startCol != b.startCol { return a.startCol < b.startCol }
        return a.span > b.span
    }

    // lanes[i][col] = 그 lane의 col이 사용 중인가
    var lanes: [[Bool]] = []
    var bars: [LaidOutBar] = []
    var overflowByCol: [Int: Int] = [:]

    for c in candidates {
        // 들어갈 lane 찾기
        var assigned: Int? = nil
        for laneIdx in 0..<lanes.count {
            var fits = true
            for col in c.startCol..<(c.startCol + c.span) {
                if lanes[laneIdx][col] { fits = false; break }
            }
            if fits { assigned = laneIdx; break }
        }
        let lane = assigned ?? lanes.count
        if assigned == nil {
            lanes.append(Array(repeating: false, count: 7))
        }
        for col in c.startCol..<(c.startCol + c.span) {
            lanes[lane][col] = true
        }

        if lane < maxLanes {
            bars.append(LaidOutBar(item: c.item, startCol: c.startCol, span: c.span, lane: lane))
        } else {
            // overflow — 막대가 걸친 모든 col에 +1 카운트
            for col in c.startCol..<(c.startCol + c.span) {
                overflowByCol[col, default: 0] += 1
            }
        }
    }

    return WeekLayout(weekStart: weekStart, bars: bars, overflowByCol: overflowByCol)
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

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if isFirstOfMonth {
                    Text(monthDayLabel(day))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(LumenTokens.Accent.violetSoft)
                } else {
                    Text("\(dayNum)")
                        .font(.system(size: 11, weight: isToday ? .bold : .regular,
                                      design: .monospaced))
                        .foregroundStyle(isToday ? LumenTokens.Accent.amber : LumenTokens.TextColor.primary)
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
        let projectColor = bar.item.projectKey.map { jiraProjectColor($0) } ?? bar.item.kind.color

        return Button {
            // 로컬 이벤트 막대 → 편집 popover. Jira 막대 → 미리보기 popover.
            if isLocal, let ev = matchingLocalEvent(barID: bar.item.id) {
                editingEvent = ev
            } else if let key = bar.item.issueKey {
                previewingKey = key
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(bar.item.kind.color)
                    .frame(width: 5, height: 5)
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
                    .fill(isLocal ? Color.white.opacity(0.04) : projectColor.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(
                        isLocal ? LumenTokens.TextColor.muted.opacity(0.55) : projectColor.opacity(0.45),
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
        .padding(.leading, leading)
        .padding(.top, topOffset)
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
}
