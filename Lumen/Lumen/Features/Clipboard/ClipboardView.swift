import SwiftUI

struct ClipboardView: View {
    @State var viewModel = ClipboardViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // 왼쪽: 목록
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))

                    TextField("클립보드 검색...", text: $viewModel.query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .frame(height: 42)

                Divider().background(Color.gray.opacity(0.3))

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            if viewModel.filteredItems.isEmpty {
                                Text("클립보드 히스토리가 비어있습니다")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 13))
                                    .padding(12)
                            } else {
                                ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.id) { index, item in
                                    clipboardRow(item: item, index: index)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: viewModel.selectedIndex) { _, newValue in
                        withAnimation(.easeOut(duration: 0.4)) {
                            if let item = viewModel.filteredItems[safe: newValue] {
                                proxy.scrollTo(item.id, anchor: .center)
                            }
                        }
                    }
                }
            }
            .frame(width: 320)

            Divider().background(Color.gray.opacity(0.3))

            // 오른쪽: 미리보기 (항상 표시)
            VStack(spacing: 0) {
                if viewModel.isLoadingPreview {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.hasPreviewContent {
                    // 본문 (남는 영역 전부 사용)
                    // 본문
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if let image = viewModel.previewImage {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }

                            if let text = viewModel.previewText {
                                Text(text)
                                    .foregroundColor(.white)
                                    .font(.system(size: 13))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(12)
                    }
                    .scrollIndicators(.hidden)

                    // 메타 + 파일 정보 (하단 고정)
                    if let meta = viewModel.previewMeta {
                        Divider().background(Color.gray.opacity(0.3))
                        HStack(alignment: .center, spacing: 8) {
                            if let icon = viewModel.previewAppIcon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                            }
                            Text(meta)
                                .foregroundColor(.gray)
                                .font(.system(size: 11))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                } else {
                    Spacer()
                    Text("미리보기")
                        .foregroundColor(.gray)
                        .font(.system(size: 13))
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.15).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func clipboardRow(item: ClipboardItem, index: Int) -> some View {
        let isSelected = index == viewModel.selectedIndex

        Button {
            viewModel.selectedIndex = index
        } label: {
            HStack(spacing: 8) {
                Group {
                    switch item.typeLabel {
                    case "파일":
                        Image(systemName: "doc")
                            .foregroundColor(.blue)
                    case "이미지":
                        Image(systemName: "photo")
                            .foregroundColor(.green)
                    default:
                        Image(systemName: "text.alignleft")
                            .foregroundColor(.gray)
                    }
                }
                .font(.system(size: 12))
                .frame(width: 20)

                Text(item.displayText)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Text(item.typeLabel)
                    .foregroundColor(.gray)
                    .font(.system(size: 11))
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
