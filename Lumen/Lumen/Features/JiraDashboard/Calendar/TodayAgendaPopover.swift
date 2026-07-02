import EventKit
import SwiftUI

/// 메뉴바 클릭 시 뜨는 오늘 일정 미리보기.
/// Jira(스프린트/에픽/태스크) + 로컬 이벤트 + EKEvent를 한 곳에 모아 종일/시간 그룹으로 보여준다.
struct TodayAgendaPopover: View {
    @State private var service = EventKitService.shared

    var body: some View {
        let items = todaysItems
        let groups = grouped(items: items)
        return ZStack(alignment: .top) {
            LumenGlassBackground(radius: 12)
            VStack(alignment: .leading, spacing: 0) {
                header(count: items.count)

                if groups.allDay.isEmpty && groups.timed.isEmpty {
                    Spacer()
                    empty
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if !groups.timed.isEmpty {
                                section(title: "시간 일정", items: groups.timed)
                            }
                            if !groups.allDay.isEmpty {
                                section(title: "종일 / 마감", items: groups.allDay)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                        .padding(.top, 4)
                    }
                    .frame(maxHeight: 400)
                }
            }
        }
        .frame(width: 320)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func header(count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LumenTokens.Accent.violetSoft)
            Text(Self.headerLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.primary)
            Spacer()
            Text(count == 0 ? "" : "\(count)개")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 22))
                .foregroundStyle(LumenTokens.TextColor.muted)
            Text("오늘 일정이 없습니다")
                .font(.system(size: 12))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func section(title: String, items: [CalendarItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.muted)
                .textCase(.uppercase)
            VStack(spacing: 6) {
                ForEach(items, id: \.id) { item in
                    AgendaRow(item: item)
                }
            }
        }
    }

    // MARK: - Data

    private var todaysItems: [CalendarItem] {
        let day = Date()
        return adaptedItems().filter { $0.covers(day) }
    }

    private func adaptedItems() -> [CalendarItem] {
        var items: [CalendarItem] = []
        for ev in LocalEventStore.shared.events {
            items.append(CalendarItem(
                id: "local-\(ev.id.uuidString)",
                kind: .local,
                title: ev.title,
                start: ev.start,
                end: ev.end,
                issueKey: nil,
                isDone: false,
                projectKey: nil
            ))
        }
        for ev in service.events {
            guard let start = ev.startDate, let end = ev.endDate else { continue }
            let effectiveEnd = ev.isAllDay ? cal.date(byAdding: .day, value: -1, to: end) ?? end : end
            items.append(CalendarItem(
                id: "gcal-\(ev.eventIdentifier ?? ev.calendarItemIdentifier)",
                kind: .googleCalendar,
                title: ev.title ?? "(제목 없음)",
                start: start,
                end: ev.isAllDay
                    ? (cal.isDate(start, inSameDayAs: effectiveEnd) ? nil : effectiveEnd)
                    : end,
                issueKey: nil,
                isDone: false,
                projectKey: nil,
                customColor: Color(cgColor: ev.calendar.cgColor),
                hasTimeOfDay: !ev.isAllDay,
                location: ev.location
            ))
        }
        // Jira 이슈 — 팝오버에만 표시 (상태바 라벨 제외)
        if let data = JiraService.shared.data {
            items += CalendarAdapter.buildItems(from: data, includeLocal: false)
        }
        return items
    }

    private let cal = Calendar.current

    private struct Groups {
        let allDay: [CalendarItem]
        let timed: [CalendarItem]
    }

    private func grouped(items: [CalendarItem]) -> Groups {
        var allDay: [CalendarItem] = []
        var timed: [CalendarItem] = []
        for item in items {
            if item.hasTimeOfDay {
                timed.append(item)
            } else {
                allDay.append(item)
            }
        }
        timed.sort { $0.start < $1.start }
        allDay.sort { $0.title < $1.title }
        return Groups(allDay: allDay, timed: timed)
    }

    private static let headerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f
    }()

    private static var headerLabel: String {
        Self.headerDateFormatter.string(from: Date()) + " 일정"
    }
}

private struct AgendaRow: View {
    let item: CalendarItem
    @State private var showingPreview = false

    var body: some View {
        Button {
            showingPreview = true
        } label: {
            HStack(alignment: .top, spacing: 9) {
                Circle()
                    .fill(barColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(item.isDone ? LumenTokens.TextColor.muted : LumenTokens.TextColor.primary)
                        .strikethrough(item.isDone, color: LumenTokens.TextColor.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        Text(timeLabel)
                        if let loc = item.location, !loc.isEmpty {
                            Text("·")
                            Text(loc)
                                .lineLimit(1)
                        }
                    }
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(LumenTokens.stroke, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPreview, arrowEdge: .trailing) {
            previewPopover
        }
    }

    private var barColor: Color {
        item.customColor ?? item.projectKey.map { jiraProjectColor($0) } ?? item.kind.color
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f
    }()

    private var timeLabel: String {
        if !item.hasTimeOfDay {
            switch item.kind {
            case .epic, .task: return "마감 \(Self.dayFormatter.string(from: item.start))"
            case .sprint: return "스프린트"
            default: return "종일"
            }
        }
        let f = Self.timeFormatter
        if let end = item.end {
            return "\(f.string(from: item.start)) – \(f.string(from: end))"
        }
        return f.string(from: item.start)
    }

    @ViewBuilder
    private var previewPopover: some View {
        if let key = item.issueKey, item.kind != .local {
            IssuePreviewPopover(issueKey: key)
        } else if item.kind == .googleCalendar {
            ekEventPreview
        } else {
            // 스프린트나 로컬 — 간단 정보만.
            CalendarPreviewLayout(
                accentColor: barColor,
                accentLabel: item.kind.label,
                title: item.title,
                metaRows: [.init(icon: "clock", text: timeLabel)]
            )
        }
    }

    @ViewBuilder
    private var ekEventPreview: some View {
        if item.id.hasPrefix("gcal-") {
            let id = String(item.id.dropFirst("gcal-".count))
            if let ev = EventKitService.shared.event(withIdentifier: id) {
                EKEventPreviewPopover(event: ev)
            }
        }
    }
}
