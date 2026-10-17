import SwiftUI

private typealias P = LumenTokens.Palette

struct WindowMagnetView: View {
    @State var viewModel = WindowMagnetViewModel()
    let onSelect: (WindowMagnetManager.Direction, CGFloat) -> Void

    var body: some View {
        ZStack {
            LumenPanelBackground()
            VStack(spacing: 0) {
                HStack(spacing: LumenTokens.Space.inline) {
                    LumenIcon("columns-2")
                        .foregroundStyle(P.inkMuted)
                    Text("창 크기 선택")
                        .lumenText(.body, weight: .semibold)
                        .foregroundStyle(P.ink)
                    Spacer()
                }
                .padding(.horizontal, LumenTokens.Space.pad)
                .frame(height: 56)

                LumenHairline()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.options.enumerated()), id: \.offset) { index, option in
                            let selected = index == viewModel.selectedIndex
                            Text(option.label)
                                .lumenText(.body, weight: selected ? .semibold : .medium)
                                .foregroundStyle(selected ? P.brand : P.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 14)
                                .padding(.horizontal, LumenTokens.Space.s4)
                                .background(selected ? P.brandSoft : .clear, in: LumenShape.rect(LumenTokens.Radius.md))
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    viewModel.selectedIndex = index
                                    onSelect(viewModel.selectedOption.direction, viewModel.selectedOption.ratio)
                                }
                                .onTapGesture {
                                    viewModel.selectedIndex = index
                                }
                        }
                    }
                    .padding(LumenTokens.Space.inline)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(LumenShape.rect(LumenTokens.Radius.xl))
    }
}
