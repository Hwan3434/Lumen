import SwiftUI

// Still 컴포넌트 명세(project/components/*/README.md)를 SwiftUI로 옮긴 공용 부품.

private typealias P = LumenTokens.Palette

// MARK: - SegmentedControl

struct LumenSegmentedControl<Value: Hashable>: View {
    struct Item {
        let value: Value
        let label: String
        var icon: String? = nil
    }

    let items: [Item]
    @Binding var selection: Value

    /// 선택 칸 반경 = 바깥 반경 − 안쪽 여백(Still 3).
    private var selectedRadius: CGFloat { LumenTokens.Radius.md - 3 }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.value) { item in
                let selected = item.value == selection
                Button {
                    withAnimation(LumenTokens.Motion.easeOut(LumenTokens.Motion.fast)) { selection = item.value }
                } label: {
                    HStack(spacing: LumenTokens.Space.scaled(6)) {
                        if let icon = item.icon { LumenIcon(icon, size: .small) }
                        Text(item.label).lumenText(.label)
                    }
                    .foregroundStyle(selected ? P.ink : P.inkMuted)
                    .padding(.vertical, LumenTokens.Space.scaled(6))
                    .padding(.horizontal, LumenTokens.Space.scaled(12))
                    .background {
                        if selected {
                            LumenShape.rect(selectedRadius)
                                .fill(P.surfaceRaised)
                                .overlay(LumenShape.rect(selectedRadius).strokeBorder(P.borderSubtle, lineWidth: 1))
                                .lumenElevation(1, radius: selectedRadius)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(LumenTokens.Space.scaled(3))
        .background(P.surface, in: LumenShape.rect(LumenTokens.Radius.md))
        .overlay(LumenShape.rect(LumenTokens.Radius.md).strokeBorder(P.borderSubtle, lineWidth: 1))
    }
}

// MARK: - Switch

/// 즉시 적용되는 켜고 끄기. 트랙 52 × 32, 손잡이 26.
/// 줄 전체가 버튼이라 라벨을 눌러도 바뀌고, 키보드(스페이스)와 VoiceOver에서는 스위치로 읽힌다.
struct LumenSwitchStyle: ToggleStyle {
    private static var trackHeight: CGFloat { LumenDensity.current.pick(compact: 20, cozy: 24, regular: 28, spacious: 32) }
    private static var trackWidth: CGFloat { trackHeight * 52 / 32 }

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: LumenTokens.Space.s3) {
                configuration.label
                    .lumenText(.body)
                    .foregroundStyle(P.ink)
                Spacer(minLength: 0)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? P.brand : P.borderStrong)
                        .frame(width: Self.trackWidth, height: Self.trackHeight)
                    Circle()
                        .fill(Color.white)
                        .frame(width: Self.trackHeight - LumenTokens.Space.scaled(6), height: Self.trackHeight - LumenTokens.Space.scaled(6))
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                        .padding(LumenTokens.Space.scaled(3))
                }
                .animation(LumenTokens.Motion.easeMove(), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

// MARK: - RadioGroup

/// 여럿 중 하나만 고르는 묶음. 원 22(밀도에 맞춰 줄어듦), 선택되면 brand 고리.
struct LumenRadioGroup<Value: Hashable>: View {
    struct Option {
        let value: Value
        let label: String
        var detail: String? = nil
    }

    let options: [Option]
    @Binding var selection: Value

    private static var circle: CGFloat { LumenDensity.current.pick(compact: 16, cozy: 18, regular: 20, spacious: 22) }

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.s3) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    HStack(alignment: .top, spacing: LumenTokens.Space.s3) {
                        Circle()
                            .strokeBorder(selected ? P.brand : P.borderStrong, lineWidth: selected ? Self.circle * 7 / 22 : 1.5)
                            .background(Circle().fill(P.bg))
                            .frame(width: Self.circle, height: Self.circle)
                            .padding(.top, max(0, (LumenTextStyle.body.lineHeight - Self.circle) / 2))
                        VStack(alignment: .leading, spacing: LumenTokens.Space.scaled(2)) {
                            Text(option.label)
                                .lumenText(.body)
                                .foregroundStyle(P.ink)
                            if let detail = option.detail {
                                Text(detail)
                                    .lumenText(.label, weight: .regular)
                                    .foregroundStyle(P.inkMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .animation(LumenTokens.Motion.easeOut(LumenTokens.Motion.fast), value: selected)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }
}
