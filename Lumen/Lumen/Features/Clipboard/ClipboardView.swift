import SwiftUI

private typealias P = LumenTokens.Palette

struct ClipboardView: View {
    @State var viewModel = ClipboardViewModel()
    @State private var showDeleteAllConfirm = false

    private var listColumnWidth: CGFloat { LumenTokens.Space.size(360) }

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                listColumn
                    .frame(width: listColumnWidth)
                LumenHairline(.vertical)
                previewColumn
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            footer
        }
        .lumenPanel()
        .confirmationDialog(
            "클립보드 기록을 모두 지울까요?",
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button("모두 삭제", role: .destructive) { viewModel.deleteAll() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("지운 기록은 되돌릴 수 없어요.")
        }
    }

    // MARK: - Header

    private var header: some View {
        LumenPanelHeader(icon: "clipboard-list", title: "클립보드") {
            Text(viewModel.countLabel)
                .lumenText(.caption)
                .monospacedDigit()
                .foregroundStyle(P.inkFaint)
            if viewModel.query.isEmpty == false {
                Text("검색 중")
                    .lumenText(.caption)
                    .foregroundStyle(P.inkFaint)
            }
        } trailing: {
            LumenIconButton(icon: "trash-2", label: "모두 삭제") {
                showDeleteAllConfirm = true
            }
            .disabled(viewModel.isHistoryEmpty)
            LumenKbd(label: "⌘⇧V")
        }
    }

    // MARK: - List column

    private var listColumn: some View {
        VStack(spacing: 0) {
            searchField
            LumenHairline()
            if viewModel.filteredItems.isEmpty {
                listEmptyState
            } else {
                listContent
            }
        }
    }

    private var searchField: some View {
        LumenInputField(
            text: $viewModel.query,
            placeholder: "클립보드 검색",
            fontSize: LumenTextStyle.body.size,
            leading: {
                LumenIcon("search")
                    .foregroundStyle(P.inkMuted)
            },
            trailing: {
                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                    } label: {
                        LumenIcon("circle-x", size: .small)
                            .foregroundStyle(P.inkFaint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("검색어 지우기")
                }
            }
        )
        .padding(.horizontal, LumenTokens.Space.s4)
        .frame(height: LumenTokens.Space.size(52))
    }

    private var listEmptyState: some View {
        LumenEmptyState(icon: "search",
                        text: viewModel.query.isEmpty ? "아직 복사한 항목이 없어요" : "찾는 항목이 없어요")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(LumenTokens.Space.pad)
    }

    private var listContent: some View {
        let selectedID = viewModel.selectedItem?.id
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredItems) { item in
                        Button {
                            viewModel.select(item)
                        } label: {
                            ClipboardListRow(
                                item: item,
                                isSelected: item.id == selectedID,
                                onDelete: { viewModel.delete(item: item) }
                            )
                        }
                        .buttonStyle(LumenListRowStyle(isSelected: item.id == selectedID))
                        .id(item.id)
                    }
                }
                .padding(LumenTokens.Space.inline)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selectedID) { _, newValue in
                if let newValue {
                    withAnimation(LumenTokens.Motion.easeMove()) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Preview column

    @ViewBuilder
    private var previewColumn: some View {
        if let preview = viewModel.preview {
            ClipboardPreview(preview: preview)
        } else {
            previewEmpty
        }
    }

    private var previewEmpty: some View {
        LumenEmptyState(icon: "clipboard-list", text: "항목을 고르면 여기에 미리 보여요")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        LumenFooterBar(actions: [
            .init(label: "복사", kbd: "⏎", primary: true),
            .init(label: "삭제", kbd: "⌘⌫"),
            .init(label: "닫기", kbd: "esc"),
        ])
    }
}
