import SwiftUI
import AppKit

// Still 컴포넌트 명세(project/components/*/README.md)를 SwiftUI로 옮긴 공용 부품.

private typealias P = LumenTokens.Palette

// MARK: - Icon

/// Lucide 아이콘. 선 굵기 1.5, 크기는 16(caption·label 옆) / 20(body·버튼·입력창) / 24(title-3 이상).
/// 에셋 이름은 `lucide-<Lucide 원래 이름>` (Assets.xcassets/Icons).
struct LumenIcon: View {
    enum Size: CGFloat { case small = 16, regular = 20, large = 24 }

    let name: String
    var size: Size = .regular

    init(_ name: String, size: Size = .regular) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image("lucide-\(name)")
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .frame(width: size.rawValue, height: size.rawValue)
    }

    /// 메뉴바·메뉴 항목용 템플릿 NSImage.
    static func nsImage(_ name: String, size: Size = .small, accessibility: String? = nil) -> NSImage? {
        guard let src = NSImage(named: "lucide-\(name)"), let img = src.copy() as? NSImage else { return nil }
        img.size = NSSize(width: size.rawValue, height: size.rawValue)
        img.isTemplate = true
        img.accessibilityDescription = accessibility
        return img
    }
}

// MARK: - Button

struct LumenButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, ghost, danger }
    /// `icon`은 안쪽 여백 없이 라벨 크기 그대로 — IconButton 전용.
    enum Size { case small, regular, large, icon }

    var variant: Variant = .secondary
    var size: Size = .regular

    func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, variant: variant, size: size)
    }

    private struct StyledButton: View {
        let configuration: Configuration
        let variant: Variant
        let size: Size
        @State private var hovered = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let pad: (CGFloat, CGFloat) = switch size {
            case .small: (6, 12)
            case .regular: (10, 16)
            case .large: (14, 24)
            case .icon: (0, 0)
            }
            configuration.label
                .lumenText(.label, weight: .semibold)
                .labelStyle(LumenInlineLabelStyle(iconSize: size == .small ? .small : .regular))
                .foregroundStyle(foreground)
                .padding(.vertical, pad.0)
                .padding(.horizontal, pad.1)
                .background(background, in: LumenShape.rect(LumenTokens.Radius.md))
                .overlay {
                    if variant == .secondary {
                        LumenShape.rect(LumenTokens.Radius.md).strokeBorder(P.borderSubtle, lineWidth: 1)
                    }
                }
                .contentShape(LumenShape.rect(LumenTokens.Radius.md))
                .scaleEffect(configuration.isPressed ? LumenTokens.Motion.scalePress : 1)
                .animation(LumenTokens.Motion.easeOut(LumenTokens.Motion.fast), value: configuration.isPressed)
                .opacity(isEnabled ? 1 : LumenTokens.State.disabledOpacity)
                .onHover { hovered = $0 }
        }

        private var foreground: Color {
            switch variant {
            case .primary: P.onBrand
            case .secondary: P.ink
            case .ghost: P.inkMuted
            case .danger: P.onDanger
            }
        }

        private var background: Color {
            switch variant {
            case .primary: P.brand
            case .secondary: hovered ? P.surfaceRaised : P.surface
            case .ghost: hovered ? P.surface : .clear
            case .danger: P.danger
            }
        }
    }
}

/// 아이콘 하나로 된 정사각형 버튼(40 × 40, 아이콘 20). 접근성 이름은 `.help`로 마우스 올림 때도 보인다.
struct LumenIconButton: View {
    let icon: String
    let label: String
    var variant: LumenButtonStyle.Variant = .ghost
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            LumenIcon(icon)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(LumenButtonStyle(variant: variant, size: .icon))
        .accessibilityLabel(label)
        .help(label)
    }
}

/// 버튼 안 아이콘 + 라벨 사이 `space-inline`.
struct LumenInlineLabelStyle: LabelStyle {
    var iconSize: LumenIcon.Size = .regular
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: LumenTokens.Space.inline) {
            configuration.icon.frame(width: iconSize.rawValue, height: iconSize.rawValue)
            configuration.title
        }
    }
}

// MARK: - Status tone (Badge, Banner, Toast)

enum LumenTone {
    case accent, category, success, warning, danger, info

    var color: Color {
        switch self {
        case .accent: P.brand
        case .category: P.inkMuted
        case .success: P.success
        case .warning: P.warning
        case .danger: P.danger
        case .info: P.info
        }
    }

    var soft: Color {
        switch self {
        case .accent: P.brandSoft
        case .category: .clear
        case .success: P.successSoft
        case .warning: P.warningSoft
        case .danger: P.dangerSoft
        case .info: P.infoSoft
        }
    }

    /// 상태는 색만으로 구분하지 않는다: 체크, 경고 삼각형, 원 안의 X, 원 안의 i.
    var icon: String? {
        switch self {
        case .success: "circle-check"
        case .warning: "triangle-alert"
        case .danger: "circle-x"
        case .info: "info"
        case .accent, .category: nil
        }
    }
}

struct LumenBadge: View {
    let text: String
    var tone: LumenTone = .category
    /// 상태 톤의 기본 아이콘 대신 쓸 아이콘.
    var icon: String? = nil

    var body: some View {
        HStack(spacing: LumenTokens.Space.s1) {
            if let name = icon ?? tone.icon {
                LumenIcon(name, size: .small)
            }
            Text(text)
                .lumenText(.caption, weight: .semibold)
                .lineLimit(1)
        }
        .foregroundStyle(tone.color)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(tone.soft, in: LumenShape.rect(LumenTokens.Radius.xs))
        .overlay {
            if tone == .category {
                LumenShape.rect(LumenTokens.Radius.xs).strokeBorder(P.borderSubtle, lineWidth: 1)
            }
        }
    }
}

struct LumenBanner<Action: View>: View {
    let tone: LumenTone
    let title: String
    var message: String? = nil
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(alignment: .top, spacing: LumenTokens.Space.s3) {
            if let icon = tone.icon {
                LumenIcon(icon).foregroundStyle(tone.color)
            }
            VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
                Text(title)
                    .lumenText(.label, weight: .semibold)
                    .foregroundStyle(P.ink)
                if let message {
                    Text(message)
                        .lumenText(.label, weight: .regular)
                        .foregroundStyle(P.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                action()
                    .padding(.top, LumenTokens.Space.s1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(tone.soft, in: LumenShape.rect(LumenTokens.Radius.md))
        .accessibilityElement(children: .combine)
    }
}

extension LumenBanner where Action == EmptyView {
    init(tone: LumenTone, title: String, message: String? = nil) {
        self.init(tone: tone, title: title, message: message, action: { EmptyView() })
    }
}

// MARK: - SegmentedControl

struct LumenSegmentedControl<Value: Hashable>: View {
    struct Item {
        let value: Value
        let label: String
        var icon: String? = nil
    }

    let items: [Item]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.value) { item in
                let selected = item.value == selection
                Button {
                    withAnimation(LumenTokens.Motion.easeOut(LumenTokens.Motion.fast)) { selection = item.value }
                } label: {
                    HStack(spacing: LumenTokens.Space.s1 + 2) {
                        if let icon = item.icon { LumenIcon(icon, size: .small) }
                        Text(item.label).lumenText(.label)
                    }
                    .foregroundStyle(selected ? P.ink : P.inkMuted)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background {
                        if selected {
                            LumenShape.rect(9)
                                .fill(P.surfaceRaised)
                                .overlay(LumenShape.rect(9).strokeBorder(P.borderSubtle, lineWidth: 1))
                                .lumenElevation(1, radius: 9)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(P.surface, in: LumenShape.rect(LumenTokens.Radius.md))
        .overlay(LumenShape.rect(LumenTokens.Radius.md).strokeBorder(P.borderSubtle, lineWidth: 1))
    }
}

// MARK: - ListItem

/// List 안의 한 줄. 마우스 올림 `surface-raised`, 선택 `brand-soft`. 줄 안쪽 14 × 16.
struct LumenListRowStyle: ButtonStyle {
    var isSelected: Bool = false
    var radius: CGFloat = LumenTokens.Radius.md

    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration, isSelected: isSelected, radius: radius)
    }

    private struct Row: View {
        let configuration: Configuration
        let isSelected: Bool
        let radius: CGFloat
        @State private var hovered = false

        var body: some View {
            configuration.label
                .background(fill, in: LumenShape.rect(radius))
                .contentShape(LumenShape.rect(radius))
                .scaleEffect(configuration.isPressed ? LumenTokens.Motion.scalePress : 1)
                .animation(LumenTokens.Motion.easeOut(LumenTokens.Motion.fast), value: configuration.isPressed)
                .onHover { hovered = $0 }
        }

        private var fill: Color {
            if isSelected { return P.brandSoft }
            return hovered ? P.surfaceRaised : .clear
        }
    }
}

// MARK: - Switch

/// 즉시 적용되는 켜고 끄기. 트랙 52 × 32, 손잡이 26.
/// 줄 전체가 버튼이라 라벨을 눌러도 바뀌고, 키보드(스페이스)와 VoiceOver에서는 스위치로 읽힌다.
struct LumenSwitchStyle: ToggleStyle {
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
                        .frame(width: 52, height: 32)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                        .padding(3)
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

// MARK: - TextField chrome

/// 입력 상자: `bg`, 테두리 1px `border-strong`, `radius-md`, 안쪽 10 × 12.
/// 포커스 시 테두리 `brand` + 바깥 3px `brand-soft` 번짐.
struct LumenFieldChrome: ViewModifier {
    var focused: Bool

    func body(content: Content) -> some View {
        let shape = LumenShape.rect(LumenTokens.Radius.md)
        content
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(P.bg, in: shape)
            .overlay(shape.strokeBorder(focused ? P.brand : P.borderStrong, lineWidth: 1))
            .background {
                if focused {
                    LumenShape.rect(LumenTokens.Radius.md + 3)
                        .fill(P.brandSoft)
                        .padding(-3)
                }
            }
            .animation(LumenTokens.Motion.easeOut(LumenTokens.Motion.fast), value: focused)
    }
}

extension View {
    func lumenFieldChrome(focused: Bool) -> some View {
        modifier(LumenFieldChrome(focused: focused))
    }
}

// MARK: - List

/// 같은 종류 항목을 세로로 묶는 그룹. Card와 같은 표면에 항목 사이 1px `border-subtle`.
/// 줄에 마우스 올림 배경이 있으면 `inset`으로 카드 테두리와 띄운다.
struct LumenList<Data: RandomAccessCollection, ID: Hashable, Row: View>: View {
    let data: Data
    let id: KeyPath<Data.Element, ID>
    var inset: CGFloat = 0
    @ViewBuilder let row: (Data.Element) -> Row

    var body: some View {
        let firstID = data.first?[keyPath: id]
        VStack(alignment: .leading, spacing: 0) {
            ForEach(data, id: id) { element in
                if element[keyPath: id] != firstID { LumenHairline() }
                row(element)
            }
        }
        .padding(inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenCard()
    }
}

extension LumenList where Data.Element: Identifiable, ID == Data.Element.ID {
    init(_ data: Data, inset: CGFloat = 0, @ViewBuilder row: @escaping (Data.Element) -> Row) {
        self.init(data: data, id: \.id, inset: inset, row: row)
    }
}

// MARK: - Empty state

/// 화면이나 영역이 비었거나 불러오는 중일 때의 안내. 아이콘 24 + 한 문장, 가운데 정렬.
struct LumenEmptyState: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: LumenTokens.Space.stack) {
            LumenIcon(icon, size: .large)
                .foregroundStyle(P.inkFaint)
            Text(text)
                .lumenText(.label, weight: .regular)
                .foregroundStyle(P.inkMuted)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Dot

/// 계열 색 표식(지름 8). 차트 범례, 프로젝트·캘린더 구분처럼 색으로 계열을 알릴 때만 쓴다.
struct LumenDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}
