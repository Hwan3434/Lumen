import SwiftUI

/// Cmd+, 로 열리는 macOS 기본 설정창의 루트 뷰.
/// Jira / OpenAI 자격증명을 입력받아 CredentialsStore(UserDefaults 래퍼)에 저장한다.
/// 변경 사항은 앱 재시작 후 반영된다 (Service init 시 값이 캡처되는 구조).
struct SettingsView: View {
    var body: some View {
        TabView {
            JiraSettingsTab()
                .tabItem { tabLabel("Jira", asset: "JiraLogo") }

            OpenAISettingsTab()
                .tabItem { tabLabel("OpenAI", asset: "OpenAILogo") }

            ClaudeSettingsTab()
                .tabItem { tabLabel("Claude", asset: "ClaudeLogo") }
        }
        .frame(width: 500, height: 340)
    }

    // 이미지 자체가 상단 40px 투명 패딩을 포함한 100x140 포맷.
    // scaledToFit로 축소되면 패딩도 비율에 맞게 같이 축소되어 자연스러운 상단 여백이 된다.
    private func tabLabel(_ title: String, asset: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        }
    }
}

// MARK: - Jira

private struct JiraSettingsTab: View {
    @State private var cloudId: String = ""
    @State private var email: String = ""
    @State private var token: String = ""
    @State private var justSaved = false

    var body: some View {
        Form {
            Section {
                TextField("Cloud ID", text: $cloudId)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: cloudId) { _, _ in justSaved = false }
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: email) { _, _ in justSaved = false }
                SecureField("API Token", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: token) { _, _ in justSaved = false }
            } header: {
                Text("Jira 자격증명").font(.headline)
            }

            Text("변경 사항은 앱을 재시작해야 반영됩니다.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("초기화", role: .destructive) {
                    CredentialsStore.shared.resetJira()
                    let store = CredentialsStore.shared
                    cloudId = store.jiraCloudId
                    email   = store.jiraEmail
                    token   = store.jiraApiToken
                    justSaved = false
                }
                Spacer()
                if justSaved {
                    Text("저장됨").foregroundColor(.green).font(.caption)
                }
                Button("저장") {
                    CredentialsStore.shared.setJira(cloudId: cloudId, email: email, token: token)
                    justSaved = true
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onAppear {
            let store = CredentialsStore.shared
            cloudId = store.jiraCloudId
            email   = store.jiraEmail
            token   = store.jiraApiToken
        }
    }
}

// MARK: - Claude

private struct ClaudeSettingsTab: View {
    @State private var enabled: Bool = CredentialsStore.shared.isClaudeUsageEnabled
    @State private var showCannotTrackAlert = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { enabled },
                    set: { newValue in
                        // ON 전환 시 환경 체크 — 디렉터리가 없으면 alert 띄우고 toggle 복귀.
                        if newValue && !ClaudeUsageService.canTrack {
                            showCannotTrackAlert = true
                            enabled = false
                            CredentialsStore.shared.setClaudeUsageEnabled(false)
                            return
                        }
                        enabled = newValue
                        CredentialsStore.shared.setClaudeUsageEnabled(newValue)
                    }
                )) {
                    Text("사용량 추적")
                }
                .toggleStyle(.switch)
            } header: {
                Text("Claude").font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("~/.claude/projects 를 읽어 검색창 우측에 사용량 패널을 표시합니다.")
                Text("OFF 시 디렉터리가 존재해도 패널이 노출되지 않습니다.")
                Text("변경 사항은 앱을 재시작해야 반영됩니다.")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(20)
        .alert("추적할 수 없습니다", isPresented: $showCannotTrackAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("~/.claude/projects 디렉터리를 찾을 수 없습니다.\nClaude Code CLI가 설치되어 최소 1회 이상 세션이 기록된 상태여야 합니다.")
        }
    }
}

// MARK: - OpenAI

private struct OpenAISettingsTab: View {
    @State private var apiKey: String = ""
    @State private var justSaved = false

    var body: some View {
        Form {
            Section {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, _ in justSaved = false }
            } header: {
                Text("OpenAI 자격증명").font(.headline)
            }

            Text("변경 사항은 앱을 재시작해야 반영됩니다.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("초기화", role: .destructive) {
                    CredentialsStore.shared.resetOpenAI()
                    apiKey = CredentialsStore.shared.openAIAPIKey
                    justSaved = false
                }
                Spacer()
                if justSaved {
                    Text("저장됨").foregroundColor(.green).font(.caption)
                }
                Button("저장") {
                    CredentialsStore.shared.setOpenAI(apiKey: apiKey)
                    justSaved = true
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onAppear {
            apiKey = CredentialsStore.shared.openAIAPIKey
        }
    }
}
