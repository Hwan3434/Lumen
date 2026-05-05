import SwiftUI

struct CalendarView: View {
    private var service: JiraService { JiraService.shared }

    private enum Mode: String { case month, timeline }
    @State private var mode: Mode = .month
    @State private var filter = CalendarFilter()
    @State private var anchorMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var anchorDate: Date = Date()

    var body: some View {
        ZStack {
            LumenGlassBackground(radius: LumenTokens.Radius.window)
            VStack(spacing: 0) {
                titleStrip
                LumenHairline()
                controlStrip
                LumenHairline()
                content
                LumenHairline()
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: LumenTokens.Radius.window, style: .continuous))
        .task {
            if service.data == nil { await service.fetch() }
        }
    }

    // MARK: - Title strip

    private var titleStrip: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LumenTokens.Accent.violetSoft)
                Text("Jira 캘린더")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                if let last = service.data?.lastUpdated {
                    Rectangle()
                        .fill(LumenTokens.divider)
                        .frame(width: 1, height: 12)
                    Text(LumenTime.relative(last, granularity: .minutesAndHours))
                        .font(.system(size: 11))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }
            }
            Spacer()
            Button {
                Task { await service.fetch(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
            .help("새로고침")
            .disabled(service.isLoading)
        }
        .padding(.horizontal, 14)
        .draggableWindowHeader()
        .frame(height: 40)
    }

    // MARK: - Control strip (mode toggle + filters)

    private var controlStrip: some View {
        HStack(spacing: 14) {
            modeToggle
            Rectangle().fill(LumenTokens.divider).frame(width: 1, height: 16)
            filterToggles
            Spacer()
            if service.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
    }

    private var modeToggle: some View {
        HStack(spacing: 4) {
            modeButton("월간", value: .month)
            modeButton("타임라인", value: .timeline)
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04))
        )
    }

    private func modeButton(_ label: String, value: Mode) -> some View {
        Button {
            mode = value
        } label: {
            Text(label)
                .font(.system(size: 11, weight: mode == value ? .semibold : .regular))
                .foregroundStyle(mode == value
                                 ? LumenTokens.TextColor.primary
                                 : LumenTokens.TextColor.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(mode == value ? LumenTokens.Accent.violet.opacity(0.22) : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var filterToggles: some View {
        HStack(spacing: 8) {
            filterChip(label: "에픽",   color: LumenTokens.Accent.violet,        isOn: $filter.showEpic)
            filterChip(label: "스프린트", color: LumenTokens.Accent.amber,         isOn: $filter.showSprint)
            filterChip(label: "태스크",  color: LumenTokens.TextColor.secondary,   isOn: $filter.showTask)
        }
    }

    private func filterChip(label: String, color: Color, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(isOn.wrappedValue ? color : color.opacity(0.25))
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isOn.wrappedValue
                                     ? LumenTokens.TextColor.secondary
                                     : LumenTokens.TextColor.muted)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isOn.wrappedValue ? color.opacity(0.35) : LumenTokens.divider, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        if service.isLoading && service.data == nil {
            placeholder("불러오는 중…")
        } else if let msg = service.errorMessage, service.data == nil {
            placeholder("오류: \(msg)")
        } else if let data = service.data {
            let baseURL = jiraBaseURL()
            let allItems = CalendarAdapter.buildItems(from: data, baseURL: baseURL)
            let visible = allItems.filter { filter.passes($0) }
            switch mode {
            case .month:
                MonthGridView(items: visible, anchorMonth: $anchorMonth)
            case .timeline:
                TimelineView(items: visible, anchorDate: $anchorDate)
            }
        } else {
            placeholder("데이터 없음")
        }
    }

    private func jiraBaseURL() -> String? {
        let slug = CredentialsStore.shared.jiraWorkspaceSlug
        guard !slug.isEmpty else { return nil }
        return "https://\(slug).atlassian.net"
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(LumenTokens.TextColor.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        LumenFooterBar(actions: [
            .init(label: "Jira로 열기", kbd: "⏎"),
            .init(label: "닫기", kbd: "esc"),
            .init(label: "패널", kbd: "⌘⇧G"),
        ])
    }
}
