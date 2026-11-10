import SwiftUI

private typealias P = LumenTokens.Palette

/// Settings → "전원" 탭. 덮개 모드(`LidAwakeFeature`)가 설치한 sudoers 권한과
/// 현재 시스템 잠자기 상태를 보여주고, 권한을 지울 수 있게 한다.
struct PowerSettingsTab: View {
    let action: SettingsActionViewModel

    @State private var lidAwake = LidAwakeFeature.shared

    var body: some View {
        SettingsTabContent {
            SettingsSection(title: "클램쉘 모드") {
                VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
                    StatusRow(
                        title: "모드",
                        value: modeText,
                        isWarning: lidAwake.isActive
                    )
                    StatusRow(
                        title: "시스템 잠자기",
                        value: systemSleepText,
                        isWarning: lidAwake.isSystemSleepDisabled == true
                    )
                    StatusRow(
                        title: "관리자 권한 규칙",
                        value: lidAwake.isRuleInstalled ? "설치됨 (\(SleepPolicyService.sudoersPath))" : "없음"
                    )
                }
                .padding(LumenTokens.Space.pad)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lumenCard()

                LumenSettingRow(title: "전원을 뽑은 뒤 끄기") {
                    LumenSegmentedControl(
                        items: LidAwakeFeature.batteryHourOptions.map { .init(value: $0, label: "\($0)시간") },
                        selection: $lidAwake.batteryHours
                    )
                }
                .padding(LumenTokens.Space.pad)
                .lumenCard()

                if lidAwake.isRuleInstalled {
                    Button {
                        lidAwake.removeRule()
                    } label: {
                        Label { Text("권한 지우기") } icon: { LumenIcon("trash-2") }
                    }
                    .buttonStyle(LumenButtonStyle(variant: .danger))
                    .disabled(lidAwake.isBusy)
                }

                LumenHint("""
                검색창에서 '덮개'를 입력해 켜고 끌 수 있어요. 전원이 연결된 동안은 계속 켜져 있어요. \
                전원을 뽑으면 위에서 고른 시간이 지나거나 배터리가 \(LidAwakeFeature.minimumBatteryPercent)% 이하가 될 때 자동으로 꺼져요. \
                권한을 지우면 잠자기 설정도 원래대로 돌아가요. 관리자 비밀번호를 한 번 물어요.
                """)
            }
        }
        .onAppear {
            // 버튼이 곧 실행이라 저장 버튼 줄은 숨긴다.
            action.hideActionBar()
            lidAwake.refreshStatus()
        }
    }

    private var modeText: String {
        guard lidAwake.isActive else { return "꺼짐" }
        guard let expiresAt = lidAwake.expiresAt else { return "켜짐 · 전원 연결 중" }
        return "켜짐 · \(LumenDateFormat.time.string(from: expiresAt))에 꺼져요"
    }

    private var systemSleepText: String {
        switch lidAwake.isSystemSleepDisabled {
        case .some(true):  return lidAwake.isActive ? "막힘" : "막힘 (Lumen 밖에서 설정됨)"
        case .some(false): return "정상"
        case .none:        return "확인하지 못했어요"
        }
    }
}

private struct StatusRow: View {
    let title: String
    let value: String
    var isWarning = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: LumenTokens.Space.s4) {
            Text(title)
                .lumenText(.label)
                .foregroundStyle(P.inkMuted)
                .frame(width: LumenTokens.Space.size(120), alignment: .leading)
            // 평소와 다른 상태는 색만 바꾸지 않고 경고 아이콘을 함께 붙인다.
            if isWarning {
                LumenIcon("triangle-alert", size: .small)
                    .foregroundStyle(P.warning)
            }
            Text(value)
                .lumenText(.body)
                .foregroundStyle(isWarning ? P.warning : P.ink)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}
