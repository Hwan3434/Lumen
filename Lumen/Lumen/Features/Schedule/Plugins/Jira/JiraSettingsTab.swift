import SwiftUI

private typealias P = LumenTokens.Palette

/// 설정 › 일정 › Jira. 사용과 가져올 항목 스위치는 즉시 반영되고,
/// 연결 정보와 프로젝트 목록은 [저장]을 눌러야 적용된다(토큰을 한 글자마다 저장하지 않도록).
struct JiraSettingsTab: View {
    let plugin: JiraPlugin
    let action: SettingsActionViewModel

    @State private var workspaceSlug: String = ""
    @State private var email: String = ""
    @State private var token: String = ""
    @State private var projects: [ProjectEntry] = []
    @State private var initialSnapshot: String = ""

    private enum ConnectionCheck: Equatable {
        case idle, checking, ok(String), failed(String)
    }
    @State private var connectionCheck: ConnectionCheck = .idle

    private struct ProjectEntry: Identifiable {
        let id = UUID()
        var key: String
        var alias: String
    }

    var body: some View {
        SettingsTabContent {
            SettingsSection(title: "Jira") {
                SwitchRow(
                    on: Binding(get: { plugin.settings.enabled }, set: { plugin.setEnabled($0) }),
                    title: "사용",
                    description: "끄면 대시보드와 메뉴바에서 Jira 항목이 사라져요. 연결 정보는 그대로 남아요."
                )
            }

            if plugin.settings.enabled {
                SettingsSection(title: "연결") {
                    LumenLabeledField(label: "워크스페이스 도메인",
                                      hint: "https://{여기}.atlassian.net 에서 {여기} 부분만 적어 주세요. 예: your-workspace") {
                        LumenTextField(text: $workspaceSlug, placeholder: "your-workspace", monospaced: true)
                    }
                    LumenLabeledField(label: "이메일") {
                        LumenTextField(text: $email, placeholder: "you@example.com")
                    }
                    LumenLabeledField(label: "API 토큰",
                                      hint: "Atlassian 계정의 [보안] › [API 토큰]에서 만들 수 있어요. 저장하면 바로 적용돼요.") {
                        LumenTextField(text: $token, placeholder: "ATATT3xFfGF…", secure: true)
                    }
                    connectionRow
                }

                SettingsSection(title: "프로젝트") {
                    VStack(alignment: .leading, spacing: LumenTokens.Space.inline) {
                        ForEach($projects) { $entry in
                            HStack(spacing: LumenTokens.Space.inline) {
                                LumenTextField(text: $entry.key, placeholder: "예: PROJ", monospaced: true)
                                    .frame(width: LumenTokens.Space.size(160))
                                LumenTextField(text: $entry.alias, placeholder: "별칭 (선택)")
                                LumenIconButton(icon: "trash-2", label: "프로젝트 삭제") {
                                    projects.removeAll { $0.id == entry.id }
                                }
                            }
                        }
                        Button {
                            projects.append(ProjectEntry(key: "", alias: ""))
                        } label: {
                            Label { Text("프로젝트 추가") } icon: { LumenIcon("plus") }
                        }
                        .buttonStyle(LumenButtonStyle(variant: .secondary))
                    }
                    LumenHint("키는 API 호출에 쓰는 대문자 식별자예요(예: PROJ). 별칭을 비워 두면 키가 그대로 보여요. 색은 보이는 순서대로 자동으로 정해져요.")
                }

                SettingsSection(title: "가져올 항목") {
                    VStack(alignment: .leading, spacing: 0) {
                        fetchRow(title: "내 담당 이슈",
                                 description: "시작일이나 마감일이 있는 이슈를 오늘 앞뒤 90일 범위로 가져와요.",
                                 trailing: { Text("항상").lumenText(.label).foregroundStyle(P.inkMuted) })
                        LumenHairline()
                        fetchRow(title: "스프린트 기간",
                                 description: "진행 중인 스프린트를 캘린더에 기간 막대로 보여줘요. 목록에는 나오지 않아요.",
                                 trailing: { switchControl(get: { plugin.settings.showSprints }, set: { plugin.setShowSprints($0) }, label: "스프린트 기간") })
                        LumenHairline()
                        fetchRow(title: "에픽 마감",
                                 description: "마감일이 있는 열린 에픽을 마감일에 표시해요.",
                                 trailing: { switchControl(get: { plugin.settings.showEpics }, set: { plugin.setShowEpics($0) }, label: "에픽 마감") })
                        LumenHairline()
                        fetchRow(title: "완료한 이슈도 표시",
                                 description: "끄면 완료한 이슈는 목록과 캘린더에서 숨겨요. 켜면 취소선으로 보여요.",
                                 trailing: { switchControl(get: { plugin.settings.showDone }, set: { plugin.setShowDone($0) }, label: "완료한 이슈도 표시") })
                    }
                    .lumenCard()
                }
            }
        }
        .onAppear {
            loadFromPlugin()
            wireActionVM()
        }
        .onChange(of: workspaceSlug) { _, _ in updateDirty() }
        .onChange(of: email) { _, _ in updateDirty() }
        .onChange(of: token) { _, _ in updateDirty() }
        .onChange(of: projects.map { "\($0.key)|\($0.alias)" }.joined(separator: ",")) { _, _ in
            updateDirty()
        }
    }

    // MARK: - 연결 확인

    private var connectionRow: some View {
        HStack(spacing: LumenTokens.Space.s3) {
            Button {
                Task { await checkConnection() }
            } label: {
                Label { Text("연결 확인") } icon: { LumenIcon("rotate-cw", size: .small) }
            }
            .buttonStyle(LumenButtonStyle(variant: .secondary, size: .small))
            .disabled(connectionCheck == .checking)

            switch connectionCheck {
            case .idle:
                EmptyView()
            case .checking:
                Text("확인하고 있어요")
                    .lumenText(.caption)
                    .foregroundStyle(P.inkFaint)
            case .ok(let name):
                LumenBadge(text: "연결됐어요", tone: .success)
                Text(name)
                    .lumenText(.caption)
                    .foregroundStyle(P.inkFaint)
                    .lineLimit(1)
            case .failed(let message):
                LumenBadge(text: "연결 실패", tone: .danger)
                Text(message)
                    .lumenText(.caption)
                    .foregroundStyle(P.inkFaint)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    /// 입력 중인 값을 먼저 저장한 뒤 확인한다 — 저장 안 한 토큰으로 확인되면 헷갈린다.
    /// 바뀐 게 없으면 저장하지 않는다. 저장은 상세 캐시를 비우고 이슈를 처음부터 다시 받게 한다.
    private func checkConnection() async {
        if action.dirty { save() }
        connectionCheck = .checking
        do {
            let name = try await plugin.verifyConnection()
            connectionCheck = .ok(name)
        } catch {
            connectionCheck = .failed(error.networkErrorMessage)
        }
    }

    // MARK: - 가져올 항목

    private func fetchRow<Trailing: View>(title: String, description: String,
                                          @ViewBuilder trailing: @escaping () -> Trailing) -> some View {
        LumenSettingRow(title: title, description: description, control: trailing)
            .padding(.vertical, LumenTokens.Space.rowY)
            .padding(.horizontal, LumenTokens.Space.pad)
    }

    private func switchControl(get: @escaping () -> Bool, set: @escaping (Bool) -> Void, label: String) -> some View {
        Toggle(isOn: Binding(get: get, set: set)) { EmptyView() }
            .toggleStyle(LumenSwitchStyle())
            .accessibilityLabel(label)
            .fixedSize()
    }

    // MARK: - 저장

    private func loadFromPlugin() {
        workspaceSlug = plugin.workspaceSlug
        email = plugin.email
        token = plugin.apiToken
        projects = plugin.settings.projects.map {
            ProjectEntry(key: $0.key, alias: $0.alias)
        }
        initialSnapshot = snapshot()
        action.dirty = false
    }

    private func snapshot() -> String {
        let p = projects.map { "\($0.key)|\($0.alias)" }.joined(separator: ",")
        return "\(workspaceSlug)|\(email)|\(token)|\(p)"
    }

    private func updateDirty() {
        action.dirty = snapshot() != initialSnapshot
        if action.dirty { action.saved = false }
    }

    private func save() {
        plugin.saveCredentials(workspaceSlug: workspaceSlug, email: email, apiToken: token)
        plugin.setProjects(projects.map { JiraProjectSetting(key: $0.key, alias: $0.alias) })
        loadFromPlugin()
        action.saved = true
    }

    private func wireActionVM() {
        action.hidden = false
        action.save = { save() }
        action.reset = {
            plugin.resetCredentials()
            plugin.setProjects([])
            connectionCheck = .idle
            loadFromPlugin()
            action.saved = false
        }
    }
}
