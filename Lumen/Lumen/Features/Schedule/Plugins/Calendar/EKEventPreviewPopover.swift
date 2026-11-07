import SwiftUI

/// 캘린더 이벤트 막대를 눌렀을 때 뜨는 읽기 전용 미리보기.
/// 캘린더에서 가져온 이벤트라 편집은 캘린더 앱에서 한다.
struct EKEventPreviewPopover: View {
    let event: ExternalCalendarEvent
    let accent: Color

    var body: some View {
        CalendarPreviewLayout(
            accentColor: accent,
            accentLabel: event.calendarTitle,
            badgeText: event.sourceTitle,
            title: event.title,
            metaRows: metaRows,
            bodyText: event.notes
        )
    }

    private var metaRows: [PreviewMetaRow] {
        var rows: [PreviewMetaRow] = []
        rows.append(.init(icon: "clock", text: timeText))
        if let location = event.location, !location.isEmpty {
            rows.append(.init(icon: "map-pin", text: location))
        }
        if let url = event.urlString {
            rows.append(.init(icon: "link", text: url))
        }
        return rows
    }

    private var timeText: String {
        let start = event.startDate
        let cal = Calendar.current
        if event.isAllDay {
            // EKEvent.endDate는 종일 이벤트의 다음날 00:00이라 -1일.
            let endInclusive = cal.date(byAdding: .day, value: -1, to: event.endDate) ?? start
            if cal.isDate(start, inSameDayAs: endInclusive) {
                return "\(LumenDateFormat.dayWithWeekday.string(from: start)) · 종일"
            }
            return "\(LumenDateFormat.dayWithWeekday.string(from: start)) – \(LumenDateFormat.dayWithWeekday.string(from: endInclusive)) · 종일"
        }
        let end = event.endDate
        let dayF = LumenDateFormat.dayWithWeekday
        let timeF = LumenDateFormat.time
        if cal.isDate(start, inSameDayAs: end) {
            return "\(dayF.string(from: start)) \(timeF.string(from: start)) – \(timeF.string(from: end))"
        }
        return "\(dayF.string(from: start)) \(timeF.string(from: start)) – \(dayF.string(from: end)) \(timeF.string(from: end))"
    }
}
