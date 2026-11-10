import SwiftUI

// Still 컴포넌트 명세(project/components/*/README.md)를 SwiftUI로 옮긴 공용 부품.

private typealias P = LumenTokens.Palette

// MARK: - Section label

/// 묶음 이름. `label` 굵기 500 `ink-muted`.
struct LumenSectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .lumenText(.label)
            .foregroundStyle(LumenTokens.Palette.inkMuted)
    }
}

// MARK: - ListItem

/// List 안의 한 줄. 마우스 올림 `Palette.hover`, 선택 `brand-soft`. 줄 안쪽 14 × 16.
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
            return hovered ? P.hover : .clear
        }
    }
}

extension View {
    /// 고를 수 있는 줄의 제목 글자. 선택되면 `brand` 굵기 600, 아니면 `ink` 굵기 500.
    func lumenRowTitle(selected: Bool, style: LumenTextStyle = .body) -> some View {
        self
            .lumenText(style, weight: selected ? .semibold : .medium)
            .foregroundStyle(selected ? P.brand : P.ink)
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

/// 목록이 들어갈 자리가 비었을 때, 목록 대신 놓는 한 줄짜리 카드. 아이콘 + 한 문장(+ 보조 설명).
struct LumenEmptyCard: View {
    let icon: String
    let text: String
    var detail: String? = nil
    /// 아이콘 색. 기본은 무채색이고, "이상 없음"처럼 상태를 알릴 때만 톤을 준다.
    var tone: LumenTone = .category

    var body: some View {
        HStack(spacing: LumenTokens.Space.s3) {
            LumenIcon(icon)
                .foregroundStyle(tone.color)
            VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
                Text(text)
                    .lumenText(.body)
                    .foregroundStyle(P.inkMuted)
                if let detail {
                    Text(detail)
                        .lumenText(.caption)
                        .foregroundStyle(P.inkFaint)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, LumenTokens.Space.rowY)
        .padding(.horizontal, LumenTokens.Space.s4)
        .lumenCard()
    }
}
