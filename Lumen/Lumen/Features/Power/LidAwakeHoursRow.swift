import SwiftUI

/// 클램쉘 모드 상세 칸의 "전원을 뽑은 뒤 끄기" 시간 선택. 설정 > 전원 탭과 같은 값을 바꾼다.
struct LidAwakeHoursRow: View {
    @Bindable var lidAwake: LidAwakeFeature

    var body: some View {
        LumenSettingRow(title: "전원을 뽑은 뒤 끄기") {
            LumenSegmentedControl(
                items: LidAwakeFeature.batteryHourOptions.map { .init(value: $0, label: LidAwakeFeature.batteryHourLabel($0)) },
                selection: $lidAwake.batteryHours
            )
        }
        .padding(.vertical, LumenTokens.Space.s3)
        .padding(.horizontal, LumenTokens.Space.s4)
        .lumenCard(radius: LumenTokens.Radius.md)
    }
}
