import SwiftUI

private typealias P = LumenTokens.Palette

/// Cmd+, 로 열리는 macOS 기본 설정창의 루트 뷰.
/// Jira 자격증명·옵션을 사이드바로 분리해 보여준다.
/// 변경 사항은 앱 재시작 후 반영된다 (Service init 시 값이 캡처되는 구조).
struct SettingsView: View {
    enum Tab: String, Hashable, CaseIterable {
        case jira, hiddenApps

        var label: String {
            switch self {
            case .jira:       return "Jira"
            case .hiddenApps: return "숨긴 앱"
            }
        }

        /// asset 이름이 있으면 그쪽이 우선, 없으면 Lucide 아이콘.
        var asset: String? {
            switch self {
            case .jira:       return "JiraLogo"
            default:          return nil
            }
        }

        var icon: String {
            switch self {
            case .hiddenApps: return "eye-off"
            default:          return "circle-help"
            }
        }
    }

    @State private var selection: Tab = .jira

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(P.borderSubtle).frame(width: 1)
            contentArea
        }
        .frame(width: 760, height: 640)
        .background(P.bg)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            LumenSectionLabel(text: "일반")
                .padding(.horizontal, LumenTokens.Space.s5)
                .padding(.top, LumenTokens.Space.pad)
                .padding(.bottom, LumenTokens.Space.inline)

            ForEach(Tab.allCases, id: \.self) { tab in
                SidebarRow(tab: tab, isSelected: tab == selection) {
                    selection = tab
                }
                .padding(.horizontal, LumenTokens.Space.inline)
            }
            Spacer()
        }
        .frame(width: 220)
        .background(P.surface)
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
        case .jira:       JiraSettingsTab(action: actionVM)
        case .hiddenApps: HiddenAppsSettingsTab(action: actionVM)
        }
    }

    // 각 탭이 ActionBar(저장 / 초기화 / 저장됨)에 자기 액션을 주입한다.
    @State private var actionVM = SettingsActionViewModel()
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
                tabIcon
                    .foregroundStyle(isSelected ? P.brand : P.inkMuted)
                    .frame(width: 20, height: 20)
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

    @ViewBuilder
    private var tabIcon: some View {
        if let asset = tab.asset {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        } else {
            LumenIcon(tab.icon)
        }
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
        .frame(minHeight: 24)
        .lumenFieldChrome(focused: focused)
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
                    LumenIcon("info", size: .small)
                    Text("바꾼 설정은 앱을 다시 시작하면 적용돼요.")
                        .lumenText(.caption)
                    Spacer()
                }
                .foregroundStyle(P.inkMuted)
                .padding(.horizontal, LumenTokens.Space.pad)
                .padding(.top, LumenTokens.Space.s3)

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
            .background(P.surface)
        }
    }
}

// MARK: - Jira tab

private struct JiraProjectEntry: Identifiable {
    let id = UUID()
    var key: String
    var name: String
}

private struct JiraSettingsTab: View {
    let action: SettingsActionViewModel

    @State private var enabled: Bool = false
    @State private var iCalEnabled: Bool = false
    @State private var menuBarAgendaEnabled: Bool = true
    @State private var workspaceSlug: String = ""
    @State private var email: String = ""
    @State private var token: String = ""
    @State private var projects: [JiraProjectEntry] = []

    @State private var initialSnapshot: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenTokens.Space.s7) {
                SettingsSection(title: "Jira") {
                    SwitchRow(
                        on: $enabled,
                        title: "사용",
                        description: "끄면 Jira 대시보드 단축키와 메뉴 항목이 보이지 않아요. 자격증명은 그대로 남아요."
                    ) { newValue in
                        CredentialsStore.shared.setJiraEnabled(newValue)
                    }
                }

                SettingsSection(title: "캘린더 연동") {
                    SwitchRow(
                        on: $iCalEnabled,
                        title: "iCal 연동",
                        description: "macOS 캘린더 앱에 연결된 일정을 Jira 월간·주간 보기에 보여줘요. Google Calendar는 macOS 설정의 [인터넷 계정]에서 연결해 주세요. 보여줄 캘린더는 Jira 패널에서 고를 수 있어요."
                    ) { newValue in
                        CredentialsStore.shared.setICalEnabled(newValue)
                        Task { await EventKitService.shared.requestAccessAndFetch() }
                    }

                    SwitchRow(
                        on: $menuBarAgendaEnabled,
                        title: "메뉴바 캘린더 위젯",
                        description: "메뉴바 오른쪽 위에 오늘의 다음 일정을 보여주고, 누르면 오늘 일정이 열려요. ⌘⇧A로도 열 수 있어요."
                    ) { newValue in
                        CredentialsStore.shared.setMenuBarAgendaEnabled(newValue)
                    }
                }

                if enabled {
                    SettingsSection(title: "Jira 자격증명") {
                        SettingsField(label: "워크스페이스 도메인",
                                      hint: "https://{여기}.atlassian.net 에서 {여기} 부분만 적어 주세요. 예: your-workspace") {
                            LumenTextField(text: $workspaceSlug, placeholder: "your-workspace", monospaced: true)
                        }
                        SettingsField(label: "이메일") {
                            LumenTextField(text: $email, placeholder: "you@example.com")
                        }
                        SettingsField(label: "API 토큰",
                                      hint: "Atlassian 계정의 [보안] > [API 토큰]에서 만들 수 있어요.") {
                            LumenTextField(text: $token, placeholder: "ATATT3xFfGF…", secure: true)
                        }
                    }

                    SettingsSection(title: "대시보드 조회 프로젝트") {
                        VStack(alignment: .leading, spacing: LumenTokens.Space.inline) {
                            ForEach($projects) { $entry in
                                HStack(spacing: LumenTokens.Space.inline) {
                                    LumenTextField(text: $entry.key, placeholder: "예: PROJ", monospaced: true)
                                        .frame(width: 160)
                                    LumenTextField(text: $entry.name, placeholder: "별칭 (선택)")
                                    LumenIconButton(icon: "trash-2", label: "프로젝트 삭제") {
                                        projects.removeAll { $0.id == entry.id }
                                    }
                                }
                            }
                            Button {
                                projects.append(JiraProjectEntry(key: "", name: ""))
                            } label: {
                                Label { Text("프로젝트 추가") } icon: { LumenIcon("plus") }
                            }
                            .buttonStyle(LumenButtonStyle(variant: .secondary))
                        }
                        Text(jiraProjectsHint)
                            .lumenText(.caption)
                            .foregroundStyle(P.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(LumenTokens.Space.s6)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            loadFromStore()
            wireActionVM()
        }
        .onChange(of: workspaceSlug) { _, _ in updateDirty() }
        .onChange(of: email) { _, _ in updateDirty() }
        .onChange(of: token) { _, _ in updateDirty() }
        .onChange(of: projects.map { "\($0.key)|\($0.name)" }.joined(separator: ",")) { _, _ in
            updateDirty()
        }
    }

    private func loadFromStore() {
        let store = CredentialsStore.shared
        enabled       = store.isJiraEnabled
        iCalEnabled   = store.isICalEnabled
        menuBarAgendaEnabled = store.isMenuBarAgendaEnabled
        workspaceSlug = store.jiraWorkspaceSlug
        email         = store.jiraEmail
        token         = store.jiraApiToken
        let nameMap = store.jiraProjectNameByKey
        projects = store.jiraProjectKeys.map { key in
            JiraProjectEntry(key: key, name: nameMap[key] ?? "")
        }
        initialSnapshot = snapshot()
        action.dirty = false
    }

    /// 프로젝트 리스트 하단 도움말 — 기본값 폴백 메시지는 폴백 키가 있을 때만 보여준다.
    private var jiraProjectsHint: String {
        let base = "Key는 API 호출에 쓰는 대문자 식별자예요(예: PROJ). 별칭을 비워 두면 Key가 그대로 보여요."
        let defaults = Constants.defaultJiraProjectKeys
        guard !defaults.isEmpty else { return base }
        return base + " 프로젝트를 모두 지우면 기본값(\(defaults.joined(separator: ", ")))으로 돌아가요."
    }

    private func snapshot() -> String {
        let p = projects.map { "\($0.key)|\($0.name)" }.joined(separator: ",")
        return "\(workspaceSlug)|\(email)|\(token)|\(p)"
    }

    private func updateDirty() {
        action.dirty = snapshot() != initialSnapshot
        if action.dirty { action.saved = false }
    }

    private func wireActionVM() {
        action.hidden = false
        action.save = {
            let store = CredentialsStore.shared
            store.setJira(workspaceSlug: workspaceSlug, email: email, token: token)
            store.setJiraProjectKeys(projects.map(\.key))
            var nameMap: [String: String] = [:]
            for entry in projects { nameMap[entry.key] = entry.name }
            store.setJiraProjectNames(nameMap)
            loadFromStore()
            action.saved = true
        }
        action.reset = {
            CredentialsStore.shared.resetJira()
            loadFromStore()
            action.saved = false
        }
    }
}


private struct SwitchRow: View {
    @Binding var on: Bool
    let title: String
    let description: String
    var onChange: (Bool) -> Void = { _ in }

    var body: some View {
        Toggle(isOn: Binding(
            get: { on },
            set: { newValue in
                on = newValue
                onChange(newValue)
            }
        )) {
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
