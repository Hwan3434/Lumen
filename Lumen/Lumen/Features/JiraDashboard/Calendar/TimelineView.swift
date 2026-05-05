import SwiftUI
import AppKit

// 타임라인 = agenda 뷰. Gantt 막대(row당 task 1개)에서 "날짜 헤더 + 그날의 항목 리스트"로 전환.
//
// 정책:
//  - 다일 task는 매 날짜에 등장. 시작일이 아닌 날의 행은 톤 다운(이미 진행 중 시그널).
//  - 빈 날짜는 생략 (정보 밀도).
//  - 한 날짜 안 정렬: 로컬 → 에픽 → 스프린트 → 태스크. 같은 종류 안에선 시작일 → 제목.
//  - 범위는 ±3개월(=fetch 윈도우와 동기화). 처음 진입 시 오늘에 anchor scroll.
//  - 클릭 동작: Jira 항목 → 기존 미리보기 popover, 로컬 항목 → 편집 popover.

struct TimelineView: View {
    let items: [CalendarItem]
    @Binding var anchorDate: Date

    /// Jira preview popover의 anchor — entry.id (즉 "{itemID}|{day}") 기준.
    /// 같은 task가 여러 row에 펼쳐져 있을 때, 클릭한 그 row에 정확히 popover가 뜨게 한다.
    @State private var previewingEntryID: String? = nil
    @State private var editingEvent: LocalEvent? = nil

    private static let cal = Calendar.current

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 4, pinnedViews: [.sectionHeaders]) {
                    ForEach(daySections, id: \.day) { section in
                        Section(header: dayHeader(section.day, count: section.entries.count)) {
                            ForEach(section.entries, id: \.id) { entry in
                                row(entry)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .id(dayKey(section.day))
                    }
                }
                .padding(.vertical, 8)
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(dayKey(Self.cal.startOfDay(for: anchorDate)), anchor: .top)
                }
            }
        }
    }

    // MARK: - Section model

    /// agenda의 한 줄 — 같은 task가 다일이면 여러 entry로 쪼개진다.
    private struct Entry {
        let id: String          // "{item.id}|{day yyyymmdd}" — ForEach 안정성
        let item: CalendarItem
        let day: Date
        /// item.start가 아닌 날 = "이미 진행 중인 day".
        var isContinuation: Bool { !Self.cal.isDate(day, inSameDayAs: item.start) }
        private static let cal = Calendar.current
    }

    private struct DaySection {
        let day: Date
        let entries: [Entry]
    }

    private var daySections: [DaySection] {
        // 1. item × covered-day 쌍 펼치기
        var byDay: [Date: [Entry]] = [:]
        for item in items {
            let s = Self.cal.startOfDay(for: item.start)
            let e = Self.cal.startOfDay(for: item.end ?? item.start)
            // ±3개월 윈도우 클램핑 — 가시 범위 밖은 의미 없음.
            let rangeStart = Self.cal.date(byAdding: .day, value: -90, to: Self.cal.startOfDay(for: Date()))!
            let rangeEnd   = Self.cal.date(byAdding: .day, value: +90, to: Self.cal.startOfDay(for: Date()))!
            let from = max(s, rangeStart)
            let to   = min(e, rangeEnd)
            guard from <= to else { continue }
            var cursor = from
            while cursor <= to {
                let key = "\(item.id)|\(dayKey(cursor))"
                byDay[cursor, default: []].append(Entry(id: key, item: item, day: cursor))
                cursor = Self.cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }
        }

        // 2. 날짜별 정렬: 미래가 위로 (날짜 desc). 같은 날짜 안은 종류 묶음 → (시작일, 제목)
        let kindOrder: [CalendarItemKind: Int] = [.local: 0, .epic: 1, .sprint: 2, .task: 3]
        return byDay.keys.sorted(by: >).map { day in
            let entries = byDay[day]!.sorted { a, b in
                let oa = kindOrder[a.item.kind] ?? 99
                let ob = kindOrder[b.item.kind] ?? 99
                if oa != ob { return oa < ob }
                if a.item.start != b.item.start { return a.item.start < b.item.start }
                return a.item.title < b.item.title
            }
            return DaySection(day: day, entries: entries)
        }
    }

    // MARK: - Header / row views

    private func dayHeader(_ day: Date, count: Int) -> some View {
        let isToday = Self.cal.isDateInToday(day)
        return HStack(spacing: 8) {
            Text(dayLabel(day))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(isToday ? LumenTokens.Accent.amber : LumenTokens.TextColor.primary)
            Text(weekdayLabel(day))
                .font(.system(size: 11))
                .foregroundStyle(weekdayColor(day))
            if isToday {
                Text("오늘")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(LumenTokens.Accent.amber)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(LumenTokens.Accent.amber.opacity(0.45), lineWidth: 0.5)
                    )
            }
            Spacer()
            Text("\(count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(LumenTokens.BG.sidePanel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LumenTokens.divider).frame(height: 0.5)
        }
    }

    private func row(_ entry: Entry) -> some View {
        let item = entry.item
        let isLocal = (item.kind == .local)
        let projectColor = item.projectKey.map { jiraProjectColor($0) } ?? item.kind.color
        let isContinuation = entry.isContinuation

        return Button {
            if isLocal, let ev = matchingLocalEvent(itemID: item.id) {
                editingEvent = ev
            } else if item.issueKey != nil {
                previewingEntryID = entry.id
            }
        } label: {
            HStack(spacing: 8) {
                // 좌측 색 바 — 종류 색
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(item.kind.color.opacity(isContinuation ? 0.35 : 0.85))
                    .frame(width: 3, height: 16)

                // 키 (Jira만)
                if let key = item.issueKey {
                    Text(key)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(LumenTokens.Accent.violetSoft.opacity(isContinuation ? 0.5 : 1))
                        .frame(minWidth: 70, alignment: .leading)
                }

                // 제목
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(item.isDone
                                     ? LumenTokens.TextColor.muted
                                     : (isContinuation ? LumenTokens.TextColor.muted : LumenTokens.TextColor.primary))
                    .strikethrough(item.isDone, color: LumenTokens.TextColor.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                // 진행중 표시 (다일 task의 두번째 이후 날)
                if isContinuation {
                    Text("진행 중")
                        .font(.system(size: 10))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                } else if let end = item.end, !Self.cal.isDate(item.start, inSameDayAs: end) {
                    Text(spanLabel(start: item.start, end: end))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }

                // 종류 (회색 chip)
                Text(item.kind.label)
                    .font(.system(size: 9.5, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(item.kind.color.opacity(isContinuation ? 0.5 : 0.85))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isLocal ? Color.white.opacity(0.04) : projectColor.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(
                                        item.kind.color.opacity(0.35),
                                        style: StrokeStyle(lineWidth: 0.5, dash: isLocal ? [3, 2] : [])
                                    )
                            )
                    )
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(item.issueKey.map { "\($0) · \(item.title)" } ?? item.title)
        // entry.id로 매칭 — 다일 task가 여러 row에 등장해도 정확히 클릭한 row에 popover.
        .popover(isPresented: Binding(
            get: { previewingEntryID == entry.id },
            set: { if !$0 { previewingEntryID = nil } }
        ), arrowEdge: .leading) {
            if let key = item.issueKey {
                IssuePreviewPopover(issueKey: key)
            }
        }
        .popover(isPresented: Binding(
            get: { editingEvent != nil && editingEvent.flatMap { "local-\($0.id.uuidString)" } == item.id },
            set: { if !$0 { editingEvent = nil } }
        ), arrowEdge: .leading) {
            if let ev = editingEvent {
                LocalEventEditPopover(event: ev) { editingEvent = nil }
            }
        }
    }

    // MARK: - Helpers

    private func matchingLocalEvent(itemID: String) -> LocalEvent? {
        guard itemID.hasPrefix("local-"),
              let uuid = UUID(uuidString: String(itemID.dropFirst("local-".count))) else { return nil }
        return LocalEventStore.shared.events.first { $0.id == uuid }
    }

    private func dayKey(_ d: Date) -> String {
        let comp = Self.cal.dateComponents([.year, .month, .day], from: d)
        return "d-\(comp.year ?? 0)-\(comp.month ?? 0)-\(comp.day ?? 0)"
    }

    private func dayLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }

    private func weekdayLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "EEEE"
        return f.string(from: d)
    }

    private func weekdayColor(_ d: Date) -> Color {
        let w = Self.cal.component(.weekday, from: d)
        if w == 1 { return Color(red: 0xE1/255, green: 0xA0/255, blue: 0xA0/255) }
        if w == 7 { return LumenTokens.Accent.violetSoft }
        return LumenTokens.TextColor.muted
    }

    private func spanLabel(start: Date, end: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M/d"
        return "\(f.string(from: start)) → \(f.string(from: end))"
    }
}
