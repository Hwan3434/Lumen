import XCTest
@testable import Lumen

/// 노트 저장은 1초 디바운스 + 백그라운드 큐라, 타이핑 직후 앱이 종료되면 마지막 편집이
/// 통째로 사라졌다(종료 경로에 flush가 없었다). 그 보장을 고정한다.
///
/// 모든 테스트는 임시 디렉터리에서 돈다 — 사용자의 실제 노트를 건드리지 않기 위해.
final class NotePersistenceTests: XCTestCase {

    private var notesDir: URL!

    override func setUpWithError() throws {
        notesDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LumenNoteTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: notesDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: notesDir)
    }

    func testFlushWritesPendingEditImmediately() throws {
        let vm = NotesViewModel(notesDir: notesDir)
        let id = try XCTUnwrap(vm.selectedID)
        let body = "종료 직전에 친 문장"

        // 사용자가 타이핑한 직후 상태 — 아직 디바운스(1초)가 끝나지 않았다.
        vm.draftDidChange(body)

        let file = notesDir.appendingPathComponent("\(id).md")
        let beforeFlush = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        XCTAssertNotEqual(beforeFlush, body, "디바운스 중이라 아직 디스크에 없어야 정상")

        // 앱 종료 경로.
        vm.flushPendingWrites()

        let afterFlush = try String(contentsOf: file, encoding: .utf8)
        XCTAssertEqual(afterFlush, body, "flush 후에는 디바운스를 기다리지 않고 디스크에 있어야 한다")
    }

    /// 순서 파일도 같이 내려가야 한다 — 얘는 0.3초 디바운스였다.
    func testFlushWritesNoteOrder() throws {
        let vm = NotesViewModel(notesDir: notesDir)
        vm.createNewNote(activate: true)
        vm.createNewNote(activate: true)
        let ids = vm.notes.map(\.id)

        vm.flushPendingWrites()

        let data = try Data(contentsOf: notesDir.appendingPathComponent(".order.json"))
        let saved = try JSONDecoder().decode([String].self, from: data)
        XCTAssertEqual(saved, ids, "flush 후 순서 파일이 현재 노트 순서와 같아야 한다")
    }

    /// flush한 내용이 다음 실행에서 그대로 올라오는지 — 라운드트립.
    func testFlushedNoteSurvivesReload() throws {
        let body = "재시작 후에도 남아야 하는 문장"
        let first = NotesViewModel(notesDir: notesDir)
        first.draftDidChange(body)
        first.flushPendingWrites()

        let reloaded = NotesViewModel(notesDir: notesDir)
        XCTAssertEqual(reloaded.notes.first?.text, body)
    }
}
