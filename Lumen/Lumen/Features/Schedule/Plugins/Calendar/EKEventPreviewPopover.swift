import SwiftUI

/// 캘린더 이벤트 막대를 눌렀을 때 뜨는 읽기 전용 미리보기.
/// 캘린더에서 가져온 이벤트라 편집은 캘린더 앱에서 한다.
struct EKEventPreviewPopover: View {
    let event: ExternalCalendarEvent
    /// 항목의 시각 표기(`ScheduleItemFormat.timeLabel`). 종일 끝 날짜 규칙을 여기서 다시 계산하지 않는다.
    let timeLabel: String
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
        rows.append(.init(icon: "clock", text: timeLabel))
        if let location = event.location, !location.isEmpty {
            rows.append(.init(icon: "map-pin", text: location))
        }
        if let url = event.urlString {
            rows.append(.init(icon: "link", text: url))
        }
        return rows
    }
}
