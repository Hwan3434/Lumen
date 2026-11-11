import Foundation
import Observation

/// 메모 1개. 디스크의 .md 파일 1개와 1:1 대응.
/// id는 파일명에 쓰이는 timestamp 문자열 (생성 순서 정렬에 그대로 활용).
struct NoteItem: Identifiable, Equatable {
    let id: String
    var text: String

    /// 첫 비어있지 않은 줄을 제목으로. Markdown `# `, `## ` 같은 헤딩 마커는 떼어낸다.
    /// 본문이 비면 "새 노트".
    var displayTitle: String {
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let stripped = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            return stripped.isEmpty ? "새 노트" : String(stripped.prefix(40))
        }
        return "새 노트"
    }

    /// 본문 두 번째~네 번째 줄까지의 발췌. 사이드바 미리보기에 사용.
    var preview: String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count > 1 else { return "" }
        return lines.dropFirst().prefix(2).joined(separator: " ")
    }
}

/// 노트별 UI 상태 — 메모리 only (앱 재시작 시 리셋). 새 상태가 늘어나도 한 군데서 관리.
struct NoteUIState {
    /// nil이면 텍스트 끝으로 복원(LumenTextArea가 length로 clamp).
    var caret: Int?
    var isPreview: Bool = false
}

@Observable
final class NotesViewModel {
    enum SaveStatus { case resting, editing, saved, failed }

    private(set) var notes: [NoteItem] = []
    var selectedID: String?
    /// 삭제 확인 창이 떠 있는 노트.
    var pendingDeleteID: String?
    var isPreview = false
    /// 편집 모드 진입 시마다 증가 — LumenTextArea가 이 값 변화를 감지해 NSTextView를
    /// first responder로 다시 잡는다 (preview→edit 토글 후 마우스 클릭 없이 바로 입력 가능하게).
    var editFocusToken: Int = 0
    var saveStatus: SaveStatus = .resting

    /// 키 입력은 이 드래프트만 갱신하고, 디바운스 만료 시점에만 `notes`로 commit한다.
    /// 사이드바가 매 keystroke마다 displayTitle/preview를 다시 계산하지 않게 하려는 분리.
    /// 노트 전환·외부 commit 시점에 동기화된다.
    var activeText: String = ""

    private var stateByNoteID: [String: NoteUIState] = [:]
    /// 노트 전환마다 +1 — LumenTextArea가 토큰 변화 감지 시 caretRestoreLocation을 1회 적용.
    var caretRestoreToken: Int = 0
    var caretRestoreLocation: Int = 0

    /// 현재 선택된 노트 인덱스 — 키 핸들러가 ⌘1~9 매핑할 때 사용.
    var selectedIndex: Int? {
        guard let selectedID else { return nil }
        return notes.firstIndex { $0.id == selectedID }
    }

    private var saveWorkItem: DispatchWorkItem?
    private var savedFlashWorkItem: DispatchWorkItem?

    private let store: NoteStore
    /// 이번 실행에서 본문 쓰기가 한 번이라도 실패했는지. 그 뒤로는 메모리가 디스크보다 새로울 수 있어
    /// `reloadFromDisk()`가 디스크 내용으로 덮지 않는다.
    private var hadWriteFailure = false

    /// 기본값은 실제 저장 위치. 테스트가 사용자의 진짜 노트를 건드리지 않도록 주입 가능하게 열어둔다.
    init(notesDir: URL = LumenStorage.url(for: .notesDir)) {
        store = NoteStore(directory: notesDir)
        store.onWriteFailure = { [weak self] in
            self?.hadWriteFailure = true
            self?.saveStatus = .failed
        }
        notes = store.loadAll()
        if notes.isEmpty {
            createNewNote(activate: true)
        } else {
            selectNote(id: notes[0].id)
        }
    }

    /// 패널을 열 때마다 부른다. 노트 폴더는 Lumen 밖에서도 바뀔 수 있다(`lumen-note` 스킬이 노트를 만들고 지운다).
    /// 디스크가 메모리와 같으면 아무것도 건드리지 않는다 — 커서, 실행 취소 기록, 쓰던 글이 그대로 남는다.
    func reloadFromDisk() {
        // 메모리에만 있는 편집을 먼저 내려야, 아래에서 읽은 디스크 내용과 다르면 밖에서 바뀐 것이라고 볼 수 있다.
        flushPendingWrites()
        guard !hadWriteFailure else { return }
        let loaded = store.loadAll()
        guard loaded != notes else { return }
        notes = loaded
        if notes.isEmpty {
            createNewNote(activate: true)
        } else if let current = notes.first(where: { $0.id == selectedID }) {
            activeText = current.text
        } else {
            selectNote(id: notes[0].id)
        }
    }

    // MARK: - Selection / Tabs

    /// View에서 매 keystroke마다 호출 — 드래프트만 갱신하고 디바운스 commit 예약.
    func draftDidChange(_ newValue: String) {
        guard activeText != newValue else { return }
        activeText = newValue
        scheduleCommitAndSave()
    }

    func selectNote(id: String) {
        guard notes.contains(where: { $0.id == id }) else { return }
        // 노트 전환 전, 펜딩 변경분이 있으면 즉시 commit해서 잃지 않도록 한다.
        commitDraftNow()
        // 떠나는 노트의 현재 모드 기억.
        if let prev = selectedID {
            stateByNoteID[prev, default: NoteUIState()].isPreview = isPreview
        }
        selectedID = id
        activeText = notes.first { $0.id == id }?.text ?? ""
        let next = stateByNoteID[id] ?? NoteUIState()
        isPreview = next.isPreview
        saveStatus = .resting
        // nil이면 텍스트 끝(Int.max는 LumenTextArea가 length로 clamp).
        caretRestoreLocation = next.caret ?? .max
        caretRestoreToken &+= 1
    }

    /// LumenTextArea가 사용자 selection 변경마다 호출 — 다음 전환 시 복원하기 위해 기억.
    func recordCaret(_ location: Int) {
        guard let selectedID else { return }
        stateByNoteID[selectedID, default: NoteUIState()].caret = location
    }

    func selectIndex(_ index: Int) {
        guard notes.indices.contains(index) else { return }
        selectNote(id: notes[index].id)
    }

    func selectNext() {
        guard let cur = selectedIndex else { return }
        let next = (cur + 1) % notes.count
        selectNote(id: notes[next].id)
    }

    func selectPrev() {
        guard let cur = selectedIndex else { return }
        let prev = (cur - 1 + notes.count) % notes.count
        selectNote(id: notes[prev].id)
    }

    func createNewNote(activate: Bool) {
        if activate { commitDraftNow() }
        let id = NoteStore.makeNoteID()
        let item = NoteItem(id: id, text: "")
        notes.append(item)
        store.write(item, synchronously: true)
        store.writeOrder(notes.map(\.id))
        if activate {
            selectedID = id
            activeText = ""
            isPreview = false
            saveStatus = .resting
            caretRestoreLocation = 0
            caretRestoreToken &+= 1
        }
    }

    /// 지우기 전에 확인을 받는다. ⌘⌫는 텍스트 편집에서 손에 익은 키라 바로 지우면 노트를 통째로 잃는다.
    /// 마지막 한 개는 지울 수 없음 — 항상 빈 노트라도 하나는 남겨둔다.
    func requestDelete(id: String) {
        guard notes.count > 1 else { return }
        pendingDeleteID = id
    }

    func requestDeleteCurrent() {
        guard let idx = selectedIndex else { return }
        requestDelete(id: notes[idx].id)
    }

    func delete(id: String) {
        guard notes.count > 1, let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = (selectedID == id)
        // 펜딩 commit이 있다면 — 삭제 대상의 것이면 의미 없으니 cancel, 아니면 잃지 않게 즉시 commit.
        if wasSelected {
            saveWorkItem?.cancel()
        } else {
            commitDraftNow()
        }
        notes.remove(at: idx)
        store.delete(id: id)
        stateByNoteID.removeValue(forKey: id)
        store.writeOrder(notes.map(\.id))
        if wasSelected {
            let nextIdx = min(idx, notes.count - 1)
            selectNote(id: notes[nextIdx].id)
        }
    }

    /// 사이드바 드래그 드랍으로 호출 — source 노트를 destination row 자리에 끼워넣는다.
    /// destination은 "remove 전" 인덱스 기준이라, source가 앞에 있을 땐 remove로 한 칸 당겨지는 걸 보정한다.
    func move(from source: Int, to destination: Int) {
        guard source != destination, notes.indices.contains(source) else { return }
        var reordered = notes
        let item = reordered.remove(at: source)
        let adjusted = source < destination ? destination - 1 : destination
        let clamped = min(max(adjusted, 0), reordered.count)
        reordered.insert(item, at: clamped)
        notes = reordered
        store.writeOrder(notes.map(\.id))
    }

    // MARK: - Editing

    func togglePreview() {
        // 미리보기로 전환할 때는 draft를 commit해서 미리보기가 stale하지 않게.
        if !isPreview { commitDraftNow() }
        isPreview.toggle()
        if let id = selectedID {
            stateByNoteID[id, default: NoteUIState()].isPreview = isPreview
        }
        if !isPreview { editFocusToken &+= 1 }
    }

    /// 패널을 내릴 때와 종료 직전 호출 — 디바운스 대기 중인 편집과 순서 변경을 **동기로** 디스크에 내린다.
    ///
    /// 평소 저장 경로는 1초 디바운스 + 백그라운드 큐라, 타이핑 직후 앱이 종료되면
    /// 대기 중인 work item도 큐에 떠 있던 쓰기도 프로세스와 함께 사라진다.
    func flushPendingWrites() {
        commitDraftNow(synchronously: true)
        store.flush()
    }

    /// keystroke 디바운스: 1초 후 draft를 notes 배열에 반영하고 디스크에 쓴다.
    private func scheduleCommitAndSave() {
        // 같은 값이어도 대입하면 관찰하는 뷰가 다시 그려진다. 머리줄이 키 입력마다 제목을 다시 계산하지 않게 막는다.
        if saveStatus != .editing { saveStatus = .editing }
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.commitDraftNow()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    /// draft → notes 배열 커밋 + 디스크 저장 + saved flash. 이미 동일하면 무시.
    /// `synchronously`면 쓰기가 끝난 뒤에 돌아온다 (패널 닫기, 종료 직전 경로).
    private func commitDraftNow(synchronously: Bool = false) {
        saveWorkItem?.cancel()
        guard let id = selectedID,
              let idx = notes.firstIndex(where: { $0.id == id }),
              notes[idx].text != activeText else { return }
        notes[idx].text = activeText
        // 쓰기에 실패하면 store.onWriteFailure가 뒤이어 `.failed`로 바꾼다.
        saveStatus = .saved
        store.write(notes[idx], synchronously: synchronously)
        flashSavedReset()
    }

    private func flashSavedReset() {
        savedFlashWorkItem?.cancel()
        let flash = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.saveStatus == .saved { self.saveStatus = .resting }
        }
        savedFlashWorkItem = flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: flash)
    }
}
