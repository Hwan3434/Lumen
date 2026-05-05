import SwiftUI

// 로컬 이벤트의 추가·편집 popover. 좌측 사이드바를 폐기하고 인라인 인터랙션으로 대체.
//
//  - NewEventPopover: 캘린더 셀 더블클릭 → 그 날짜로 시작일 prefill
//  - LocalEventEditPopover: 캘린더의 로컬 이벤트 막대 클릭 → 제목/시작/종료 편집 + 삭제

struct NewEventPopover: View {
    let initialDate: Date
    let onDismiss: () -> Void

    @State private var title: String = ""
    @State private var start: Date
    @State private var end: Date
    @State private var hasEnd: Bool = false
    @FocusState private var titleFocused: Bool

    init(initialDate: Date, onDismiss: @escaping () -> Void) {
        let day = Calendar.current.startOfDay(for: initialDate)
        self.initialDate = day
        self.onDismiss = onDismiss
        self._start = State(initialValue: day)
        self._end = State(initialValue: day)
    }

    var body: some View {
        EventForm(
            heading: "새 이벤트",
            title: $title,
            start: $start,
            end: $end,
            hasEnd: $hasEnd,
            titleFocused: $titleFocused,
            primaryLabel: "추가",
            onPrimary: commit,
            secondary: nil
        )
        .frame(width: 280)
        .onAppear { DispatchQueue.main.async { titleFocused = true } }
    }

    private func commit() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        LocalEventStore.shared.add(LocalEvent(
            title: trimmed,
            start: start,
            end: hasEnd ? end : nil
        ))
        onDismiss()
    }
}

struct LocalEventEditPopover: View {
    let initial: LocalEvent
    let onDismiss: () -> Void

    @State private var title: String
    @State private var start: Date
    @State private var end: Date
    @State private var hasEnd: Bool
    @FocusState private var titleFocused: Bool

    init(event: LocalEvent, onDismiss: @escaping () -> Void) {
        self.initial = event
        self.onDismiss = onDismiss
        _title = State(initialValue: event.title)
        _start = State(initialValue: event.start)
        _end = State(initialValue: event.end ?? event.start)
        _hasEnd = State(initialValue: event.end != nil)
    }

    var body: some View {
        EventForm(
            heading: "이벤트 편집",
            title: $title,
            start: $start,
            end: $end,
            hasEnd: $hasEnd,
            titleFocused: $titleFocused,
            primaryLabel: "저장",
            onPrimary: save,
            secondary: ("삭제", LumenTokens.ErrorTone.title, delete)
        )
        .frame(width: 280)
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        LocalEventStore.shared.update(LocalEvent(
            id: initial.id,
            title: trimmed,
            start: start,
            end: hasEnd ? end : nil
        ))
        onDismiss()
    }

    private func delete() {
        LocalEventStore.shared.delete(id: initial.id)
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
    /// 보조 액션(삭제 등) — (라벨, 색, 핸들러).
    let secondary: (String, Color, () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(heading)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(LumenTokens.TextColor.muted)
                Spacer()
            }

            TextField("제목", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused(titleFocused)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(LumenTokens.stroke, lineWidth: 0.5)
                        )
                )
                .onSubmit { onPrimary() }

            DatePicker("시작", selection: $start, displayedComponents: .date)
                .datePickerStyle(.compact)
                .font(.system(size: 11))
                .foregroundStyle(LumenTokens.TextColor.secondary)

            Toggle("종료일", isOn: $hasEnd)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundStyle(LumenTokens.TextColor.secondary)

            if hasEnd {
                DatePicker("종료", selection: $end, in: start..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(.system(size: 11))
                    .foregroundStyle(LumenTokens.TextColor.secondary)
            }

            HStack(spacing: 8) {
                if let s = secondary {
                    Button(action: s.2) {
                        Text(s.0)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(s.1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(s.1.opacity(0.45), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button(action: onPrimary) {
                    Text(primaryLabel)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(canCommit ? LumenTokens.TextColor.primary : LumenTokens.TextColor.muted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(canCommit ? LumenTokens.Accent.violet.opacity(0.22) : Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(canCommit ? LumenTokens.Accent.violet.opacity(0.45) : LumenTokens.stroke,
                                                lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canCommit)
            }
        }
        .padding(14)
    }

    private var canCommit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
