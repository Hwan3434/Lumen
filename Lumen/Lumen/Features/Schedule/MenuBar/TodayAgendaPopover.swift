import SwiftUI

private typealias P = LumenTokens.Palette

/// 메뉴바 클릭 시 뜨는 오늘 일정 미리보기. 보이는 모든 플러그인의 오늘 항목을 시간/종일 그룹으로 보여준다.
struct TodayAgendaPopover: View {
    @Environment(ScheduleStore.self) private var store

    var body: some View {
        let items = store.items(on: Date())
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
        .frame(width: Constants.agendaPanelSize.width, height: Constants.agendaPanelSize.height, alignment: .top)
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

    private func section(title: String, items: [ScheduleItem]) -> some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.inline) {
            LumenSectionLabel(text: title)
                .padding(.horizontal, LumenTokens.Space.inline)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    AgendaRow(item: item)
                }
            }
        }
    }

    private struct Groups {
        let allDay: [ScheduleItem]
        let timed: [ScheduleItem]
    }

    private func grouped(items: [ScheduleItem]) -> Groups {
        let timed = CalendarItemSort.ordered(items.filter(\.hasTimeOfDay))
        let allDay = CalendarItemSort.ordered(items.filter { !$0.hasTimeOfDay })
        return Groups(allDay: allDay, timed: timed)
    }

    private static let headerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f
    }()

    private static var headerLabel: String {
        headerDateFormatter.string(from: Date()) + " 일정"
    }
}

private struct AgendaRow: View {
    @Environment(ScheduleStore.self) private var store
    let item: ScheduleItem
    @State private var showingDetail = false
    @State private var variant: ScheduleDetailVariant = .primary

    var body: some View {
        Button {
            variant = isCommandClick ? .secondary : .primary
            showingDetail = true
        } label: {
            HStack(alignment: .top, spacing: LumenTokens.Space.s3) {
                LumenDot(color: store.color(for: item))
                    .padding(.top, LumenTokens.Space.scaled(8))
                VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
                    Text(item.title)
                        .lumenText(.body, weight: .medium)
                        .foregroundStyle(item.isDone ? P.inkFaint : P.ink)
                        .strikethrough(item.isDone, color: P.inkFaint)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: LumenTokens.Space.s1) {
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                            Text("·")
                        }
                        Text(ScheduleItemFormat.shortLabel(item))
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
        .scheduleDetailPopover(item: item, variant: variant, isPresented: $showingDetail, arrowEdge: .trailing)
    }
}
