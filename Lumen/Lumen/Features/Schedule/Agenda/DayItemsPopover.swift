import SwiftUI

private typealias P = LumenTokens.Palette

/// 월간 칸의 "+N"을 눌렀을 때 뜨는 그날 일정 전체. 기간 항목(스프린트)도 함께 보여 준다 —
/// 칸에서 잘린 막대가 무엇이었는지 알 수 있도록.
struct DayItemsPopover: View {
    @Environment(ScheduleStore.self) private var store
    let day: Date

    var body: some View {
        let items = CalendarItemSort.ordered(store.visibleItems.filter { $0.covers(day) })
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: LumenTokens.Space.inline) {
                Text(LumenDateFormat.dayWithWeekday.string(from: day))
                    .lumenText(.body, weight: .semibold)
                    .monospacedDigit()
                    .foregroundStyle(P.ink)
                Spacer()
                Text("\(items.count)개")
                    .lumenText(.caption)
                    .monospacedDigit()
                    .foregroundStyle(P.inkFaint)
            }
            .padding(.horizontal, LumenTokens.Space.pad)
            .padding(.vertical, LumenTokens.Space.s4)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        ScheduleItemRow(item: item, popoverEdge: .trailing)
                    }
                }
                .padding(.horizontal, LumenTokens.Space.inline)
                .padding(.bottom, LumenTokens.Space.inline)
            }
            .frame(maxHeight: CalendarPreviewMetrics.maxPopoverHeight)
        }
        .frame(width: LumenTokens.Space.size(380))
        .fixedSize(horizontal: false, vertical: true)
        .background(P.surfaceRaised)
    }
}
