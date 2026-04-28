import SwiftUI
import MarkdownUI

struct NoteView: View {
    @State var viewModel = NotesViewModel()

    var body: some View {
        ZStack {
            LumenGlassBackground(radius: LumenTokens.Radius.window)
            HStack(spacing: 0) {
                NotesSidebar(viewModel: viewModel)
                    .frame(width: 200)
                Rectangle().fill(LumenTokens.divider).frame(width: 0.5)
                mainPane
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: LumenTokens.Radius.window, style: .continuous))
    }

    // MARK: - Main pane

    private var mainPane: some View {
        VStack(spacing: 0) {
            header
            LumenHairline()
            bodyContent
            footer
        }
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "note.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LumenTokens.Accent.violetSoft)
                Text(activeTitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                    .lineLimit(1)
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

    private var activeTitle: String {
        guard let idx = viewModel.selectedIndex else { return "메모" }
        return viewModel.notes[idx].displayTitle
    }

    private var bodyContent: some View {
        // editor를 미리보기에서도 mount된 채로 둬서 토글 후에도 NSTextView의 selection/스크롤
        // 위치가 살아있게 한다. 미리보기일 때는 위에 마크다운 ScrollView를 덮고 hit test만 끈다.
        ZStack(alignment: .topLeading) {
            editor
                .opacity(viewModel.isPreview ? 0 : 1)
                .allowsHitTesting(!viewModel.isPreview)
            if viewModel.isPreview {
                ScrollView(.vertical) {
                    Markdown(viewModel.activeText)
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editor: some View {
        // 활성 노트가 바뀌어도 LumenTextArea가 새 인스턴스로 리셋되도록 .id() 부여.
        // 같은 NSTextView를 재사용하면 캐럿/스크롤 위치가 이전 노트 기준으로 남는다.
        LumenTextArea(
            text: Binding(
                get: { viewModel.activeText },
                set: { viewModel.draftDidChange($0) }
            ),
            placeholder: "여기에 메모… 마크다운 지원",
            fontSize: 13,
            monospaced: true,
            focusToken: viewModel.isPreview ? 0 : viewModel.editFocusToken
        )
        .id(viewModel.selectedID ?? "")
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private var footer: some View {
        LumenFooterBar(actions: [
            .init(label: "새 노트", kbd: "⌘N", primary: true),
            .init(label: "모드 전환", kbd: "⌘⇧E"),
            .init(label: "닫기", kbd: "⌘W"),
        ])
    }
}

// MARK: - Sidebar

private struct NotesSidebar: View {
    @Bindable var viewModel: NotesViewModel

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            LumenHairline()
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(Array(viewModel.notes.enumerated()), id: \.element.id) { index, note in
                        SidebarRow(
                            note: note,
                            index: index,
                            isSelected: viewModel.selectedID == note.id,
                            onSelect: { viewModel.selectNote(id: note.id) }
                        )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxHeight: .infinity)
        .background(LumenTokens.BG.sidePanel)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 8) {
            Text("노트")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(LumenTokens.TextColor.muted)
            Spacer()
            Button {
                viewModel.createNewNote(activate: true)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LumenTokens.Accent.violetSoft)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(LumenTokens.stroke, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help("새 노트 (⌘N)")
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
    }
}

private struct SidebarRow: View {
    let note: NoteItem
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(note.displayTitle)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? LumenTokens.TextColor.primary : LumenTokens.TextColor.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if index < 9 {
                        Text("⌘\(index + 1)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(LumenTokens.TextColor.muted)
                            .padding(.horizontal, 3)
                            .frame(minWidth: 18, minHeight: 13)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(LumenTokens.stroke, lineWidth: 0.5)
                            )
                    }
                }
                if !note.preview.isEmpty {
                    Text(note.preview)
                        .font(.system(size: 10.5))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? LumenTokens.BG.rowActive : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isSelected ? LumenTokens.Accent.amber.opacity(0.18) : .clear, lineWidth: 0.5)
                    )
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(LumenTokens.Accent.amber)
                        .frame(width: 2)
                        .padding(.vertical, 4)
                        .padding(.leading, 1)
                        .shadow(color: LumenTokens.Accent.amberDim, radius: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Save status

private struct SaveStatusView: View {
    let state: NotesViewModel.SaveStatus

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
