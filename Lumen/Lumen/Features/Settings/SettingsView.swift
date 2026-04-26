import SwiftUI

/// Cmd+, 로 열리는 macOS 기본 설정창의 루트 뷰.
/// Jira / OpenAI / Claude 자격증명·옵션을 사이드바로 분리해 보여준다.
/// 변경 사항은 앱 재시작 후 반영된다 (Service init 시 값이 캡처되는 구조).
struct SettingsView: View {
    enum Tab: String, Hashable, CaseIterable {
        case jira, openai, claude

        var label: String {
            switch self {
            case .jira:   return "Jira"
            case .openai: return "OpenAI"
            case .claude: return "Claude"
            }
        }

        var asset: String {
            switch self {
            case .jira:   return "JiraLogo"
            case .openai: return "OpenAILogo"
            case .claude: return "ClaudeLogo"
            }
        }
    }

    @State private var selection: Tab = .jira

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(LumenTokens.divider).frame(width: 0.5)
            contentArea
        }
        .frame(width: 600, height: 540)
        .background(LumenTokens.BG.windowSolid)
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 1) {
            LumenSectionLabel(text: "일반")
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ForEach(Tab.allCases, id: \.self) { tab in
                SidebarRow(tab: tab, isSelected: tab == selection) {
                    selection = tab
                }
            }
            Spacer()
        }
        .frame(width: 168)
        .background(Color.white.opacity(0.015))
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
        case .jira:   JiraSettingsTab(action: actionVM)
        case .openai: OpenAISettingsTab(action: actionVM)
        case .claude: ClaudeSettingsTab(action: actionVM)
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
            HStack(spacing: 10) {
                Image(tab.asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(isSelected ? LumenTokens.Accent.violetSoft : LumenTokens.TextColor.secondary)
                Text(tab.label)
                    .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? LumenTokens.TextColor.primary : LumenTokens.TextColor.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? LumenTokens.Accent.violet.opacity(0.14) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? LumenTokens.Accent.violetSoft.opacity(0.25) : .clear, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable form primitives

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LumenSectionLabel(text: title)
            content()
        }
    }
}

struct SettingsField<Content: View>: View {
    let label: String
    var hint: String? = nil
    var dirty: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.secondary)
                if dirty {
                    Circle()
                        .fill(LumenTokens.Accent.violetSoft)
                        .frame(width: 5, height: 5)
                        .shadow(color: LumenTokens.Accent.violetSoft, radius: 3)
                }
            }
            content()
            if let hint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .lineSpacing(2)
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
        HStack(spacing: 8) {
            if secure {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                        .font(.system(size: 12.5, design: .monospaced))
                        .textContentType(.password)
                } else {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 12.5, design: monospaced ? .monospaced : .default))
                }
            }
            .textFieldStyle(.plain)
            .foregroundStyle(LumenTokens.TextColor.primary)
            .tint(LumenTokens.Accent.violetSoft)
            .focused($focused)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(focused ? LumenTokens.Accent.violetSoft : LumenTokens.stroke,
                                lineWidth: 0.5)
                )
                .shadow(color: focused ? LumenTokens.Accent.violet.opacity(0.18) : .clear,
                        radius: focused ? 4 : 0)
        )
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
                Rectangle().fill(LumenTokens.divider).frame(height: 0.5)

                // Restart notice strip
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                    Text("변경 사항은 앱을 재시작해야 반영됩니다.")
                        .font(.system(size: 11))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .frame(height: 26)
                .background(Color.black.opacity(0.10))

                Rectangle().fill(LumenTokens.divider).frame(height: 0.5)

                // Buttons
                HStack {
                    ResetButton(action: viewModel.reset)
                    Spacer()
                    if viewModel.saved {
                        SavedIndicator()
                            .transition(.opacity)
                    }
                    SaveButton(prominent: viewModel.dirty, action: viewModel.save)
                }
                .padding(.horizontal, 18)
                .frame(height: 50)
                .background(Color.black.opacity(0.18))
            }
        }
    }
}

private struct SaveButton: View {
    var prominent: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("저장")
                    .font(.system(size: 12.5, weight: .medium))
                Text("⏎")
                    .font(.system(size: 9.5, design: .monospaced))
                    .padding(.horizontal, 5)
                    .frame(minWidth: 16, minHeight: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(LumenTokens.Accent.amber.opacity(0.35), lineWidth: 0.5)
                    )
            }
            .foregroundStyle(LumenTokens.Accent.amber)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(LumenTokens.BG.rowActive)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LumenTokens.Accent.amber.opacity(prominent ? 0.55 : 0.35),
                                    lineWidth: 0.5)
                    )
                    .shadow(color: LumenTokens.Accent.amber.opacity(prominent ? 0.18 : 0.10),
                            radius: prominent ? 8 : 6)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
    }
}

private struct ResetButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .semibold))
                Text("초기화")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(LumenTokens.ErrorTone.title)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(LumenTokens.ErrorTone.bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LumenTokens.ErrorTone.border, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SavedIndicator: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
            Text("저장됨")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(LumenTokens.Accent.violetSoft)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(
            Capsule()
                .fill(LumenTokens.Accent.violet.opacity(0.10))
                .overlay(
                    Capsule()
                        .stroke(LumenTokens.Accent.violetSoft.opacity(0.25), lineWidth: 0.5)
                )
        )
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
    @State private var cloudId: String = ""
    @State private var workspaceSlug: String = ""
    @State private var email: String = ""
    @State private var token: String = ""
    @State private var projects: [JiraProjectEntry] = []

    @State private var initialSnapshot: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 토글은 스크롤과 무관하게 항상 상단에 고정 — 자격증명/프로젝트 폼이
            // 길어져 ScrollView가 활성화돼도 사용자가 토글 위치를 잃지 않도록.
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(title: "Jira") {
                    SwitchRow(
                        on: $enabled,
                        title: "사용",
                        description: "꺼져 있으면 Jira 대시보드 핫키와 메뉴 항목이 노출되지 않습니다. 자격증명은 꺼도 보존됩니다."
                    ) { newValue in
                        enabled = newValue
                        CredentialsStore.shared.setJiraEnabled(newValue)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, enabled ? 22 : 20)

            if enabled {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        SettingsSection(title: "Jira 자격증명") {
                            SettingsField(label: "Cloud ID",
                                          hint: "Atlassian tenant 식별자 (UUID). https://{워크스페이스}.atlassian.net/_edge/tenant_info 에서 확인.") {
                                LumenTextField(text: $cloudId, placeholder: "00000000-0000-0000-0000-000000000000", monospaced: true)
                            }
                            SettingsField(label: "워크스페이스 URL",
                                          hint: "브라우저 주소의 서브도메인. https://{여기}.atlassian.net") {
                                LumenTextField(text: $workspaceSlug, placeholder: "your-workspace", monospaced: true)
                            }
                            SettingsField(label: "Email") {
                                LumenTextField(text: $email, placeholder: "you@example.com")
                            }
                            SettingsField(label: "API Token",
                                          hint: "Atlassian 계정 → 보안 → API 토큰에서 발급") {
                                LumenTextField(text: $token, placeholder: "ATATT3xFfGF…", secure: true)
                            }
                        }

                        SettingsSection(title: "대시보드 조회 프로젝트") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach($projects) { $entry in
                                    HStack(spacing: 8) {
                                        LumenTextField(text: $entry.key, placeholder: "예: PROJ", monospaced: true)
                                            .frame(width: 130)
                                        LumenTextField(text: $entry.name, placeholder: "별칭 (선택)")
                                        Button {
                                            projects.removeAll { $0.id == entry.id }
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 12))
                                                .foregroundStyle(LumenTokens.TextColor.muted)
                                                .frame(width: 28, height: 28)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                Button {
                                    projects.append(JiraProjectEntry(key: "", name: ""))
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("프로젝트 추가")
                                            .font(.system(size: 12, weight: .medium))
                                        Spacer()
                                    }
                                    .foregroundStyle(LumenTokens.Accent.violetSoft)
                                    .padding(.horizontal, 10)
                                    .frame(height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                                            .foregroundStyle(LumenTokens.stroke)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.015))
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            Text(jiraProjectsHint)
                                .font(.system(size: 11))
                                .foregroundStyle(LumenTokens.TextColor.muted)
                                .lineSpacing(3)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            loadFromStore()
            wireActionVM()
        }
        .onChange(of: cloudId) { _, _ in updateDirty() }
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
        cloudId       = store.jiraCloudId
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
        let base = "Key는 대문자 식별자(예: PROJ) — API 호출용. 별칭은 비워두면 Key가 그대로 표시됩니다."
        let defaults = Constants.defaultJiraProjectKeys
        guard !defaults.isEmpty else { return base }
        return base + " 프로젝트를 모두 비우면 기본값(\(defaults.joined(separator: ", ")))으로 복원됩니다."
    }

    private func snapshot() -> String {
        let p = projects.map { "\($0.key)|\($0.name)" }.joined(separator: ",")
        return "\(cloudId)|\(workspaceSlug)|\(email)|\(token)|\(p)"
    }

    private func updateDirty() {
        action.dirty = snapshot() != initialSnapshot
        if action.dirty { action.saved = false }
    }

    private func wireActionVM() {
        action.hidden = false
        action.save = {
            let store = CredentialsStore.shared
            store.setJira(cloudId: cloudId, workspaceSlug: workspaceSlug, email: email, token: token)
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

// MARK: - OpenAI tab

private struct OpenAISettingsTab: View {
    let action: SettingsActionViewModel

    @State private var enabled: Bool = false
    @State private var apiKey: String = ""
    @State private var initialSnapshot: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 토글은 항상 상단 고정. Jira 탭과 같은 정책.
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(title: "OpenAI") {
                    SwitchRow(
                        on: $enabled,
                        title: "사용",
                        description: "꺼져 있으면 번역 패널 핫키와 메뉴 항목이 노출되지 않습니다. API Key는 꺼도 보존됩니다."
                    ) { newValue in
                        enabled = newValue
                        CredentialsStore.shared.setOpenAIEnabled(newValue)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, enabled ? 22 : 20)

            if enabled {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        SettingsSection(title: "OpenAI 자격증명") {
                            SettingsField(label: "API Key",
                                          hint: "번역 패널에서 사용합니다. platform.openai.com → API keys에서 발급.") {
                                LumenTextField(text: $apiKey, placeholder: "sk-proj-…", secure: true)
                            }
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(LumenTokens.TextColor.muted)
                                .padding(.top, 1)
                            Text("키는 macOS 키체인에 저장됩니다. 이 화면에서는 다시 표시되지 않으며, 새로 입력하면 기존 값을 덮어씁니다.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(LumenTokens.TextColor.muted)
                                .lineSpacing(3)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.02))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                                )
                        )
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            loadFromStore()
            wireActionVM()
        }
        .onChange(of: apiKey) { _, _ in updateDirty() }
    }

    private func loadFromStore() {
        let store = CredentialsStore.shared
        enabled = store.isOpenAIEnabled
        apiKey = store.openAIAPIKey
        initialSnapshot = apiKey
        action.dirty = false
    }

    private func updateDirty() {
        action.dirty = apiKey != initialSnapshot
        if action.dirty { action.saved = false }
    }

    private func wireActionVM() {
        action.hidden = false
        action.save = {
            CredentialsStore.shared.setOpenAI(apiKey: apiKey)
            loadFromStore()
            action.saved = true
        }
        action.reset = {
            CredentialsStore.shared.resetOpenAI()
            loadFromStore()
            action.saved = false
        }
    }
}

// MARK: - Claude tab

private struct ClaudeSettingsTab: View {
    let action: SettingsActionViewModel

    @State private var enabled: Bool = CredentialsStore.shared.isClaudeUsageEnabled
    @State private var showCannotTrackAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(title: "Claude 사용량") {
                    SwitchRow(
                        on: $enabled,
                        title: "사용량 추적",
                        description: "~/.claude/projects 를 읽어 검색창 우측에 사용량 패널을 표시합니다. OFF 시 디렉터리가 존재해도 패널이 노출되지 않습니다. 변경 사항은 앱을 재시작해야 반영됩니다."
                    ) { newValue in
                        if newValue && !ClaudeUsageService.canTrack {
                            showCannotTrackAlert = true
                            enabled = false
                            CredentialsStore.shared.setClaudeUsageEnabled(false)
                            return
                        }
                        enabled = newValue
                        CredentialsStore.shared.setClaudeUsageEnabled(newValue)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            // Claude 탭은 토글이 곧 저장이라 ActionBar(저장/초기화)를 숨긴다.
            action.hidden = true
            action.dirty = false
            action.saved = false
        }
        .alert("추적할 수 없습니다", isPresented: $showCannotTrackAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("~/.claude/projects 디렉터리를 찾을 수 없습니다.\nClaude Code CLI가 설치되어 최소 1회 이상 세션이 기록된 상태여야 합니다.")
        }
    }
}

private struct SwitchRow: View {
    @Binding var on: Bool
    let title: String
    let description: String
    var onChange: (Bool) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .lineSpacing(3)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { on },
                set: { onChange($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(LumenTokens.Accent.violet)
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                )
        )
    }
}
