import SwiftUI
import MarkdownUI

struct NoteView: View {
    @State var viewModel = NoteViewModel()

    var body: some View {
        ZStack {
            LumenGlassBackground(radius: LumenTokens.Radius.window)
            VStack(spacing: 0) {
                header
                LumenHairline()
                body_
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: LumenTokens.Radius.window, style: .continuous))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "note.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LumenTokens.Accent.violetSoft)
                Text("메모")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                Text("· 단일 노트")
                    .font(.system(size: 11))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                Rectangle()
                    .fill(LumenTokens.divider)
                    .frame(width: 1, height: 12)
                SaveStatusView(state: viewModel.saveStatus)
            }
            Spacer()
            ModeToggle(isPreview: viewModel.isPreview) {
                viewModel.togglePreview()
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    // MARK: - Body

    private var body_: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.isPreview {
                ScrollView(.vertical) {
                    Markdown(viewModel.text)
                        .markdownTheme(.lumen)
                        .textSelection(.enabled)
                        .environment(\.openURL, OpenURLAction { url in
                            NSWorkspace.shared.open(url)
                            return .handled
                        })
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 20)
                }
                .scrollIndicators(.hidden)
            } else {
                editor
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editor: some View {
        LumenTextArea(
            text: $viewModel.text,
            placeholder: "여기에 메모… 마크다운 지원",
            fontSize: 13,
            monospaced: true
        )
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .onChange(of: viewModel.text) { _, _ in
            viewModel.onTextChanged()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                LinearGradient(
                    colors: [LumenTokens.Accent.violetSoft, LumenTokens.Accent.amber],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Lumen")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
            Spacer()
            HStack(spacing: 14) {
                NoteFooterAction(label: "모드 전환", kbd: "⌘⇧E", primary: true)
                NoteFooterAction(label: "닫기", kbd: "esc")
                NoteFooterAction(label: "패널", kbd: "⌘⇧X")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(LumenTokens.BG.footer)
        .overlay(alignment: .top) {
            Rectangle().fill(LumenTokens.divider).frame(height: 0.5)
        }
    }
}

// MARK: - Save status

private struct SaveStatusView: View {
    let state: NoteViewModel.SaveStatus

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .shadow(color: glow ? dotColor : .clear, radius: 4)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
    }

    private var dotColor: Color {
        switch state {
        case .resting: return Color.white.opacity(0.18)
        case .editing: return LumenTokens.Accent.violetSoft
        case .saved:   return LumenTokens.Accent.violet
        }
    }

    private var glow: Bool {
        if case .saved = state { return true }
        return false
    }

    private var label: String {
        switch state {
        case .resting: return "자동 저장"
        case .editing: return "편집 중…"
        case .saved:   return "저장됨"
        }
    }
}

// MARK: - Mode toggle

private struct ModeToggle: View {
    let isPreview: Bool
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 0) {
                    segment(icon: "pencil", label: "편집", active: !isPreview)
                    segment(icon: "eye", label: "미리보기", active: isPreview)
                }
                .padding(2)
                .background(
                    Capsule().fill(LumenTokens.BG.card)
                )
                .overlay(
                    Capsule().stroke(LumenTokens.strokeStrong, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            Text("⌘⇧E")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
    }

    private func segment(icon: String, label: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? LumenTokens.Accent.violetSoft : LumenTokens.TextColor.muted)
            Text(label)
                .font(.system(size: 11.5, weight: active ? .medium : .regular))
                .foregroundStyle(active ? LumenTokens.TextColor.primary : LumenTokens.TextColor.muted)
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(
            Capsule()
                .fill(active ? LumenTokens.Accent.violet.opacity(0.16) : .clear)
                .overlay(
                    Capsule()
                        .stroke(active ? LumenTokens.Accent.violetSoft.opacity(0.35) : .clear, lineWidth: 0.5)
                )
                .shadow(color: active ? LumenTokens.Accent.violet.opacity(0.18) : .clear, radius: 6)
        )
    }
}

// MARK: - Footer action

private struct NoteFooterAction: View {
    let label: String
    let kbd: String
    var primary: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: primary ? .medium : .regular))
                .foregroundStyle(primary ? LumenTokens.TextColor.primary : LumenTokens.TextColor.muted)
            LumenKbd(label: kbd, primary: primary)
        }
    }
}
