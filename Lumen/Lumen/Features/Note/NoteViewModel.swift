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

@Observable
final class NotesViewModel {
    enum SaveStatus { case resting, editing, saved }

    private(set) var notes: [NoteItem] = []
    var selectedID: String?
    var isPreview = false
    var saveStatus: SaveStatus = .resting

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
            selectedID = notes.first?.id
        }
    }

    // MARK: - Selection / Tabs

    /// 활성 탭의 본문에 직접 바인딩 (없으면 빈 문자열 반환 / 무시).
    var activeText: String {
        get { notes.first { $0.id == selectedID }?.text ?? "" }
        set {
            guard let idx = notes.firstIndex(where: { $0.id == selectedID }) else { return }
            notes[idx].text = newValue
            scheduleSave(for: notes[idx])
        }
    }

    func selectNote(id: String) {
        guard notes.contains(where: { $0.id == id }) else { return }
        selectedID = id
        isPreview = false
        saveStatus = .resting
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
        let id = String(Int(Date().timeIntervalSince1970 * 1000))
        let item = NoteItem(id: id, text: "")
        notes.append(item)
        writeToDisk(item)
        if activate { selectNote(id: id) }
    }

    /// 마지막 한 개는 지울 수 없음 — 항상 빈 노트라도 하나는 남겨둔다.
    func deleteCurrent() {
        guard notes.count > 1, let idx = selectedIndex else { return }
        let id = notes[idx].id
        notes.remove(at: idx)
        try? FileManager.default.removeItem(at: fileURL(for: id))
        let nextIdx = min(idx, notes.count - 1)
        selectNote(id: notes[nextIdx].id)
    }

    // MARK: - Editing

    func togglePreview() { isPreview.toggle() }

    private func scheduleSave(for note: NoteItem) {
        saveStatus = .editing
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.writeToDisk(note)
            self?.saveStatus = .saved
            self?.flashSavedReset()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
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

    private func loadFromDisk() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: notesDir, includingPropertiesForKeys: nil) else { return }
        let mdFiles = urls.filter { $0.pathExtension == "md" }
        // 파일명(id)이 timestamp이므로 사전순 == 생성순.
        let sorted = mdFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
        notes = sorted.map { url in
            let id = url.deletingPathExtension().lastPathComponent
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return NoteItem(id: id, text: text)
        }
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
