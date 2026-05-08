import EventKit
import SwiftUI

/// EKEvent 막대 클릭 시 뜨는 읽기 전용 미리보기 popover.
/// 캘린더에서 가져온 이벤트라 편집은 캘린더.app에서 — 우리는 보기만.
struct EKEventPreviewPopover: View {
    let event: EKEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Text(event.title ?? "(제목 없음)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            timeRow

            if let location = event.location, !location.isEmpty {
                infoRow(icon: "mappin.and.ellipse", text: location)
            }
            if let url = event.url {
                infoRow(icon: "link", text: url.absoluteString)
            }
            if let notes = event.notes, !notes.isEmpty {
                ScrollView {
                    Text(notes)
                        .font(.system(size: 11.5))
                        .foregroundStyle(LumenTokens.TextColor.secondary)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 160)
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 9, height: 9)
            Text(event.calendar.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LumenTokens.TextColor.secondary)
                .lineLimit(1)
            if let source = event.calendar.source?.title, !source.isEmpty {
                Text(source)
                    .font(.system(size: 10.5))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private var timeRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(LumenTokens.TextColor.muted)
            Text(timeText)
                .font(.system(size: 11.5))
                .foregroundStyle(LumenTokens.TextColor.secondary)
                .textSelection(.enabled)
        }
    }

    private var timeText: String {
        guard let start = event.startDate else { return "" }
        let cal = Calendar.current
        if event.isAllDay {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ko_KR")
            f.dateFormat = "yyyy.MM.dd (E)"
            // EKEvent.endDate는 종일 이벤트의 다음날 00:00이라 -1일.
            let endInclusive = cal.date(byAdding: .day, value: -1, to: event.endDate ?? start) ?? start
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
        let end = event.endDate ?? start
        if cal.isDate(start, inSameDayAs: end) {
            return "\(dayF.string(from: start)) \(timeF.string(from: start)) – \(timeF.string(from: end))"
        }
        return "\(dayF.string(from: start)) \(timeF.string(from: start)) → \(dayF.string(from: end)) \(timeF.string(from: end))"
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(LumenTokens.TextColor.muted)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(LumenTokens.TextColor.secondary)
                .lineLimit(3)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
