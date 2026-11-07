import AppKit
import SwiftUI

/// 플러그인이 따로 상세를 내주지 않는 항목(스프린트 같은 기간)의 기본 미리보기.
struct ScheduleItemPreview: View {
    let item: ScheduleItem
    let accent: Color

    var body: some View {
        CalendarPreviewLayout(
            accentColor: accent,
            accentLabel: item.subtitle ?? item.title,
            title: item.title,
            metaRows: metaRows,
            footer: { footer }
        )
    }

    private var metaRows: [PreviewMetaRow] {
        var rows: [PreviewMetaRow] = []
        rows.append(.init(icon: "clock", text: ScheduleItemFormat.timeLabel(item)))
        if let location = item.location, !location.isEmpty {
            rows.append(.init(icon: "map-pin", text: location))
        }
        return rows
    }

    @ViewBuilder
    private var footer: some View {
        if let url = item.url {
            HStack(spacing: LumenTokens.Space.inline) {
                Spacer()
                Button {
                    openScheduleURL(url)
                } label: {
                    Label { Text("열기") } icon: { LumenIcon("external-link", size: .small) }
                }
                .buttonStyle(LumenButtonStyle(variant: .secondary, size: .small))
            }
            .padding(.horizontal, LumenTokens.Space.pad)
            .padding(.bottom, LumenTokens.Space.s4)
            .background(LumenTokens.Palette.surfaceRaised)
        }
    }
}

/// 항목을 출처 쪽(브라우저)에서 열고 패널을 내린다. 외부 앱으로 넘어가는 길이라 이전 앱 복귀는 막는다.
@MainActor
func openScheduleURL(_ url: URL) {
    NSWorkspace.shared.open(url)
    if let panel = NSApp.keyWindow as? KeyablePanel {
        panel.activatePreviousAppOnClose = false
        panel.orderOut(nil)
    }
}

/// 항목의 시각·마감 표기. 목록 두 번째 줄과 미리보기가 같은 글을 쓴다. Still 규칙: `오후 2:30`, `2026. 11. 7 (토)`.
enum ScheduleItemFormat {
    static func timeLabel(_ item: ScheduleItem) -> String {
        let cal = Calendar.current
        let day = LumenDateFormat.dayWithWeekday
        let time = LumenDateFormat.time

        if item.hasTimeOfDay {
            guard let end = item.end else { return "\(day.string(from: item.start)) \(time.string(from: item.start))" }
            if cal.isDate(item.start, inSameDayAs: end) {
                return "\(day.string(from: item.start)) \(time.string(from: item.start)) – \(time.string(from: end))"
            }
            return "\(day.string(from: item.start)) \(time.string(from: item.start)) – \(day.string(from: end)) \(time.string(from: end))"
        }

        switch item.kind {
        case .task:
            if let end = item.end, !cal.isDate(item.start, inSameDayAs: end) {
                return "\(day.string(from: item.start)) – \(day.string(from: end))"
            }
            return "마감 \(day.string(from: item.start))"
        case .event, .span:
            if let end = item.end, !cal.isDate(item.start, inSameDayAs: end) {
                return "\(day.string(from: item.start)) – \(day.string(from: end))"
            }
            return "\(day.string(from: item.start)) · 종일"
        }
    }

    /// 목록 두 번째 줄용 짧은 표기. 날짜는 묶음 머리가 말해 주므로 시각이나 마감만.
    static func shortLabel(_ item: ScheduleItem, relativeTo today: Date = Date()) -> String {
        let cal = Calendar.current
        let time = LumenDateFormat.time
        if item.hasTimeOfDay {
            guard let end = item.end else { return time.string(from: item.start) }
            return "\(time.string(from: item.start)) – \(time.string(from: end))"
        }
        switch item.kind {
        case .task:
            let due = item.end ?? item.start
            if cal.isDate(due, inSameDayAs: today) { return "마감 오늘" }
            return "마감 \(LumenDateFormat.shortDay.string(from: due))"
        case .event, .span:
            if let end = item.end, !cal.isDate(item.start, inSameDayAs: end) {
                return "\(LumenDateFormat.shortDay.string(from: item.start)) – \(LumenDateFormat.shortDay.string(from: end))"
            }
            return "종일"
        }
    }
}
