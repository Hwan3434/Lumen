import SwiftUI

private typealias P = LumenTokens.Palette

/// Cmd+, 로 열리는 macOS 기본 설정창의 루트 뷰.
/// 사이드바는 "일반"(UI, 숨긴 앱, 전원)과 "일정"(대시보드, 플러그인별 탭)으로 나뉜다.
/// 플러그인 탭은 `SchedulePlugins.all` 중 `hasSettingsTab`인 것만 등록 순서대로 나온다.
struct SettingsView: View {
    enum Tab: Hashable {
        case ui, hiddenApps, power
        case dashboard
        case plugin(SchedulePluginID)

        var label: String {
            switch self {
            case .ui:         return "UI"
            case .hiddenApps: return "숨긴 앱"
            case .power:      return "전원"
            case .dashboard:  return "대시보드"
            case .plugin(let id): return SchedulePlugins.plugin(id)?.displayName ?? id.rawValue
            }
        }

        var icon: String {
            switch self {
            case .ui:         return "palette"
            case .hiddenApps: return "eye-off"
            case .power:      return "flame"
            case .dashboard:  return "layout-grid"
            case .plugin(let id): return SchedulePlugins.plugin(id)?.iconName ?? "circle-help"
            }
        }
    }

    static let generalTabs: [Tab] = [.ui, .hiddenApps, .power]
    static var scheduleTabs: [Tab] {
        [.dashboard] + SchedulePlugins.all.filter(\.hasSettingsTab).map { .plugin($0.id) }
    }

    @State private var selection: Tab = .dashboard
    // 각 탭이 ActionBar(저장 / 초기화 / 저장됨)에 자기 액션을 주입한다.
    @State private var actionVM = SettingsActionViewModel()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(P.borderSubtle).frame(width: 1)
            contentArea
        }
        .frame(width: Constants.settingsWindowSize.width, height: Constants.settingsWindowSize.height)
        // 창 배경 자체를 글래스로 — 떠 있는 패널과 같은 투명도를 쓴다.
        .containerBackground(for: .window) { LumenGlassFill() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarSection(title: "일반", tabs: Self.generalTabs)
            sidebarSection(title: "일정", tabs: Self.scheduleTabs)
                .padding(.top, LumenTokens.Space.s4)
            Spacer()
        }
        .frame(width: LumenTokens.Space.size(220))
        .background(P.panelSurface)
    }

    private func sidebarSection(title: String, tabs: [Tab]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            LumenSectionLabel(text: title)
                .padding(.horizontal, LumenTokens.Space.s5)
                .padding(.top, LumenTokens.Space.pad)
                .padding(.bottom, LumenTokens.Space.inline)

            ForEach(tabs, id: \.self) { tab in
                SidebarRow(tab: tab, isSelected: tab == selection) {
                    selection = tab
                }
                .padding(.horizontal, LumenTokens.Space.inline)
            }
        }
    }

    // MARK: - Content area

    private var contentArea: some View {
        VStack(spacing: 0) {
            tabContent
            ActionBar(viewModel: actionVM)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selection {
        case .ui:         UISettingsTab(action: actionVM)
        case .hiddenApps: HiddenAppsSettingsTab(action: actionVM)
        case .power:      PowerSettingsTab(action: actionVM)
        case .dashboard:  DashboardSettingsTab(action: actionVM)
        case .plugin(let id):
            if let plugin = SchedulePlugins.plugin(id) {
                plugin.makeSettingsTab(action: actionVM)
                    .id(id)
            }
        }
    }
}

// MARK: - Action bar VM

@Observable
final class SettingsActionViewModel {
    /// 현재 탭이 ActionBar(저장됨/초기화) 액션을 처리할 수 있도록 위임받는 핸들러.
    var save: () -> Void = {}
    var reset: () -> Void = {}
    var dirty: Bool = false
    var saved: Bool = false
    /// 토글 같이 명시적 저장이 없는 탭은 ActionBar 자체를 숨긴다.
    var hidden: Bool = false
}

// MARK: - Sidebar row

private struct SidebarRow: View {
    let tab: SettingsView.Tab
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: LumenTokens.Space.s3) {
                LumenIcon(tab.icon)
                    .foregroundStyle(isSelected ? P.brand : P.inkMuted)
                Text(tab.label)
                    .lumenText(.body, weight: isSelected ? .semibold : .medium)
                    .foregroundStyle(isSelected ? P.brand : P.ink)
                Spacer()
            }
            .padding(.vertical, LumenTokens.Space.s3)
            .padding(.horizontal, LumenTokens.Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(LumenListRowStyle(isSelected: isSelected))
    }
}

// MARK: - Reusable form primitives

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
            Text(title)
                .lumenText(.title3)
                .foregroundStyle(P.ink)
            content()
        }
    }
}

/// Still TextField 구조: 라벨(위) · 입력 상자 · 도움말(아래), 사이 간격 6.
struct SettingsField<Content: View>: View {
    let label: String
    var hint: String? = nil
    var dirty: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: LumenTokens.Space.inline) {
                Text(label)
                    .lumenText(.label)
                    .foregroundStyle(P.inkMuted)
                if dirty {
                    Text("변경됨")
                        .lumenText(.caption)
                        .foregroundStyle(P.inkFaint)
                }
            }
            content()
            if let hint {
                Text(hint)
                    .lumenText(.caption)
                    .foregroundStyle(P.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct LumenTextField: View {
    @Binding var text: String
    var placeholder: String
    var monospaced: Bool = false
    var secure: Bool = false

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: LumenTokens.Space.inline) {
            if secure {
                LumenIcon("lock")
                    .foregroundStyle(P.inkFaint)
            }
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                        .font(LumenFont.mono(LumenTextStyle.body.size))
                        .textContentType(.password)
                } else {
                    TextField(placeholder, text: $text)
                        .font(monospaced ? LumenFont.mono(LumenTextStyle.body.size) : LumenFont.style(.body))
                }
            }
            .textFieldStyle(.plain)
            .foregroundStyle(P.ink)
            .tint(P.brand)
            .focused($focused)
        }
        .frame(minHeight: LumenTokens.Space.scaled(24))
        .lumenFieldChrome(focused: focused)
    }
}

/// 즉시 적용되는 켜고 끄기 한 줄. 제목과 설명을 카드에 담는다.
struct SwitchRow: View {
    @Binding var on: Bool
    let title: String
    let description: String

    var body: some View {
        Toggle(isOn: $on) {
            VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
                Text(title)
                    .lumenText(.body, weight: .medium)
                    .foregroundStyle(P.ink)
                Text(description)
                    .lumenText(.label, weight: .regular)
                    .foregroundStyle(P.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(LumenSwitchStyle())
        .padding(LumenTokens.Space.pad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenCard()
    }
}

// MARK: - Action bar

private struct ActionBar: View {
    let viewModel: SettingsActionViewModel

    var body: some View {
        if viewModel.hidden {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                LumenHairline()
                HStack(spacing: LumenTokens.Space.inline) {
                    Button(action: viewModel.reset) {
                        Label { Text("초기화") } icon: { LumenIcon("rotate-ccw") }
                    }
                    .buttonStyle(LumenButtonStyle(variant: .secondary))
                    Spacer()
                    if viewModel.saved {
                        HStack(spacing: LumenTokens.Space.s1) {
                            LumenIcon("circle-check", size: .small)
                                .foregroundStyle(P.success)
                            Text("저장했어요")
                                .lumenText(.label, weight: .regular)
                                .foregroundStyle(P.inkMuted)
                        }
                        .transition(.opacity)
                    }
                    Button("저장", action: viewModel.save)
                        .buttonStyle(LumenButtonStyle(variant: .primary))
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, LumenTokens.Space.pad)
                .padding(.vertical, LumenTokens.Space.s4)
            }
            .background(P.panelSurface)
        }
    }
}
