import SwiftUI
import Translation

struct TranslatorView: View {
    @State var viewModel: TranslatorViewModel

    private let historyRailWidth: CGFloat = 240

    var body: some View {
        ZStack {
            LumenGlassBackground(radius: LumenTokens.Radius.window)
            VStack(spacing: 0) {
                titleStrip
                LumenHairline()
                HStack(spacing: 0) {
                    mainColumn
                    Rectangle().fill(LumenTokens.divider).frame(width: 0.5)
                    historyRail
                        .frame(width: historyRailWidth)
                }
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: LumenTokens.Radius.window, style: .continuous))
        .translationTask(viewModel.translationConfig) { session in
            do {
                let text = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                
                let response = try await session.translate(text)
                await MainActor.run {
                    viewModel.handleTranslationResult(response.targetText)
                }
            } catch {
                await MainActor.run {
                    viewModel.handleTranslationError(error)
                }
            }
        }
    }

    // MARK: - Title strip

    private var titleStrip: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "character.bubble")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LumenTokens.Accent.violetSoft)
                Text("번역")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(LumenTokens.Accent.violetSoft)
                    Text("자동 감지")
                        .font(.system(size: 11))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }
                Text(viewModel.providerName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .overlay(Capsule().stroke(LumenTokens.stroke, lineWidth: 0.5))
                    )
            }
            Spacer()
            Text("⌘⇧C")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
        .padding(.horizontal, 16)
        .draggableWindowHeader()
        .frame(height: 40)
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
        VStack(alignment: .leading, spacing: 10) {
            LumenSectionLabel(text: "입력")

            LumenTextArea(
                text: $viewModel.inputText,
                placeholder: "여기에 한국어 또는 영어 문장을 입력하세요…",
                fontSize: 17
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxHeight: .infinity)
    }

    private var outputArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                LumenSectionLabel(text: viewModel.errorMessage != nil ? "오류" : "번역")
                Spacer()
                if shouldShowResultCopy {
                    AmberChip(label: "결과 복사", kbd: "⌘C") {
                        viewModel.copyToClipboard()
                    }
                }
            }

            outputBody
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxHeight: .infinity)
    }

    private var shouldShowResultCopy: Bool {
        !viewModel.translatedText.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil
    }

    @ViewBuilder
    private var outputBody: some View {
        if viewModel.isLoading {
            ShimmerLines()
        } else if let error = viewModel.errorMessage {
            ErrorBox(message: error)
        } else if !viewModel.translatedText.isEmpty {
            ScrollView {
                Text(viewModel.translatedText)
                    .font(.system(size: 17))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        } else {
            Text(viewModel.inputText.isEmpty ? "번역 결과가 여기 표시됩니다" : "⏎를 눌러 번역하세요")
                .font(.system(size: 17))
                .foregroundStyle(LumenTokens.TextColor.placeholder)
        }
    }



    // MARK: - History rail

    private var historyRail: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LumenTokens.Accent.violetSoft)
                    LumenSectionLabel(text: "히스토리")
                }
                Spacer()
                Text("\(viewModel.history.count)/30")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if viewModel.history.isEmpty {
                Spacer(minLength: 0)
                Text("번역 히스토리가\n여기에 표시됩니다")
                    .font(.system(size: 12))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
                Spacer(minLength: 0)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(viewModel.history.enumerated()), id: \.element.id) { index, item in
                                HistoryItemRow(
                                    item: item,
                                    isSelected: index == viewModel.selectedHistoryIndex
                                )
                                .id(item.id)
                                .onTapGesture { viewModel.selectHistory(at: index) }
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 8)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: viewModel.selectedHistoryIndex) { _, newValue in
                        if let item = viewModel.history[safe: newValue] {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(item.id, anchor: .center)
                            }
                        }
                    }
                }
            }

            historyFooter
        }
        .background(LumenTokens.BG.sidePanel)
    }

    private var historyFooter: some View {
        HStack {
            HStack(spacing: 6) {
                LumenKbd(label: "↑")
                LumenKbd(label: "↓")
                Text("탐색")
                    .font(.system(size: 10.5))
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
            Spacer()
            Text("최대 30개")
                .font(.system(size: 10.5))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(LumenTokens.divider).frame(height: 0.5)
        }
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

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: LumenTokens.Radius.row)
                .fill(isSelected ? LumenTokens.BG.rowActive : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: LumenTokens.Radius.row)
                        .stroke(isSelected ? LumenTokens.Accent.amber.opacity(0.18) : .clear, lineWidth: 0.5)
                )

            if isSelected {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(LumenTokens.Accent.amber)
                    .frame(width: 2)
                    .padding(.vertical, 6)
                    .padding(.leading, 4)
                    .shadow(color: LumenTokens.Accent.amberDim, radius: 4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.original)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? LumenTokens.TextColor.primary : LumenTokens.TextColor.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(item.translated)
                    .font(.system(size: 11.5))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(LumenTime.relative(item.date, granularity: .shortNoSuffix))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .padding(.top, 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .contentShape(Rectangle())
    }
}



// MARK: - Shimmer

private struct ShimmerLines: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            shimmerLine(width: 0.94)
            shimmerLine(width: 0.82)
            shimmerLine(width: 0.50)
            Spacer(minLength: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private func shimmerLine(width: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack {
                Capsule().fill(LumenTokens.Accent.violet.opacity(0.06))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                LumenTokens.Accent.violet.opacity(0.06),
                                LumenTokens.Accent.violetSoft.opacity(0.20),
                                LumenTokens.Accent.violet.opacity(0.06),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .offset(x: phase * geo.size.width)
                    .mask(Capsule())
            }
            .frame(width: geo.size.width * width, height: 14)
        }
        .frame(height: 14)
    }
}

// MARK: - Error box

private struct ErrorBox: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LumenTokens.ErrorTone.icon)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("번역에 실패했습니다")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LumenTokens.ErrorTone.title)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(LumenTokens.ErrorTone.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LumenTokens.ErrorTone.border, lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Amber chip

struct AmberChip: View {
    let label: String
    let kbd: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Text(kbd)
                    .font(.system(size: 9.5, design: .monospaced))
                    .padding(.horizontal, 4)
                    .frame(minWidth: 14, minHeight: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(LumenTokens.Accent.amber.opacity(0.35), lineWidth: 0.5)
                    )
            }
            .foregroundStyle(LumenTokens.Accent.amber)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(LumenTokens.BG.rowActive)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LumenTokens.Accent.amber.opacity(0.35), lineWidth: 0.5)
                    )
            )
            .shadow(color: LumenTokens.Accent.amber.opacity(0.15), radius: 6)
        }
        .buttonStyle(.plain)
    }
}

