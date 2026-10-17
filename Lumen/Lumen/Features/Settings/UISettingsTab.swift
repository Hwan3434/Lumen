import SwiftUI

/// Settings → "UI" 탭. 화면 밀도, 배경 글래스 투명도, 테마를 고른다. 모두 고르는 즉시 반영된다.
struct UISettingsTab: View {
    let action: SettingsActionViewModel

    @State private var density = LumenDensity.saved
    @State private var glassTransparency = LumenGlass.saved
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
                    HStack(spacing: LumenTokens.Space.s4) {
                        Slider(value: $glassTransparency, in: 0...LumenGlass.maxTransparency) {
                            Text("투명도")
                        } minimumValueLabel: {
                            Text("불투명").lumenText(.caption).foregroundStyle(LumenTokens.Palette.inkFaint)
                        } maximumValueLabel: {
                            Text("\(Int(LumenGlass.maxTransparency * 100))%").lumenText(.caption).foregroundStyle(LumenTokens.Palette.inkFaint)
                        }
                        .labelsHidden()
                        .tint(LumenTokens.Palette.brand)
                        Text(glassTransparency == 0 ? "끔" : "\(Int((glassTransparency * 100).rounded()))%")
                            .lumenText(.label)
                            .monospacedDigit()
                            .foregroundStyle(LumenTokens.Palette.ink)
                            .frame(minWidth: LumenTokens.Space.size(48), alignment: .trailing)
                    }
                    Text("검색, 번역, 메모 같은 떠 있는 창의 배경이 뒤 화면을 얼마나 비칠지 정해요. 0%면 글래스를 꺼요.")
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
        .onChange(of: glassTransparency) { _, newValue in LumenGlass.saved = newValue }
        .onChange(of: appearance) { _, newValue in LumenAppearance.saved = newValue }
    }
}
