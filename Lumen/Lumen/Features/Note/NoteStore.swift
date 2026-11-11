import Foundation

/// 노트 폴더의 파일 읽기·쓰기. 노트 하나가 `<id>.md` 파일 하나이고, 순서는 `.order.json`에 id 배열로 둔다.
/// `NotesViewModel`은 화면 상태만 다루고 디스크는 여기에 맡긴다.
final class NoteStore {
    private let directory: URL

    // 본문 쓰기·삭제·순서 저장이 모두 이 직렬 큐를 탄다 — 같은 노트의 쓰기와 삭제가 순서대로 처리돼,
    // 지운 파일을 뒤늦은 쓰기가 되살리지 않는다. 드래그로 순서를 바꿀 때는 100ms 단위로 저장 요청이
    // 쏟아지므로 순서 파일은 디바운스한다.
    private let diskQueue = DispatchQueue(label: "com.lumen.note.disk", qos: .utility)
    private var orderSaveWorkItem: DispatchWorkItem?
    /// 아직 디스크에 내려가지 않은 순서. `flush()`가 이 값이 있을 때만 순서 파일을 쓴다 —
    /// 바꾼 적이 없는데도 메모리의 순서로 덮어쓰면 밖에서 고친 순서 파일이 사라진다.
    private var pendingOrder: [String]?

    /// 본문을 디스크에 쓰지 못했을 때 메인에서 불린다. 화면이 "저장했어요"로 남지 않게 하려는 것.
    /// 동기 쓰기라면 `write`가 돌아오기 전에 불린다.
    var onWriteFailure: (() -> Void)?

    /// 기본값은 실제 저장 위치. 테스트가 사용자의 진짜 노트를 건드리지 않도록 주입 가능하게 열어둔다.
    init(directory: URL = LumenStorage.url(for: .notesDir)) {
        self.directory = directory
        // 0.x 단일 노트 마이그레이션은 실제 저장 위치를 쓸 때만 의미가 있다.
        if directory == LumenStorage.url(for: .notesDir) {
            migrateLegacyIfNeeded()
        }
    }

    static func makeNoteID() -> String {
        "\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString)"
    }

    private func fileURL(for id: String) -> URL {
        directory.appendingPathComponent("\(id).md")
    }

    private var orderFileURL: URL { directory.appendingPathComponent(".order.json") }

    // MARK: - 읽기

    /// 저장된 순서대로 모든 노트를 읽는다. 순서 파일에 없는 파일은 timestamp 순(파일명 사전순)으로 끝에 붙인다.
    func loadAll() -> [NoteItem] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        let mdFiles = urls.filter { $0.pathExtension == "md" }
        var byID: [String: NoteItem] = [:]
        for url in mdFiles {
            let id = url.deletingPathExtension().lastPathComponent
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            byID[id] = NoteItem(id: id, text: text)
        }
        let savedOrder = LumenStorage.read([String].self, from: orderFileURL) ?? []
        var ordered: [NoteItem] = []
        var seen = Set<String>()
        for id in savedOrder {
            if let n = byID[id] { ordered.append(n); seen.insert(id) }
        }
        let leftovers = byID.keys.filter { !seen.contains($0) }.sorted()
        for id in leftovers {
            if let n = byID[id] { ordered.append(n) }
        }
        return ordered
    }

    // MARK: - 쓰기

    /// `synchronously`면 큐에 쌓인 앞선 작업이 끝난 뒤 바로 쓰고 돌아온다(새 노트 만들기, 패널 닫기, 앱 종료).
    func write(_ note: NoteItem, synchronously: Bool = false) {
        let url = fileURL(for: note.id)
        let text = note.text
        let onFailure = onWriteFailure
        let write: () -> Bool = {
            (try? text.write(to: url, atomically: true, encoding: .utf8)) != nil
        }
        if synchronously {
            if !diskQueue.sync(execute: write) { onFailure?() }
        } else {
            diskQueue.async {
                if !write() { DispatchQueue.main.async { onFailure?() } }
            }
        }
    }

    func delete(id: String) {
        let url = fileURL(for: id)
        // 영구 삭제 대신 휴지통으로 — 잘못 지워도 Finder에서 꺼낼 수 있다.
        diskQueue.async {
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }

    func writeOrder(_ ids: [String]) {
        let url = orderFileURL
        pendingOrder = ids
        orderSaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            LumenStorage.write(ids, to: url)
            DispatchQueue.main.async {
                if self?.pendingOrder == ids { self?.pendingOrder = nil }
            }
        }
        orderSaveWorkItem = work
        diskQueue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// 대기 중인 순서 저장을 바로 쓰고, 큐에 남은 쓰기·삭제가 끝날 때까지 기다린다.
    /// 평소 저장은 백그라운드 큐라, 앱이 종료되면 큐에 떠 있던 작업이 프로세스와 함께 사라진다.
    func flush() {
        orderSaveWorkItem?.cancel()
        orderSaveWorkItem = nil
        let ids = pendingOrder
        pendingOrder = nil
        let url = orderFileURL
        // 직렬 큐라 sync로 밀어 넣으면 그 앞의 작업이 모두 끝난 뒤에 돌아온다.
        diskQueue.sync {
            if let ids { LumenStorage.write(ids, to: url) }
        }
    }

    // MARK: - 마이그레이션

    /// 0.x의 단일 note.md가 있고 notes/ 디렉터리가 비어 있으면 첫 노트로 옮기고 원본 삭제.
    private func migrateLegacyIfNeeded() {
        let fm = FileManager.default
        let legacyURL = LumenStorage.url(for: .legacyNote)
        guard fm.fileExists(atPath: legacyURL.path) else { return }

        let existing = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        guard existing.filter({ $0.pathExtension == "md" }).isEmpty else { return }

        let dest = fileURL(for: Self.makeNoteID())
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
