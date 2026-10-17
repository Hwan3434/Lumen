import SwiftUI

/// Settings → "UI" 탭. 화면 밀도, 글래스 정도, 테마를 고른다. 모두 고르는 즉시 반영된다.
struct UISettingsTab: View {
    let action: SettingsActionViewModel

    @State private var density = LumenDensity.saved
    @State private var glass = LumenGlass.saved
    @State private var appearance = LumenAppearance.saved

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenTokens.Space.s7) {
                SettingsSection(title: "화면 밀도") {
                    LumenRadioGroup(
                        options: LumenDensity.allCases.map { .init(value: $0, label: $0.label, detail: $0.detail) },
                        selection: $density
                    )
                }

                SettingsSection(title: "배경 글래스") {
                    LumenRadioGroup(
                        options: LumenGlass.allCases.map { .init(value: $0, label: $0.label) },
                        selection: $glass
                    )
                    Text("검색, 번역, 메모 같은 떠 있는 창의 배경이 뒤 화면을 얼마나 비칠지 정해요.")
                        .lumenText(.caption)
                        .foregroundStyle(LumenTokens.Palette.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
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
            // 고르는 즉시 저장·반영되므로 저장 버튼 줄은 숨긴다.
            action.hidden = true
            action.dirty = false
            action.saved = false
        }
        .onChange(of: density) { _, newValue in
            LumenDensity.saved = newValue
            PanelWindowController.applyDensityToPanels()
        }
        .onChange(of: glass) { _, newValue in LumenGlass.saved = newValue }
        .onChange(of: appearance) { _, newValue in LumenAppearance.saved = newValue }
    }
}
