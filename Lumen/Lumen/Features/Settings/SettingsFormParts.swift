import SwiftUI

// 설정 탭들이 같이 쓰는 뼈대. 입력 상자·도움말·설정 줄 같은 범용 부품은 DesignSystem/LumenForm.swift에 있다.

/// 설정 탭 한 장의 뼈대: 세로 스크롤 안에 `SettingsSection`들을 넓은 간격으로 쌓는다.
struct SettingsTabContent<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenTokens.Space.s7) {
                content()
            }
            .padding(LumenTokens.Space.s6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
            Text(title)
                .lumenText(.title3)
                .foregroundStyle(LumenTokens.Palette.ink)
            content()
        }
    }
}

/// 즉시 적용되는 켜고 끄기 한 줄. 제목과 설명을 카드에 담고, 줄 어디를 눌러도 바뀐다.
struct SwitchRow: View {
    @Binding var on: Bool
    let title: String
    let description: String

    var body: some View {
        Toggle(isOn: $on) {
            LumenSettingLabel(title: title, description: description)
        }
        .toggleStyle(LumenSwitchStyle())
        .padding(LumenTokens.Space.pad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenCard()
    }
}
