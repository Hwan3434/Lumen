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
    enum SaveStatus { case resting, editing, saved }

    private(set) var notes: [NoteItem] = []
    var selectedID: String?
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

    private let notesDir: URL = LumenStorage.url(for: .notesDir)

    init() {
        migrateLegacyIfNeeded()
        loadFromDisk()
        if notes.isEmpty {
            createNewNote(activate: true)
        } else if selectedID == nil {
            selectNote(id: notes.first!.id)
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
        let id = String(Int(Date().timeIntervalSince1970 * 1000))
        let item = NoteItem(id: id, text: "")
        notes.append(item)
        writeToDisk(item)
        writeOrder()
        if activate {
            selectedID = id
            activeText = ""
            isPreview = false
            saveStatus = .resting
            caretRestoreLocation = 0
            caretRestoreToken &+= 1
        }
    }

    /// 마지막 한 개는 지울 수 없음 — 항상 빈 노트라도 하나는 남겨둔다.
    func deleteCurrent() {
        guard let idx = selectedIndex else { return }
        delete(id: notes[idx].id)
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
        try? FileManager.default.removeItem(at: fileURL(for: id))
        stateByNoteID.removeValue(forKey: id)
        writeOrder()
        if wasSelected {
            let nextIdx = min(idx, notes.count - 1)
            selectNote(id: notes[nextIdx].id)
        }
    }

    /// 사이드바 드래그 드랍으로 호출 — source 노트를 destination row 자리에 끼워넣는다.
    func move(from source: Int, to destination: Int) {
        guard source != destination, notes.indices.contains(source) else { return }
        var reordered = notes
        let item = reordered.remove(at: source)
        let clamped = min(max(destination, 0), reordered.count)
        reordered.insert(item, at: clamped)
        notes = reordered
        writeOrder()
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

    /// keystroke 디바운스: 1초 후 draft를 notes 배열에 반영하고 디스크에 쓴다.
    private func scheduleCommitAndSave() {
        saveStatus = .editing
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.commitDraftNow()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    /// draft → notes 배열 커밋 + 디스크 저장 + saved flash. 이미 동일하면 무시.
    private func commitDraftNow() {
        saveWorkItem?.cancel()
        guard let id = selectedID,
              let idx = notes.firstIndex(where: { $0.id == id }),
              notes[idx].text != activeText else { return }
        notes[idx].text = activeText
        writeToDisk(notes[idx])
        saveStatus = .saved
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

    // MARK: - Disk

    private func fileURL(for id: String) -> URL {
        notesDir.appendingPathComponent("\(id).md")
    }

    private func writeToDisk(_ note: NoteItem) {
        try? note.text.write(to: fileURL(for: note.id), atomically: true, encoding: .utf8)
    }

    /// 노트 순서는 .order.json에 id 배열로 저장. 새 노트(메타에 없는 파일)는 timestamp 순으로 끝에 추가.
    private var orderFileURL: URL { notesDir.appendingPathComponent(".order.json") }

    private func writeOrder() {
        let ids = notes.map { $0.id }
        guard let data = try? JSONEncoder().encode(ids) else { return }
        try? data.write(to: orderFileURL, options: .atomic)
    }

    private func loadFromDisk() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: notesDir, includingPropertiesForKeys: nil) else { return }
        let mdFiles = urls.filter { $0.pathExtension == "md" }
        var byID: [String: NoteItem] = [:]
        for url in mdFiles {
            let id = url.deletingPathExtension().lastPathComponent
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            byID[id] = NoteItem(id: id, text: text)
        }
        let savedOrder: [String] = (try? Data(contentsOf: orderFileURL))
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        var ordered: [NoteItem] = []
        var seen = Set<String>()
        for id in savedOrder {
            if let n = byID[id] { ordered.append(n); seen.insert(id) }
        }
        // 메타에 없는 새 파일은 timestamp 순(파일명 사전순)으로 끝에.
        let leftovers = mdFiles
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { !seen.contains($0) }
            .sorted()
        for id in leftovers {
            if let n = byID[id] { ordered.append(n) }
        }
        notes = ordered
    }

    /// 0.x의 단일 note.md가 있고 notes/ 디렉터리가 비어 있으면 첫 노트로 옮기고 원본 삭제.
    private func migrateLegacyIfNeeded() {
        let fm = FileManager.default
        let legacyURL = LumenStorage.url(for: .legacyNote)
        guard fm.fileExists(atPath: legacyURL.path) else { return }

        let existing = (try? fm.contentsOfDirectory(at: notesDir, includingPropertiesForKeys: nil)) ?? []
        guard existing.filter({ $0.pathExtension == "md" }).isEmpty else { return }

        let id = String(Int(Date().timeIntervalSince1970 * 1000))
        let dest = fileURL(for: id)
        do {
            try fm.moveItem(at: legacyURL, to: dest)
        } catch {
            // 이동 실패 시 복사 후 원본 삭제 시도.
            if (try? fm.copyItem(at: legacyURL, to: dest)) != nil {
                try? fm.removeItem(at: legacyURL)
            }
        }
    }
}
