import SwiftUI

/// 설정 › 일정 › 대시보드. 플러그인에 속하지 않는 공통 설정. 모두 고르는 즉시 반영된다.
struct DashboardSettingsTab: View {
    let action: SettingsActionViewModel

    @State private var store = DashboardSettingsStore.shared

    var body: some View {
        SettingsTabContent {
            SettingsSection(title: "메뉴바") {
                SwitchRow(
                    on: Binding(get: { store.settings.menuBarLabel }, set: { store.settings.menuBarLabel = $0 }),
                    title: "다음 일정 라벨",
                    description: "메뉴바 오른쪽 위에 오늘의 다음 일정을 보여주고, 누르면 오늘 일정이 열려요. ⌘⇧A로도 열 수 있어요. 어느 플러그인을 올릴지는 플러그인 탭에서 정해요."
                )
            }

            SettingsSection(title: "기본 보기") {
                LumenRadioGroup(
                    options: CalendarMode.allCases.map { .init(value: $0, label: $0.label) },
                    selection: Binding(get: { store.settings.defaultView }, set: { store.settings.defaultView = $0 })
                )
                LumenHint("일정 창을 열었을 때 먼저 보이는 보기예요. ⌘1 월간, ⌘2 주간으로 바꿀 수 있어요.")
            }

            SettingsSection(title: "주 시작 요일") {
                LumenRadioGroup(
                    options: DashboardSettings.Weekday.allCases.map { .init(value: $0, label: $0.label) },
                    selection: Binding(get: { store.settings.weekStartsOn }, set: { store.settings.weekStartsOn = $0 })
                )
                LumenHint("월간·주간 그리드가 이 요일부터 시작해요.")
            }
        }
        .onAppear {
            // 고르는 즉시 저장·반영되므로 저장 버튼 줄은 숨긴다.
            action.hideActionBar()
        }
    }
}
