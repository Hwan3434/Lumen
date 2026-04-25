import SwiftUI

struct SearchView: View {
    @State var viewModel = SearchViewModel()
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            mainPanel
            if ClaudeUsageService.isAvailable {
                Divider().background(Color.gray.opacity(0.2))
                UsagePanelView()
                    .frame(width: Constants.usagePanelWidth)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.15).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var mainPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))

                TextField("검색어 입력...", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)

            Divider().background(Color.gray.opacity(0.3))

            // 내장 기능 카드 (가로)
            if !viewModel.features.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.features, id: \.name) { feature in
                            featureCard(feature: feature)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }

                Divider().background(Color.gray.opacity(0.3))
            }

            // 앱 + 계산 결과 (세로)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                            switch item {
                            case .app, .calculation:
                                resultRow(item: item, index: index)
                            case .feature:
                                EmptyView()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .onChange(of: viewModel.selectedIndex) { _, newValue in
                    withAnimation(.easeOut(duration: 0.4)) {
                        if let item = viewModel.results[safe: newValue] {
                            proxy.scrollTo(item.id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func featureCard(feature: BuiltInFeature) -> some View {
        Button {
            onDismiss()
            feature.activate()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: feature.iconName)
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                Text(feature.name)
                    .foregroundColor(.white)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .frame(width: 72, height: 52)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func resultRow(item: SearchResultItem, index: Int) -> some View {
        let isSelected = index == viewModel.selectedIndex

        Button {
            viewModel.selectedIndex = index
        } label: {
            HStack(spacing: 8) {
                switch item {
                case .app(let appItem):
                    Image(nsImage: appItem.icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text(appItem.name)
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                    Spacer()
//                    Button {
//                        viewModel.hideApp(appItem.id)
//                    } label: {
//                        Image(systemName: "eye.slash")
//                            .foregroundColor(.gray.opacity(0.5))
//                            .font(.system(size: 11))
//                    }
//                    .buttonStyle(.plain)
//                    .help("검색 결과에서 숨기기")
                    Text("앱")
                        .foregroundColor(.gray)
                        .font(.system(size: 11))

                case .calculation(let expr, let result):
                    Image(systemName: "equal.circle.fill")
                        .foregroundColor(.cyan)
                        .frame(width: 24, height: 24)
                        .font(.system(size: 14))
                    Text("\(expr) = \(result)")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text("복사")
                        .foregroundColor(.cyan)
                        .font(.system(size: 11))

                case .feature:
                    EmptyView()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableRowStyle(isSelected: isSelected))
        .padding(.horizontal, 6)
        .id(item.id)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
