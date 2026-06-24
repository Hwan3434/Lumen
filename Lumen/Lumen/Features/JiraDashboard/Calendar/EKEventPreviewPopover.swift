import SwiftUI

/// EKEvent 막대 클릭 시 뜨는 읽기 전용 미리보기.
/// 캘린더에서 가져온 이벤트라 편집은 캘린더.app에서 — 우리는 보기만.
struct EKEventPreviewPopover: View {
    let event: ExternalCalendarEvent

    var body: some View {
        CalendarPreviewLayout(
            accentColor: Color(cgColor: event.calendarColor),
            accentLabel: event.calendarTitle,
            badgeText: event.sourceTitle,
            title: event.title,
            metaRows: metaRows,
            bodyText: event.notes
        )
    }

    private var metaRows: [CalendarPreviewLayout<EmptyView, EmptyView>.MetaRow] {
        var rows: [CalendarPreviewLayout<EmptyView, EmptyView>.MetaRow] = []
        rows.append(.init(icon: "clock", text: timeText))
        if let location = event.location, !location.isEmpty {
            rows.append(.init(icon: "mappin.and.ellipse", text: location))
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
            let f = DateFormatter()
            f.locale = Locale(identifier: "ko_KR")
            f.dateFormat = "yyyy.MM.dd (E)"
            // EKEvent.endDate는 종일 이벤트의 다음날 00:00이라 -1일.
            let endInclusive = cal.date(byAdding: .day, value: -1, to: event.endDate) ?? start
            if cal.isDate(start, inSameDayAs: endInclusive) {
                return "\(f.string(from: start)) · 종일"
            }
            return "\(f.string(from: start)) → \(f.string(from: endInclusive)) · 종일"
        }
        let dayF = DateFormatter()
        dayF.locale = Locale(identifier: "ko_KR")
        dayF.dateFormat = "yyyy.MM.dd (E)"
        let timeF = DateFormatter()
        timeF.locale = Locale(identifier: "ko_KR")
        timeF.dateFormat = "HH:mm"
        let end = event.endDate
        if cal.isDate(start, inSameDayAs: end) {
            return "\(dayF.string(from: start)) \(timeF.string(from: start)) – \(timeF.string(from: end))"
        }
        return "\(dayF.string(from: start)) \(timeF.string(from: start)) → \(dayF.string(from: end)) \(timeF.string(from: end))"
    }
}
