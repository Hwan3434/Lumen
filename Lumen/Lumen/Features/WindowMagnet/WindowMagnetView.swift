import SwiftUI

struct WindowMagnetView: View {
    @State var viewModel = WindowMagnetViewModel()
    let onSelect: (WindowMagnetManager.Direction, CGFloat) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.split.2x1")
                    .foregroundColor(.purple)
                    .font(.system(size: 16))
                Text("윈도우 크기 선택")
                    .foregroundColor(.white)
                    .font(.system(size: 18))
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 42)

            Divider().background(Color.gray.opacity(0.3))

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(viewModel.options.enumerated()), id: \.offset) { index, option in
                        HStack(spacing: 8) {
                            Text(option.label)
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(index == viewModel.selectedIndex ? Color.blue.opacity(0.3) : Color.clear)
                        .cornerRadius(5)
                        .padding(.horizontal, 6)
                        .onTapGesture(count: 2) {
                            viewModel.selectedIndex = index
                            onSelect(viewModel.selectedOption.direction, viewModel.selectedOption.ratio)
                        }
                        .onTapGesture {
                            viewModel.selectedIndex = index
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.15).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
