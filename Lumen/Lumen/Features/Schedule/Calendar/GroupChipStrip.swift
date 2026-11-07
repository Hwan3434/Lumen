import SwiftUI

private typealias P = LumenTokens.Palette

/// 캘린더 헤더의 묶음 칩 줄. 켜진 플러그인을 등록 순서대로, 플러그인 아이콘 뒤에 그 묶음들을 깐다.
/// 칩을 누르면 플러그인 설정의 표시 여부가 바뀌고, 설정 탭의 스위치도 같은 값을 본다.
struct GroupChipStrip: View {
    @Environment(ScheduleStore.self) private var store

    var body: some View {
        let colors = store.groupColors
        let plugins = store.enabledPlugins.filter { !$0.groups.isEmpty }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LumenTokens.Space.inline) {
                ForEach(Array(plugins.enumerated()), id: \.element.id.rawValue) { idx, plugin in
                    if idx > 0 {
                        Rectangle()
                            .fill(P.borderSubtle)
                            .frame(width: 1, height: LumenIcon.Size.small.points)
                    }
                    LumenIcon(plugin.iconName, size: .small)
                        .foregroundStyle(P.inkFaint)
                        .help(plugin.displayName)
                    ForEach(plugin.groups) { group in
                        FilterChip(
                            label: group.name,
                            color: colors[ScheduleGroupKey(plugin: plugin.id, group: group.id)] ?? P.chartOther,
                            isOn: Binding(
                                get: { group.isVisible },
                                set: { plugin.setGroupVisible(group.id, $0) }
                            )
                        )
                    }
                }
            }
        }
        .scrollClipDisabled()
    }
}

/// 켜고 끄는 필터. 계열 색은 점에만 쓰고, 꺼지면 점을 비운다(색만으로 상태를 나타내지 않도록 체크 아이콘도 함께).
struct FilterChip: View {
    let label: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: LumenTokens.Space.s1 + 2) {
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .background(Circle().fill(isOn ? color : .clear))
                    .frame(width: LumenTokens.Space.scaled(10), height: LumenTokens.Space.scaled(10))
                Text(label)
                    .lumenText(.label)
                    .foregroundStyle(isOn ? P.ink : P.inkFaint)
                if isOn {
                    LumenIcon("check", size: .small)
                        .foregroundStyle(P.inkMuted)
                }
            }
            .padding(.vertical, LumenTokens.Space.scaled(6))
            .padding(.horizontal, LumenTokens.Space.scaled(12))
            .background(isOn ? P.surface : .clear, in: LumenShape.rect(LumenTokens.Radius.md))
            .overlay(LumenShape.rect(LumenTokens.Radius.md).strokeBorder(P.borderSubtle, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "켜짐" : "꺼짐")
    }
}
