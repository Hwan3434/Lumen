import SwiftUI

// 내 일정의 추가·편집 팝오버.
//  - NewEventPopover: 캘린더 빈 날짜 더블클릭 → 그 날짜로 시작일을 채워 둔다
//  - LocalEventEditPopover: 내 일정 막대 클릭 → 제목·시작·종료 편집과 삭제

struct NewEventPopover: View {
    let plugin: LocalPlugin
    let onDismiss: () -> Void

    @State private var title: String = ""
    @State private var start: Date
    @State private var end: Date
    @State private var hasEnd: Bool = false
    @FocusState private var titleFocused: Bool

    init(plugin: LocalPlugin, initialDate: Date, onDismiss: @escaping () -> Void) {
        let day = Calendar.current.startOfDay(for: initialDate)
        self.plugin = plugin
        self.onDismiss = onDismiss
        self._start = State(initialValue: day)
        self._end = State(initialValue: day)
    }

    var body: some View {
        EventForm(
            heading: "새 일정",
            title: $title,
            start: $start,
            end: $end,
            hasEnd: $hasEnd,
            titleFocused: $titleFocused,
            primaryLabel: "추가",
            onPrimary: commit,
            secondary: nil
        )
        .frame(width: LumenTokens.Space.size(360))
        .onAppear { DispatchQueue.main.async { titleFocused = true } }
    }

    private func commit() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        plugin.add(LocalEvent(title: trimmed, start: start, end: hasEnd ? end : nil))
        onDismiss()
    }
}

struct LocalEventEditPopover: View {
    let plugin: LocalPlugin
    let initial: LocalEvent
    let onDismiss: () -> Void

    @State private var title: String
    @State private var start: Date
    @State private var end: Date
    @State private var hasEnd: Bool
    @FocusState private var titleFocused: Bool

    init(plugin: LocalPlugin, event: LocalEvent, onDismiss: @escaping () -> Void) {
        self.plugin = plugin
        self.initial = event
        self.onDismiss = onDismiss
        _title = State(initialValue: event.title)
        _start = State(initialValue: event.start)
        _end = State(initialValue: event.end ?? event.start)
        _hasEnd = State(initialValue: event.end != nil)
    }

    var body: some View {
        EventForm(
            heading: "일정 편집",
            title: $title,
            start: $start,
            end: $end,
            hasEnd: $hasEnd,
            titleFocused: $titleFocused,
            primaryLabel: "저장",
            onPrimary: save,
            secondary: ("삭제", delete)
        )
        .frame(width: LumenTokens.Space.size(360))
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        plugin.update(LocalEvent(id: initial.id, title: trimmed, start: start, end: hasEnd ? end : nil))
        onDismiss()
    }

    private func delete() {
        plugin.delete(id: initial.id)
        onDismiss()
    }
}

// MARK: - Shared form

private struct EventForm: View {
    let heading: String
    @Binding var title: String
    @Binding var start: Date
    @Binding var end: Date
    @Binding var hasEnd: Bool
    var titleFocused: FocusState<Bool>.Binding
    let primaryLabel: String
    let onPrimary: () -> Void
    /// 보조 액션(삭제 등) — (라벨, 핸들러).
    let secondary: (String, () -> Void)?

    private typealias P = LumenTokens.Palette

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.group) {
            Text(heading)
                .lumenText(.title3)
                .foregroundStyle(P.ink)

            VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
                LumenLabeledField(label: "제목") {
                    LumenTextField(text: $title, focus: titleFocused)
                        .onSubmit { onPrimary() }
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
                if let s = secondary {
                    Button(s.0, action: s.1)
                        .buttonStyle(LumenButtonStyle(variant: .ghost))
                }
                Spacer()
                Button(primaryLabel, action: onPrimary)
                    .buttonStyle(LumenButtonStyle(variant: .primary))
                    .disabled(!canCommit)
            }
        }
        .padding(LumenTokens.Space.pad)
        .background(P.surfaceRaised)
    }

    private var canCommit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
