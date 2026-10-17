import SwiftUI
import MarkdownUI
import UniformTypeIdentifiers

private typealias P = LumenTokens.Palette

struct NoteView: View {
    @State var viewModel = NotesViewModel()

    var body: some View {
        ZStack {
            LumenPanelBackground()
            HStack(spacing: 0) {
                NotesSidebar(viewModel: viewModel)
                    .frame(width: 240)
                Rectangle().fill(P.borderSubtle).frame(width: 1)
                mainPane
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(LumenShape.rect(LumenTokens.Radius.xl))
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
        ZStack {
            // 평상시 헤더 빈 공간 드래그로 윈도우 이동. 콘텐츠는 위에 겹쳐 hit-test 우선권 잡게.
            WindowDragArea()
            HStack {
                HStack(spacing: LumenTokens.Space.s3) {
                    LumenIcon("sticky-note")
                        .foregroundStyle(P.inkMuted)
                    Text(activeTitle)
                        .lumenText(.body, weight: .semibold)
                        .foregroundStyle(P.ink)
                        .lineLimit(1)
                    SaveStatusView(state: viewModel.saveStatus)
                }
                .allowsHitTesting(false)
                Spacer()
                ModeToggle(isPreview: viewModel.isPreview) {
                    viewModel.togglePreview()
                }
            }
            .padding(.horizontal, LumenTokens.Space.pad)
        }
        .frame(height: 56)
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
                        .padding(.horizontal, LumenTokens.Space.s6)
                        .padding(.vertical, LumenTokens.Space.pad)
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
            placeholder: "메모를 적어 보세요. 마크다운을 쓸 수 있어요.",
            fontSize: LumenTextStyle.body.size,
            focusToken: viewModel.isPreview ? 0 : viewModel.editFocusToken,
            caretRestoreToken: viewModel.caretRestoreToken,
            caretRestoreLocation: viewModel.caretRestoreLocation,
            onCaretChange: { viewModel.recordCaret($0) }
        )
        .id(viewModel.selectedID ?? "")
        .padding(.horizontal, LumenTokens.Space.s6)
        .padding(.vertical, LumenTokens.Space.pad)
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
    /// drag 중인 source note id — DropDelegate가 hover 위치 감지하면 즉시 reorder.
    @State private var draggingID: String?

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            LumenHairline()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.notes.enumerated()), id: \.element.id) { index, note in
                        DraggableSidebarRow(
                            note: note,
                            index: index,
                            viewModel: viewModel,
                            draggingID: $draggingID
                        )
                    }
                    // 마지막 row 아래 빈 공간 — 드랍하면 리스트 끝에 끼워넣음.
                    TrailingDropZone(viewModel: viewModel, draggingID: $draggingID)
                }
                .padding(LumenTokens.Space.inline)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .background(P.surface)
    }

    private var sidebarHeader: some View {
        ZStack {
            WindowDragArea()
            HStack(spacing: LumenTokens.Space.inline) {
                LumenSectionLabel(text: "노트")
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
                LumenIconButton(icon: "plus", label: "새 노트 (⌘N)") {
                    viewModel.createNewNote(activate: true)
                }
            }
            .padding(.leading, LumenTokens.Space.s4)
            .padding(.trailing, LumenTokens.Space.inline)
        }
        .frame(height: 56)
    }
}

/// SidebarRow + NSItemProvider/DropDelegate 기반 reorder.
/// `.dropDestination(for: String.self)`는 macOS에서 row hit-area가 작을 때 flaky라 DropDelegate로 처리.
private struct DraggableSidebarRow: View {
    let note: NoteItem
    let index: Int
    @Bindable var viewModel: NotesViewModel
    @Binding var draggingID: String?

    var body: some View {
        SidebarRow(
            note: note,
            index: index,
            isSelected: viewModel.selectedID == note.id,
            canDelete: viewModel.notes.count > 1,
            onSelect: { viewModel.selectNote(id: note.id) },
            onDelete: { viewModel.delete(id: note.id) }
        )
        .opacity(draggingID == note.id ? 0.4 : 1)
        .onDrag {
            draggingID = note.id
            return NSItemProvider(object: note.id as NSString)
        } preview: {
            SidebarRow(
                note: note,
                index: index,
                isSelected: true,
                canDelete: false,
                onSelect: {},
                onDelete: {}
            )
            .frame(width: 224)
            .opacity(0.85)
        }
        .onDrop(of: [.text], delegate: NoteReorderDelegate(
            target: note,
            viewModel: viewModel,
            draggingID: $draggingID
        ))
    }
}

private struct NoteReorderDelegate: DropDelegate {
    let target: NoteItem
    let viewModel: NotesViewModel
    @Binding var draggingID: String?

    func dropEntered(info: DropInfo) {
        guard let sourceID = draggingID, sourceID != target.id,
              let from = viewModel.notes.firstIndex(where: { $0.id == sourceID }),
              let to = viewModel.notes.firstIndex(where: { $0.id == target.id }) else { return }
        if from != to {
            viewModel.move(from: from, to: to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

/// 마지막 row 아래 빈 공간 drop zone — drag가 여기로 들어오면 즉시 끝으로 이동.
private struct TrailingDropZone: View {
    @Bindable var viewModel: NotesViewModel
    @Binding var draggingID: String?

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 40)
            .onDrop(of: [.text], delegate: TrailingDropDelegate(
                viewModel: viewModel,
                draggingID: $draggingID
            ))
    }
}

private struct TrailingDropDelegate: DropDelegate {
    let viewModel: NotesViewModel
    @Binding var draggingID: String?

    func dropEntered(info: DropInfo) {
        guard let sourceID = draggingID,
              let from = viewModel.notes.firstIndex(where: { $0.id == sourceID }) else { return }
        let lastIndex = viewModel.notes.count - 1
        if from != lastIndex {
            viewModel.move(from: from, to: viewModel.notes.count)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

private struct SidebarRow: View {
    let note: NoteItem
    let index: Int
    let isSelected: Bool
    let canDelete: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
                HStack(spacing: LumenTokens.Space.inline) {
                    Text(note.displayTitle)
                        .lumenText(.body, weight: isSelected ? .semibold : .medium)
                        .foregroundStyle(isSelected ? P.brand : P.ink)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // hover 시 같은 자리에 삭제 버튼이 덮어 그려진다.
                    if !isHovering, index < 9 {
                        LumenKbd(label: "⌘\(index + 1)")
                    }
                    if isHovering, canDelete {
                        LumenIconButton(icon: "trash-2", label: "노트 삭제", action: onDelete)
                            .padding(.vertical, -10)
                    }
                }
                if !note.preview.isEmpty {
                    Text(note.preview)
                        .lumenText(.caption)
                        .foregroundStyle(P.inkFaint)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, LumenTokens.Space.s3)
            .padding(.horizontal, LumenTokens.Space.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
        }
        .buttonStyle(LumenListRowStyle(isSelected: isSelected))
    }
}

// MARK: - Save status

private struct SaveStatusView: View {
    let state: NotesViewModel.SaveStatus

    var body: some View {
        HStack(spacing: LumenTokens.Space.s1) {
            if case .saved = state {
                LumenIcon("circle-check", size: .small)
                    .foregroundStyle(P.success)
            }
            Text(label)
                .lumenText(.caption)
                .foregroundStyle(P.inkFaint)
        }
    }

    private var label: String {
        switch state {
        case .resting: return "자동 저장"
        case .editing: return "편집 중"
        case .saved:   return "저장했어요"
        }
    }
}

// MARK: - Mode toggle

private struct ModeToggle: View {
    let isPreview: Bool
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: LumenTokens.Space.inline) {
            LumenSegmentedControl(
                items: [
                    .init(value: false, label: "편집", icon: "pencil"),
                    .init(value: true, label: "미리보기", icon: "eye"),
                ],
                selection: Binding(
                    get: { isPreview },
                    set: { if $0 != isPreview { onToggle() } }
                )
            )
            LumenKbd(label: "⌘⇧E")
        }
    }
}
