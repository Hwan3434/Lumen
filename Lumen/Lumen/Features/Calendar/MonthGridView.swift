import SwiftUI
import AppKit

struct MonthGridView: View {
    let items: [CalendarItem]
    @Binding var anchorMonth: Date

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayRow
            grid
        }
        // 위·아래 스크롤휠 / 트랙패드 스와이프로 월 이동.
        .onScrollWheel { dy in
            if dy > 0 { shiftMonth(-1) } else if dy < 0 { shiftMonth(1) }
        }
        .gesture(
            // 트랙패드/마우스 드래그 — 일정 거리 이상 위/아래로 끌면 한 달 이동.
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height > 30 { shiftMonth(-1) }
                    else if value.translation.height < -30 { shiftMonth(1) }
                }
        )
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack(spacing: 12) {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LumenTokens.TextColor.muted)

            Text(monthLabel)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.primary)
                .frame(minWidth: 110)

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LumenTokens.TextColor.muted)

            Button("오늘") { anchorMonth = Calendar.current.startOfMonth(for: Date()) }
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
        return f.string(from: anchorMonth)
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

    // MARK: - Grid

    private var grid: some View {
        let days = monthGridDays()
        return GeometryReader { proxy in
            let cellW = (proxy.size.width - 24) / 7
            let cellH = (proxy.size.height - 12) / CGFloat(days.count / 7)
            VStack(spacing: 0) {
                ForEach(0..<(days.count / 7), id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let day = days[row * 7 + col]
                            cell(day: day, cellWidth: cellW, cellHeight: cellH)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private func cell(day: Date, cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        let cal = Calendar.current
        let inMonth = cal.isDate(day, equalTo: anchorMonth, toGranularity: .month)
        let isToday = cal.isDateInToday(day)
        let dayNum = cal.component(.day, from: day)
        let dayItems = items.filter { $0.covers(day) }

        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(dayNum)")
                    .font(.system(size: 11, weight: isToday ? .bold : .regular,
                                  design: .monospaced))
                    .foregroundStyle(inMonth
                                     ? (isToday ? LumenTokens.Accent.amber : LumenTokens.TextColor.primary)
                                     : LumenTokens.TextColor.muted.opacity(0.5))
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
        Button {
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
                    .fill(item.kind.color.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
        .help(item.title)
    }

    // MARK: - Day generation

    /// anchorMonth가 속한 달의 1일 직전 일요일부터 6주(=42일)를 반환한다.
    private func monthGridDays() -> [Date] {
        let cal = Calendar.current
        let startOfMonth = cal.startOfMonth(for: anchorMonth)
        let weekdayOf1st = cal.component(.weekday, from: startOfMonth) // 1=일
        let firstCellDate = cal.date(byAdding: .day, value: -(weekdayOf1st - 1), to: startOfMonth)!
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: firstCellDate) }
    }

    private func shiftMonth(_ delta: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: delta, to: anchorMonth) {
            anchorMonth = next
        }
    }
}

// MARK: - Calendar utility

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

// MARK: - Scroll wheel modifier
//
// SwiftUI는 스크롤휠을 직접 노출하지 않는다. NSViewRepresentable로 한 겹 깔고
// scrollWheel(with:)에서 deltaY를 받아 클로저로 흘려보낸다.

extension View {
    func onScrollWheel(_ handler: @escaping (CGFloat) -> Void) -> some View {
        self.background(ScrollWheelCatcher(handler: handler))
    }
}

private struct ScrollWheelCatcher: NSViewRepresentable {
    let handler: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WheelView()
        view.handler = handler
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WheelView)?.handler = handler
    }

    private final class WheelView: NSView {
        var handler: ((CGFloat) -> Void)?
        // 디바운스 — 트랙패드 한 번 휙 하면 deltaY가 여러 번 들어와 월이 한꺼번에 여러 칸 넘어간다.
        private var lastFireAt: TimeInterval = 0

        override var acceptsFirstResponder: Bool { false }
        override func hitTest(_ point: NSPoint) -> NSView? { nil } // 자식 hit-test 양보

        override func scrollWheel(with event: NSEvent) {
            let dy = event.scrollingDeltaY
            guard abs(dy) > 1 else { return }
            let now = Date().timeIntervalSince1970
            guard now - lastFireAt > 0.25 else { return }
            lastFireAt = now
            handler?(dy)
        }
    }
}
