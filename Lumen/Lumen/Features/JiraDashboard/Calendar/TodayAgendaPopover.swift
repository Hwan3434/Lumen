import EventKit
import SwiftUI

private typealias P = LumenTokens.Palette

/// 메뉴바 클릭 시 뜨는 오늘 일정 미리보기.
/// Jira(스프린트/에픽/태스크) + 로컬 이벤트 + EKEvent를 한 곳에 모아 종일/시간 그룹으로 보여준다.
struct TodayAgendaPopover: View {
    @State private var service = EventKitService.shared

    var body: some View {
        let items = todaysItems
        let groups = grouped(items: items)
        return VStack(alignment: .leading, spacing: 0) {
            header(count: items.count)

            if groups.allDay.isEmpty && groups.timed.isEmpty {
                Spacer()
                empty
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: LumenTokens.Space.group) {
                        if !groups.timed.isEmpty {
                            section(title: "시간 일정", items: groups.timed)
                        }
                        if !groups.allDay.isEmpty {
                            section(title: "종일 · 마감", items: groups.allDay)
                        }
                    }
                    .padding(.horizontal, LumenTokens.Space.s4)
                    .padding(.bottom, LumenTokens.Space.s4)
                }
            }
        }
        .frame(width: 380, height: 520, alignment: .top)
        .background(P.surfaceRaised)
        .clipShape(LumenShape.rect(LumenTokens.Radius.lg))
        .overlay(LumenShape.rect(LumenTokens.Radius.lg).strokeBorder(P.borderSubtle, lineWidth: 1))
    }

    private func header(count: Int) -> some View {
        HStack(spacing: LumenTokens.Space.inline) {
            LumenIcon("calendar")
                .foregroundStyle(P.inkMuted)
            Text(Self.headerLabel)
                .lumenText(.body, weight: .semibold)
                .foregroundStyle(P.ink)
            Spacer()
            Text(count == 0 ? "" : "\(count)개")
                .lumenText(.caption)
                .monospacedDigit()
                .foregroundStyle(P.inkFaint)
        }
        .padding(.horizontal, LumenTokens.Space.pad)
        .padding(.vertical, LumenTokens.Space.s4)
    }

    private var empty: some View {
        LumenEmptyState(icon: "calendar-check", text: "오늘은 일정이 없어요")
        .frame(maxWidth: .infinity)
        .padding(.vertical, LumenTokens.Space.s6)
    }

    private func section(title: String, items: [CalendarItem]) -> some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.inline) {
            LumenSectionLabel(text: title)
                .padding(.horizontal, LumenTokens.Space.inline)
            VStack(spacing: 0) {
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
            let effectiveEnd = ev.isAllDay ? cal.date(byAdding: .day, value: -1, to: ev.endDate) ?? ev.endDate : ev.endDate
            items.append(CalendarItem(
                id: "gcal-\(ev.id)",
                kind: .googleCalendar,
                title: ev.title,
                start: ev.startDate,
                end: ev.isAllDay
                    ? (cal.isDate(ev.startDate, inSameDayAs: effectiveEnd) ? nil : effectiveEnd)
                    : ev.endDate,
                issueKey: nil,
                isDone: false,
                projectKey: nil,
                customColor: Color(cgColor: ev.calendarColor),
                hasTimeOfDay: !ev.isAllDay,
                location: ev.location
            ))
        }
        // Jira 이슈 — 팝오버에만 표시 (상태바 라벨 제외)
        if let data = JiraService.shared.data {
            items += CalendarAdapter.buildItems(from: data)
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
        timed = CalendarItemSort.ordered(timed)
        allDay = CalendarItemSort.ordered(allDay)
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
    /// ⌘클릭이면 설명 대신 댓글 팝오버를 띄운다.
    @State private var showingComments = false

    var body: some View {
        Button {
            showingComments = isCommandClick
            showingPreview = true
        } label: {
            HStack(alignment: .top, spacing: LumenTokens.Space.s3) {
                LumenDot(color: barColor)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
                    Text(item.title)
                        .lumenText(.body, weight: .medium)
                        .foregroundStyle(item.isDone ? P.inkFaint : P.ink)
                        .strikethrough(item.isDone, color: P.inkFaint)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: LumenTokens.Space.s1) {
                        Text(timeLabel)
                        if let loc = item.location, !loc.isEmpty {
                            Text("·")
                            Text(loc)
                                .lineLimit(1)
                        }
                    }
                    .lumenText(.caption)
                    .foregroundStyle(P.inkFaint)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, LumenTokens.Space.s3)
            .padding(.horizontal, LumenTokens.Space.inline)
            .contentShape(Rectangle())
        }
        .buttonStyle(LumenListRowStyle())
        // 이슈는 조회를 마친 뒤에 떠야 크기가 내용에 맞는다(IssuePopoverPresenter 참고).
        // 캘린더 이벤트·스프린트는 이미 값이 있으므로 바로 띄운다.
        .popover(isPresented: Binding(
            get: { showingPreview && !isIssueItem },
            set: { if !$0 { showingPreview = false } }
        ), arrowEdge: .trailing) {
            previewPopover
        }
        .issuePreviewPopover(
            issueKey: isIssueItem ? item.issueKey : nil,
            isPresented: Binding(
                get: { showingPreview && isIssueItem && !showingComments },
                set: { if !$0 { showingPreview = false } }
            ),
            arrowEdge: .trailing
        )
        .issueCommentsPopover(
            issueKey: isIssueItem ? item.issueKey : nil,
            isPresented: Binding(
                get: { showingPreview && isIssueItem && showingComments },
                set: { if !$0 { showingPreview = false } }
            ),
            arrowEdge: .trailing
        )
    }

    /// Jira 이슈 행인지 — 로컬 일정은 issueKey가 있어도 이슈가 아니다.
    private var isIssueItem: Bool {
        item.issueKey != nil && item.kind != .local
    }

    private var barColor: Color {
        item.customColor ?? item.projectKey.map { jiraProjectColor($0) } ?? item.kind.color
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
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
        if item.kind == .googleCalendar {
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
