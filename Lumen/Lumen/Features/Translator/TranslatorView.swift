import SwiftUI
import Translation

private typealias P = LumenTokens.Palette

struct TranslatorView: View {
    @State var viewModel: TranslatorViewModel

    private var historyRailWidth: CGFloat { LumenTokens.Space.size(280) }

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                mainColumn
                LumenHairline(.vertical)
                historyRail
                    .frame(width: historyRailWidth)
            }
            footer
        }
        .lumenPanel()
        .translationTask(viewModel.translationConfig) { session in
            await viewModel.runTranslation(using: session)
        }
    }

    // MARK: - Header

    private var header: some View {
        LumenPanelHeader(icon: "languages", title: "번역") {
            Text("자동 감지")
                .lumenText(.caption)
                .foregroundStyle(P.inkFaint)
            LumenBadge(text: viewModel.providerName)
        } trailing: {
            LumenKbd(label: "⌘⇧C")
        }
    }

    // MARK: - Main column

    private var mainColumn: some View {
        VStack(spacing: 0) {
            inputArea
            LumenHairline()
            outputArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
            LumenSectionLabel(text: "입력")

            LumenTextArea(
                text: $viewModel.inputText,
                placeholder: "한국어나 영어 문장을 입력해 주세요",
                fontSize: LumenTextStyle.bodyLarge.size
            )
        }
        .padding(LumenTokens.Space.pad)
        .frame(maxHeight: .infinity)
    }

    private var outputArea: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
            HStack {
                LumenSectionLabel(text: viewModel.errorMessage != nil ? "오류" : "번역")
                Spacer()
                if shouldShowResultCopy {
                    Button {
                        viewModel.copyToClipboard()
                    } label: {
                        Label { Text("결과 복사") } icon: { LumenIcon("copy", size: .small) }
                    }
                    .buttonStyle(LumenButtonStyle(variant: .secondary, size: .small))
                }
            }
            .frame(minHeight: LumenTokens.Space.scaled(32))

            outputBody
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(LumenTokens.Space.pad)
        .frame(maxHeight: .infinity)
    }

    private var shouldShowResultCopy: Bool {
        !viewModel.translatedText.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil
    }

    @ViewBuilder
    private var outputBody: some View {
        if viewModel.isLoading {
            LoadingLines()
        } else if let error = viewModel.errorMessage {
            LumenBanner(tone: .danger, title: "번역하지 못했어요", message: error)
        } else if !viewModel.translatedText.isEmpty {
            ScrollView {
                Text(viewModel.translatedText)
                    .lumenText(.bodyLarge)
                    .foregroundStyle(P.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        } else {
            Text(viewModel.inputText.isEmpty ? "번역 결과가 여기에 보여요" : "⏎를 누르면 번역해요")
                .lumenText(.bodyLarge)
                .foregroundStyle(P.inkFaint)
        }
    }

    // MARK: - History rail

    private var historyRail: some View {
        VStack(spacing: 0) {
            HStack(spacing: LumenTokens.Space.inline) {
                LumenIcon("history", size: .small)
                    .foregroundStyle(P.inkMuted)
                LumenSectionLabel(text: "기록")
                Spacer()
                Text("\(viewModel.history.count) / \(viewModel.maxHistory)")
                    .lumenText(.caption)
                    .monospacedDigit()
                    .foregroundStyle(P.inkFaint)
            }
            .padding(.horizontal, LumenTokens.Space.s4)
            .padding(.top, LumenTokens.Space.s4)
            .padding(.bottom, LumenTokens.Space.inline)

            if viewModel.history.isEmpty {
                Spacer(minLength: 0)
                Text("번역한 문장이 여기에 쌓여요")
                    .lumenText(.label, weight: .regular)
                    .foregroundStyle(P.inkFaint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, LumenTokens.Space.s4)
                Spacer(minLength: 0)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.history.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    viewModel.selectHistory(at: index)
                                } label: {
                                    HistoryItemRow(
                                        item: item,
                                        isSelected: index == viewModel.selectedHistoryIndex,
                                        now: viewModel.shownAt
                                    )
                                }
                                .buttonStyle(LumenListRowStyle(isSelected: index == viewModel.selectedHistoryIndex))
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, LumenTokens.Space.inline)
                        .padding(.bottom, LumenTokens.Space.inline)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: viewModel.selectedHistoryIndex) { _, newValue in
                        if let item = viewModel.history[safe: newValue] {
                            withAnimation(LumenTokens.Motion.easeMove()) {
                                proxy.scrollTo(item.id, anchor: .center)
                            }
                        }
                    }
                }
            }

            historyFooter
        }
        .background(P.panelSurface)
    }

    private var historyFooter: some View {
        HStack(spacing: LumenTokens.Space.inline) {
            LumenKbd(label: "↑")
            LumenKbd(label: "↓")
            Text("이동")
                .lumenText(.caption)
                .foregroundStyle(P.inkFaint)
            Spacer()
        }
        .padding(.horizontal, LumenTokens.Space.s4)
        .padding(.vertical, LumenTokens.Space.s3)
        .overlay(alignment: .top) { LumenHairline() }
    }

    // MARK: - Footer

    private var footer: some View {
        LumenFooterBar(actions: [
            .init(label: "번역", kbd: "⏎", primary: true),
            .init(label: "결과 복사", kbd: "⌘C"),
            .init(label: "닫기", kbd: "esc"),
        ])
    }
}

// MARK: - History item

private struct HistoryItemRow: View {
    let item: TranslationHistoryItem
    let isSelected: Bool
    /// 상대 시간의 기준. 패널을 열 때마다 바뀌어 "방금"이 몇 시간씩 남지 않는다.
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
            Text(item.original)
                .lumenRowTitle(selected: isSelected, style: .label)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(item.translated)
                .lumenText(.label, weight: .regular)
                .foregroundStyle(P.inkMuted)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(LumenTime.relative(item.date, granularity: .shortNoSuffix, now: now))
                .lumenText(.caption)
                .foregroundStyle(P.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, LumenTokens.Space.s3)
        .padding(.horizontal, LumenTokens.Space.s4)
        .contentShape(Rectangle())
    }
}

// MARK: - Loading

/// 번역 중 자리 표시. 반복 애니메이션 없이 정적인 줄과 안내 문구만 둔다.
private struct LoadingLines: View {
    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
            Text("번역하고 있어요")
                .lumenText(.label, weight: .regular)
                .foregroundStyle(P.inkFaint)
            GeometryReader { geo in
                VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
                    ForEach([0.94, 0.82, 0.5], id: \.self) { ratio in
                        Capsule()
                            .fill(P.surface)
                            .frame(width: geo.size.width * ratio, height: LumenTokens.Space.scaled(16))
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}
