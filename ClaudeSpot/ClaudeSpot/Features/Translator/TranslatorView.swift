import SwiftUI

struct TranslatorView: View {
    @State var viewModel: TranslatorViewModel

    var body: some View {
        GeometryReader { outerGeo in
            VStack(spacing: 0) {
                // 상단 (65%): 입력 | 번역결과+발음
                HStack(spacing: 0) {
                    // 왼쪽: 입력
                    TextEditor(text: $viewModel.inputText)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .frame(width: 320)

                    Divider().background(Color.gray.opacity(0.3))

                    // 오른쪽: 번역 결과 + 발음
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            translationResultView()
                                .frame(height: (viewModel.showPronunciation || viewModel.showNotice)
                                       ? geo.size.height * 0.78
                                       : geo.size.height)

                            if viewModel.showPronunciation {
                                Divider().background(Color.gray.opacity(0.3))

                                pronunciationView()
                                    .frame(maxHeight: .infinity)
                            } else if viewModel.showNotice {
                                Divider().background(Color.gray.opacity(0.3))

                                Text("200자가 넘는 문자는 발음을 제공해주지 않습니다.")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 11))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: outerGeo.size.height * 0.65)

                Divider().background(Color.gray.opacity(0.3))

                // 하단 (35%): 히스토리 (전체 너비)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            if viewModel.history.isEmpty {
                                Text("번역 히스토리가 여기에 표시됩니다")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 13))
                                    .padding(12)
                            } else {
                                ForEach(Array(viewModel.history.enumerated()), id: \.element.id) { index, item in
                                    historyRow(item: item, index: index)
                                        .id(item.id)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: viewModel.selectedHistoryIndex) { _, newValue in
                        withAnimation(.easeOut(duration: 0.4)) {
                            if let item = viewModel.history[safe: newValue] {
                                proxy.scrollTo(item.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.15).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func translationResultView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isLoading {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                Spacer()
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                Spacer()
            } else if !viewModel.translatedText.isEmpty {
                ScrollView {
                    Text(viewModel.translatedText)
                        .foregroundColor(.white)
                        .font(.system(size: 15))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)

                HStack {
                    Spacer()
                    Button("복사") {
                        viewModel.copyToClipboard()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Spacer()
                HStack {
                    Spacer()
                    Text("번역 결과")
                        .foregroundColor(.gray)
                        .font(.system(size: 13))
                    Spacer()
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func pronunciationView() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("발음")
                    .foregroundColor(.gray)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Button {
                    viewModel.copyPronunciation()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                Text(viewModel.pronunciationText ?? "")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func historyRow(item: TranslationHistoryItem, index: Int) -> some View {
        let isSelected = index == viewModel.selectedHistoryIndex

        Button {
            viewModel.selectHistory(at: index)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.original)
                    .foregroundColor(.white)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text(item.translated)
                    .foregroundColor(.gray)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableRowStyle(isSelected: isSelected))
        .padding(.horizontal, 6)
    }
}
