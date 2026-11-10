import SwiftUI

private typealias P = LumenTokens.Palette

struct WindowMagnetView: View {
    @State var viewModel = WindowMagnetViewModel()
    let onSelect: (WindowMagnetManager.Direction, CGFloat) -> Void

    var body: some View {
        VStack(spacing: 0) {
            LumenPanelHeader(icon: "columns-2", title: "창 크기 선택")

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.options.enumerated()), id: \.offset) { index, option in
                            let selected = index == viewModel.selectedIndex
                            Text(option.label)
                                .lumenRowTitle(selected: selected)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, LumenTokens.Space.rowY)
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
                                .id(index)
                        }
                    }
                    .padding(LumenTokens.Space.inline)
                }
                .scrollIndicators(.hidden)
                // 화살표로 고른 줄이 보이는 영역 밖으로 나가지 않게 따라간다.
                .onChange(of: viewModel.selectedIndex) { _, newValue in
                    withAnimation(LumenTokens.Motion.easeMove()) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .lumenPanel()
    }
}
