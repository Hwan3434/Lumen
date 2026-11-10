import SwiftUI

/// 내 일정의 추가·편집 팝오버.
///  - 추가(`isNew`): 캘린더 빈 날짜 더블클릭·⌘N → 그 날짜를 시작일로 채운 빈 일정을 `draft`로 받는다
///  - 편집: 내 일정 막대 클릭 → 제목·시작·종료 편집과 삭제
struct LocalEventPopover: View {
    let plugin: LocalPlugin
    let draft: LocalEvent
    let isNew: Bool
    let onDismiss: () -> Void

    @State private var title: String
    @State private var start: Date
    @State private var end: Date
    @State private var hasEnd: Bool
    @FocusState private var titleFocused: Bool

    private typealias P = LumenTokens.Palette

    init(plugin: LocalPlugin, draft: LocalEvent, isNew: Bool, onDismiss: @escaping () -> Void) {
        self.plugin = plugin
        self.draft = draft
        self.isNew = isNew
        self.onDismiss = onDismiss
        _title = State(initialValue: draft.title)
        _start = State(initialValue: draft.start)
        _end = State(initialValue: draft.end ?? draft.start)
        _hasEnd = State(initialValue: draft.end != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.group) {
            Text(isNew ? "새 일정" : "일정 편집")
                .lumenText(.title3)
                .foregroundStyle(P.ink)

            VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
                LumenLabeledField(label: "제목") {
                    LumenTextField(text: $title, focus: $titleFocused)
                        .onSubmit { commit() }
                }

                DatePicker("시작", selection: $start, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(LumenFont.style(.label))
                    .foregroundStyle(P.inkMuted)

                Toggle("종료일 지정", isOn: $hasEnd)
                    .toggleStyle(.checkbox)
                    .font(LumenFont.style(.label, weight: .regular))
                    .foregroundStyle(P.ink)
                    .tint(P.brand)

                if hasEnd {
                    DatePicker("종료", selection: $end, in: start..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .font(LumenFont.style(.label))
                        .foregroundStyle(P.inkMuted)
                }
            }

            HStack(spacing: LumenTokens.Space.inline) {
                if !isNew {
                    Button("삭제") {
                        plugin.delete(id: draft.id)
                        onDismiss()
                    }
                    .buttonStyle(LumenButtonStyle(variant: .ghost))
                }
                Spacer()
                Button(isNew ? "추가" : "저장", action: commit)
                    .buttonStyle(LumenButtonStyle(variant: .primary))
                    .disabled(trimmedTitle.isEmpty)
            }
        }
        .padding(LumenTokens.Space.pad)
        .background(P.surfaceRaised)
        .frame(width: LumenTokens.Space.size(360))
        .onAppear {
            if isNew { DispatchQueue.main.async { titleFocused = true } }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commit() {
        guard !trimmedTitle.isEmpty else { return }
        let event = LocalEvent(id: draft.id, title: trimmedTitle, start: start, end: hasEnd ? end : nil)
        if isNew {
            plugin.add(event)
        } else {
            plugin.update(event)
        }
        onDismiss()
    }
}
