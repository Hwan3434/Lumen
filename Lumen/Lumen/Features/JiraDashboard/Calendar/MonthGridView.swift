import SwiftUI
import AppKit

// 월간 캘린더 — 한 달씩 교체 방식이 아니라, ±3개월(=약 26주)을 하나의 vertical ScrollView 안에
// 이어 붙여 부드럽게 스크롤하는 iCalendar 스타일. 헤더의 "yyyy년 M월"은 가시 영역 중앙 주의
// month로 따라 갱신된다. 사용자가 "오늘"을 누르면 오늘이 속한 주로 애니메이션 스크롤.

struct MonthGridView: View {
    let items: [CalendarItem]

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    private let weekRowHeight: CGFloat = 100

    /// 가시 중앙 주의 시작일 — onScrollGeometryChange로 갱신.
    @State private var visibleAnchor: Date = startOfWeek(of: Date())
    @State private var weeks: [Date] = []  // 각 원소가 startOfWeek (일요일)

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayRow
            calendarScroll
        }
        .onAppear { weeks = buildWeeks() }
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
        // 가시 영역 중앙 주의 month — 같은 주에 두 달이 걸쳐있으면 *목요일* 기준으로 결정
        // (ISO week의 정통 규칙). 월 라벨이 흔들림 없이 안정적으로 바뀐다.
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

    @State private var scrollTarget: Date? = nil  // "오늘" 버튼 등 코드로 점프할 때 사용

    private var calendarScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    ForEach(weeks, id: \.self) { weekStart in
                        weekRow(weekStart: weekStart)
                            .frame(height: weekRowHeight)
                            .id(weekKey(weekStart))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .scrollTargetLayout()
            }
            .onScrollGeometryChange(for: Date.self) { geo in
                // 가시 영역 정중앙(y) 위치에 해당하는 주를 추정.
                let centerY = geo.contentOffset.y + geo.containerSize.height / 2
                let topPadding: CGFloat = 0  // weeks가 0번째부터 시작
                let idx = Int((centerY - topPadding) / weekRowHeight)
                let clamped = max(0, min(weeks.count - 1, idx))
                return weeks.indices.contains(clamped) ? weeks[clamped] : visibleAnchor
            } action: { _, newValue in
                if !Calendar.current.isDate(newValue, inSameDayAs: visibleAnchor) {
                    visibleAnchor = newValue
                }
            }
            .onAppear {
                // 첫 진입 시 오늘이 속한 주가 화면 중앙에 오도록.
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

    // MARK: - Week row

    private func weekRow(weekStart: Date) -> some View {
        let cal = Calendar.current
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
        return GeometryReader { proxy in
            let cellW = proxy.size.width / 7
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    cell(day: day, cellWidth: cellW, cellHeight: proxy.size.height)
                }
            }
        }
    }

    private func cell(day: Date, cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(day)
        let dayNum = cal.component(.day, from: day)
        let isFirstOfMonth = (dayNum == 1)
        let dayItems = items.filter { $0.covers(day) }
        // 같은 달인지 판정은 visibleAnchor가 아니라 그 주의 목요일 기준 — header와 일관.
        let weekStart = Self.startOfWeek(of: day)
        let referenceMonth = cal.date(byAdding: .day, value: 3, to: weekStart) ?? day
        let inReferenceMonth = cal.isDate(day, equalTo: referenceMonth, toGranularity: .month)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if isFirstOfMonth {
                    // 새 달 첫날엔 "M월 d일" 형태로 month 시각화. 무한 스크롤에서 달 경계가 한눈에.
                    Text(monthDayLabel(day))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(LumenTokens.Accent.violetSoft)
                } else {
                    Text("\(dayNum)")
                        .font(.system(size: 11, weight: isToday ? .bold : .regular,
                                      design: .monospaced))
                        .foregroundStyle(inReferenceMonth
                                         ? (isToday ? LumenTokens.Accent.amber : LumenTokens.TextColor.primary)
                                         : LumenTokens.TextColor.muted.opacity(0.5))
                }
                Spacer()
            }
            ForEach(dayItems.prefix(3)) { item in
                pill(item)
            }
            if dayItems.count > 3 {
                Text("+\(dayItems.count - 3)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .padding(.leading, 2)
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
    }

    private func pill(_ item: CalendarItem) -> some View {
        // 배경 = 프로젝트 색, 좌측 점 = 종류 색. 두 시그널을 분리.
        let projectColor = item.projectKey.map { jiraProjectColor($0) } ?? item.kind.color
        return Button {
            if let url = item.openURL { NSWorkspace.shared.open(url) }
        } label: {
            HStack(spacing: 3) {
                Circle()
                    .fill(item.kind.color)
                    .frame(width: 5, height: 5)
                Text(item.title)
                    .font(.system(size: 10))
                    .foregroundStyle(item.isDone
                                     ? LumenTokens.TextColor.muted
                                     : LumenTokens.TextColor.secondary)
                    .strikethrough(item.isDone, color: LumenTokens.TextColor.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(projectColor.opacity(0.18))
            )
        }
        .buttonStyle(.plain)
        .help(item.title)
    }

    private func monthDayLabel(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: day)
    }

    // MARK: - Week generation

    /// ±3개월 = -90 ~ +90일을 포함하는 주들의 시작일(일요일) 배열.
    /// data fetch 윈도우(JiraService의 ±3M)와 정확히 일치한다.
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

    private func weekKey(_ d: Date) -> String {
        let cal = Calendar.current
        let comp = cal.dateComponents([.year, .month, .day], from: d)
        return "w-\(comp.year ?? 0)-\(comp.month ?? 0)-\(comp.day ?? 0)"
    }

    /// 일요일 시작 기준 주의 시작일 (자정).
    static func startOfWeek(of date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 1  // 일요일
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }
}

// MARK: - Calendar utility (다른 뷰와 공유)

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
