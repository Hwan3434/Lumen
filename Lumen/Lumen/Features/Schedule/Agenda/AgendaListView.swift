import AppKit
import SwiftUI

private typealias P = LumenTokens.Palette

/// 일정 대시보드 왼쪽 열. 모든 플러그인 항목을 날짜로 묶어 한 줄씩 보여 준다.
/// 위에는 플러그인 오류·설정 안내 배너, 연동이 하나도 없으면 안내 카드를 둔다.
struct AgendaListView: View {
    @Environment(ScheduleStore.self) private var store
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let sections = AgendaBuckets.sections(
            items: store.visibleItems,
            now: store.now,
            firstWeekday: DashboardSettingsStore.shared.settings.weekStartsOn.calendarValue
        )
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: LumenTokens.Space.group) {
                ForEach(store.failures) { failure in
                    failureBanner(failure)
                }
                ForEach(hintPlugins, id: \.id.rawValue) { plugin in
                    LumenBanner(tone: .warning, title: "\(plugin.displayName) 설정이 필요해요", message: plugin.setupHint) {
                        settingsButton
                    }
                }
                if !hasIntegration {
                    noIntegrationCard
                }
                if sections.isEmpty {
                    if hasIntegration {
                        LumenEmptyState(icon: "calendar-check", text: "다가오는 일정이 없어요")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, LumenTokens.Space.s6)
                    }
                } else {
                    ForEach(sections) { section in
                        AgendaSectionView(section: section, today: store.today)
                    }
                }
            }
            .padding(LumenTokens.Space.pad)
        }
    }

    /// 내 일정 말고 연동 플러그인이 하나라도 켜져 있는지.
    private var hasIntegration: Bool {
        store.enabledPlugins.contains { $0.id != .local }
    }

    private var hintPlugins: [any SchedulePlugin] {
        store.enabledPlugins.filter { $0.setupHint != nil }
    }

    private func failureBanner(_ failure: ScheduleStore.Failure) -> some View {
        LumenBanner(
            tone: .danger,
            title: "\(failure.plugin.displayName) 일정을 불러오지 못했어요",
            message: "\(failure.message)\n마지막으로 받은 내용을 그대로 보여주고 있어요."
        ) {
            HStack(spacing: LumenTokens.Space.inline) {
                Button {
                    Task { await store.refresh(failure.plugin.id, force: true) }
                } label: {
                    Label { Text("다시 시도") } icon: { LumenIcon("rotate-cw", size: .small) }
                }
                .buttonStyle(LumenButtonStyle(variant: .secondary, size: .small))
                settingsButton
            }
        }
    }

    private var noIntegrationCard: some View {
        VStack(spacing: LumenTokens.Space.stack) {
            LumenIcon("calendar-plus", size: .large)
                .foregroundStyle(P.inkFaint)
            Text("연동한 일정이 아직 없어요.\n설정에서 일정 출처를 켜면 여기에 함께 보여요.")
                .lumenText(.label, weight: .regular)
                .foregroundStyle(P.inkMuted)
                .multilineTextAlignment(.center)
            settingsButton
            Text("빈 날짜를 두 번 누르면 내 일정을 바로 추가할 수 있어요.")
                .lumenText(.caption)
                .foregroundStyle(P.inkFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LumenTokens.Space.s6)
        .padding(.horizontal, LumenTokens.Space.pad)
        .lumenCard()
    }

    private var settingsButton: some View {
        Button("설정 열기") {
            NSApp.activate()
            openSettings()
        }
        .buttonStyle(LumenButtonStyle(variant: .ghost, size: .small))
    }
}

/// 날짜 묶음 하나. 머리를 눌러 접고, 펼침 여부는 묶음마다 기억한다.
private struct AgendaSectionView: View {
    let section: AgendaSection
    let today: Date
    @AppStorage private var expanded: Bool

    init(section: AgendaSection, today: Date) {
        self.section = section
        self.today = today
        _expanded = AppStorage(wrappedValue: true,
                               "schedule.agenda.\(section.bucket.rawValue).expanded")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.inline) {
            Button {
                withAnimation(LumenTokens.Motion.easeOut()) { expanded.toggle() }
            } label: {
                header
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(expanded ? "접기" : "펼치기")

            if expanded {
                LumenList(section.items, inset: LumenTokens.Space.s1) { item in
                    ScheduleItemRow(item: item, popoverEdge: .trailing)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: LumenTokens.Space.inline) {
            LumenIcon("chevron-right", size: .small)
                .foregroundStyle(P.inkFaint)
                .rotationEffect(.degrees(expanded ? 90 : 0))
            LumenIcon(section.bucket.iconName, size: .small)
                .foregroundStyle(section.bucket == .overdue ? P.danger : P.inkMuted)
            Text(section.bucket.title)
                .lumenText(.label)
                .foregroundStyle(P.inkMuted)
            Text(caption)
                .lumenText(.caption)
                .monospacedDigit()
                .foregroundStyle(P.inkFaint)
        }
    }

    /// "11. 7 (토) · 3"처럼 하루짜리 묶음은 날짜를, 나머지는 개수만.
    private var caption: String {
        let count = "\(section.items.count)"
        let cal = Calendar.current
        switch section.bucket {
        case .today:
            return "\(LumenDateFormat.shortDayWithWeekday.string(from: today)) · \(count)"
        case .tomorrow:
            let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
            return "\(LumenDateFormat.shortDayWithWeekday.string(from: tomorrow)) · \(count)"
        default:
            return count
        }
    }
}
