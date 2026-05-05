import SwiftUI
import AppKit

// 타임라인: 가로축 = 날짜 (하루 = 일정 픽셀), 세로축 = 항목 행.
// 시간축이 가로이므로 시간 이동도 가로 스크롤이 정상 — 트랙패드 좌·우 스와이프 또는
// 마우스 ⇧+휠이 가로 ScrollView로 그대로 들어간다. 위/아래 입력은 항목이 많아 화면을
// 넘칠 때 vertical scroll에 쓰일 여지를 위해 비워둔다 (현재는 한 화면에 다 들어옴).
//
// 항목은 kind별 영역(에픽 → 스프린트 → 태스크)으로 구분되고, 각 영역 안에서는 start 오름차순.

struct TimelineView: View {
    let items: [CalendarItem]
    @Binding var anchorDate: Date

    /// 하루의 가로 픽셀 폭. 4주를 한 화면에 보이게 하는 게 디폴트.
    private let dayWidth: CGFloat = 36
    private let rowHeight: CGFloat = 24
    private let groupSpacing: CGFloat = 12
    /// 가시 영역 좌·우로 충분히 그려서 스크롤 직후 빈 영역이 안 보이게.
    private let halfRangeDays: Int = 60

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    timelineContent(visibleWidth: proxy.size.width)
                }
                .onAppear { scrollProxy.scrollTo(anchorID, anchor: .center) }
                .onChange(of: anchorDate) { _, _ in
                    withAnimation(.easeOut(duration: 0.18)) {
                        scrollProxy.scrollTo(anchorID, anchor: .center)
                    }
                }
            }
        }
    }

    private var anchorID: String { dayKey(anchorDate) }

    // MARK: - Content

    @ViewBuilder
    private func timelineContent(visibleWidth: CGFloat) -> some View {
        let groups: [(CalendarItemKind, [CalendarItem])] = [
            (.epic,    items.filter { $0.kind == .epic    }.sorted { $0.start < $1.start }),
            (.sprint,  items.filter { $0.kind == .sprint  }.sorted { $0.start < $1.start }),
            (.task,    items.filter { $0.kind == .task    }.sorted { $0.start < $1.start }),
        ]
        let nonEmpty = groups.filter { !$0.1.isEmpty }
        let dayRange = visibleDayRange()

        VStack(alignment: .leading, spacing: groupSpacing) {
            dayAxis(dayRange: dayRange)
            ForEach(Array(nonEmpty.enumerated()), id: \.offset) { _, pair in
                groupSection(kind: pair.0, items: pair.1, dayRange: dayRange)
            }
            if nonEmpty.isEmpty {
                Text("표시할 항목이 없습니다")
                    .font(.system(size: 12))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minWidth: visibleWidth, alignment: .topLeading)
    }

    private func groupSection(kind: CalendarItemKind, items: [CalendarItem], dayRange: [Date]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: kind.iconName)
                    .font(.system(size: 10, weight: .semibold))
                Text(kind.label)
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.4)
                Text("\(items.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
            .foregroundStyle(kind.color)
            .padding(.bottom, 2)

            ZStack(alignment: .topLeading) {
                gridLines(dayRange: dayRange, rowCount: items.count)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(items) { item in
                        timelineRow(item: item, dayRange: dayRange)
                    }
                }
            }
        }
    }

    private func timelineRow(item: CalendarItem, dayRange: [Date]) -> some View {
        let cal = Calendar.current
        let rangeStart = dayRange.first!
        let startOffset = max(0, cal.dateComponents([.day], from: rangeStart, to: item.start).day ?? 0)
        let endDate = cal.startOfDay(for: item.end ?? item.start)
        let endOffset = (cal.dateComponents([.day], from: rangeStart, to: endDate).day ?? startOffset) + 1
        let leading = CGFloat(startOffset) * dayWidth
        let width = max(dayWidth, CGFloat(endOffset - startOffset) * dayWidth)

        return ZStack(alignment: .leading) {
            // 행 자체의 배경 — 호버용. 일단 없음.
            HStack { Spacer() }
                .frame(height: rowHeight)

            Button {
                if let url = item.openURL { NSWorkspace.shared.open(url) }
            } label: {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(item.isDone
                                         ? LumenTokens.TextColor.muted
                                         : LumenTokens.TextColor.primary)
                        .strikethrough(item.isDone, color: LumenTokens.TextColor.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 6)
                .frame(width: width, height: rowHeight - 4, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(item.kind.color.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(item.kind.color.opacity(0.45), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help(item.title)
            .padding(.leading, leading)
        }
        .frame(height: rowHeight, alignment: .leading)
    }

    private func dayAxis(dayRange: [Date]) -> some View {
        let cal = Calendar.current
        return HStack(spacing: 0) {
            ForEach(dayRange, id: \.self) { day in
                let weekday = cal.component(.weekday, from: day) // 1=일
                let dayNum = cal.component(.day, from: day)
                let isFirstOfMonth = cal.component(.day, from: day) == 1
                let isToday = cal.isDateInToday(day)
                VStack(spacing: 1) {
                    if isFirstOfMonth {
                        Text(monthShort(day))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(LumenTokens.Accent.violetSoft)
                    } else {
                        Text(" ").font(.system(size: 9))
                    }
                    Text("\(dayNum)")
                        .font(.system(size: 10, weight: isToday ? .bold : .regular,
                                      design: .monospaced))
                        .foregroundStyle(isToday
                                         ? LumenTokens.Accent.amber
                                         : (weekday == 1 || weekday == 7
                                            ? LumenTokens.TextColor.muted
                                            : LumenTokens.TextColor.secondary))
                }
                .frame(width: dayWidth, height: 28)
                .id(dayKey(day))
            }
        }
    }

    private func gridLines(dayRange: [Date], rowCount: Int) -> some View {
        let cal = Calendar.current
        let height = max(1, CGFloat(rowCount) * (rowHeight + 2))
        return HStack(spacing: 0) {
            ForEach(Array(dayRange.enumerated()), id: \.offset) { _, day in
                let weekday = cal.component(.weekday, from: day)
                let isWeekend = (weekday == 1 || weekday == 7)
                let isToday = cal.isDateInToday(day)
                Rectangle()
                    .fill(isToday
                          ? LumenTokens.Accent.amber.opacity(0.06)
                          : (isWeekend ? Color.white.opacity(0.015) : Color.clear))
                    .frame(width: dayWidth, height: height)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(LumenTokens.divider)
                            .frame(width: 0.5, height: height)
                    }
            }
        }
    }

    // MARK: - Helpers

    private func visibleDayRange() -> [Date] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -halfRangeDays, to: cal.startOfDay(for: anchorDate))!
        return (0..<(halfRangeDays * 2)).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func dayKey(_ d: Date) -> String {
        let cal = Calendar.current
        let comp = cal.dateComponents([.year, .month, .day], from: d)
        return "\(comp.year ?? 0)-\(comp.month ?? 0)-\(comp.day ?? 0)"
    }

    private func monthShort(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월"
        return f.string(from: d)
    }
}
