import SwiftUI

private typealias P = LumenTokens.Palette

// MARK: - Hint

/// 설정 묶음이나 입력 상자 아래의 도움말. `caption` `ink-faint`, 길면 여러 줄로 내려간다.
struct LumenHint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .lumenText(.caption)
            .foregroundStyle(P.inkFaint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Setting row

/// 설정 한 줄: 왼쪽에 제목(+ 설명), 오른쪽에 조작 부품(세그먼트, 스위치, 값 글자).
/// 여백과 카드는 쓰는 쪽이 붙인다 — 한 줄이 카드 하나면 `.padding(Space.pad).lumenCard()`,
/// 한 카드에 여러 줄이면 줄마다 `Space.rowY` 여백에 사이는 `LumenHairline`.
struct LumenSettingRow<Control: View>: View {
    let title: String
    var description: String? = nil
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(spacing: LumenTokens.Space.s4) {
            LumenSettingLabel(title: title, description: description)
            Spacer(minLength: 0)
            control()
        }
    }
}

/// 설정 줄의 제목과 설명. 줄 전체가 스위치인 `SwitchRow`는 이것을 스위치 라벨로 쓴다.
struct LumenSettingLabel: View {
    let title: String
    var description: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
            Text(title)
                .lumenText(.body, weight: .medium)
                .foregroundStyle(P.ink)
            if let description {
                Text(description)
                    .lumenText(.label, weight: .regular)
                    .foregroundStyle(P.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - TextField

/// Still TextField 구조: 라벨(위) · 입력 상자 · 도움말(아래), 사이 간격 6.
struct LumenLabeledField<Content: View>: View {
    let label: String
    var hint: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.scaled(6)) {
            Text(label)
                .lumenText(.label)
                .foregroundStyle(P.inkMuted)
            content()
            if let hint {
                LumenHint(hint)
            }
        }
    }
}

/// 테두리 있는 한 줄 입력 상자(설정, 팝오버 폼). 패널 맨 위의 테두리 없는 검색 입력은 `LumenInputField`다.
struct LumenTextField: View {
    @Binding var text: String
    var placeholder: String = ""
    var monospaced: Bool = false
    var secure: Bool = false
    /// 밖에서 포커스를 옮겨야 할 때(팝오버가 뜨자마자 입력 등) 넘긴다. 없으면 안에서만 추적한다.
    var focus: FocusState<Bool>.Binding? = nil

    @FocusState private var ownFocus: Bool

    var body: some View {
        HStack(spacing: LumenTokens.Space.inline) {
            if secure {
                LumenIcon("lock")
                    .foregroundStyle(P.inkFaint)
            }
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                        .font(LumenFont.mono(LumenTextStyle.body.size))
                        .textContentType(.password)
                } else {
                    TextField(placeholder, text: $text)
                        .font(monospaced ? LumenFont.mono(LumenTextStyle.body.size) : LumenFont.style(.body))
                }
            }
            .textFieldStyle(.plain)
            .foregroundStyle(P.ink)
            .tint(P.brand)
            .focused(focus ?? $ownFocus)
        }
        .frame(minHeight: LumenTokens.Space.scaled(24))
        .lumenFieldChrome(focused: focus?.wrappedValue ?? ownFocus)
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
            .padding(.vertical, LumenTokens.Space.scaled(10))
            .padding(.horizontal, LumenTokens.Space.scaled(12))
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
