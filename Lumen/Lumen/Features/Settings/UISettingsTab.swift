import SwiftUI

private typealias P = LumenTokens.Palette

/// Settings → "UI" 탭. 화면 밀도(재시작 후 반영)와 테마(바로 반영)를 고른다.
struct UISettingsTab: View {
    let action: SettingsActionViewModel

    @State private var density = LumenDensity.saved
    @State private var appearance = LumenAppearance.saved

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenTokens.Space.s7) {
                SettingsSection(title: "화면 밀도") {
                    LumenRadioGroup(
                        options: LumenDensity.allCases.map { .init(value: $0, label: $0.label, detail: $0.detail) },
                        selection: $density
                    )
                    if density != LumenDensity.current {
                        LumenBanner(tone: .info, title: "앱을 다시 시작하면 적용돼요",
                                    message: "지금 화면은 '\(LumenDensity.current.label)' 밀도예요.")
                    }
                }

                SettingsSection(title: "테마") {
                    LumenRadioGroup(
                        options: LumenAppearance.allCases.map { .init(value: $0, label: $0.label) },
                        selection: $appearance
                    )
                }
            }
            .padding(LumenTokens.Space.s6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            // 고르는 즉시 저장되므로 저장 버튼 줄은 숨긴다.
            action.hidden = true
            action.dirty = false
            action.saved = false
        }
        .onChange(of: density) { _, newValue in LumenDensity.saved = newValue }
        .onChange(of: appearance) { _, newValue in LumenAppearance.saved = newValue }
    }
}
