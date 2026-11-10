import XCTest
@testable import Lumen

/// 번역 기록은 LumenStorage(atomic 쓰기)로 저장된다. 저장한 기록이 다음 실행에서 그대로 읽히는지,
/// 그리고 예전 방식(JSONEncoder 기본값 + 일반 쓰기)으로 저장된 파일도 그대로 읽히는지 고정한다.
///
/// 모든 테스트는 임시 파일에서 돈다 — 사용자의 실제 번역 기록을 건드리지 않기 위해.
@MainActor
final class TranslationPersistenceTests: XCTestCase {

    private var dir: URL!
    private var file: URL { dir.appendingPathComponent("translation_history.json") }

    override func setUpWithError() throws {
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LumenTranslationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testSavedHistorySurvivesReload() throws {
        let first = TranslatorViewModel(savePath: file)
        first.inputText = "안녕하세요"
        first.handleTranslationResult("Hello")
        let saved = try XCTUnwrap(first.history.first)

        let reloaded = TranslatorViewModel(savePath: file)
        let item = try XCTUnwrap(reloaded.history.first)
        XCTAssertEqual(reloaded.history.count, 1)
        XCTAssertEqual(item.id, saved.id)
        XCTAssertEqual(item.original, "안녕하세요")
        XCTAssertEqual(item.translated, "Hello")
        XCTAssertEqual(item.date.timeIntervalSinceReferenceDate,
                       saved.date.timeIntervalSinceReferenceDate, accuracy: 0.001)
    }

    /// 바꾸기 전 코드가 남긴 파일 모양 그대로 써 두고 읽는다 — 기존 기록이 사라지면 안 된다.
    /// 발음 칸은 지금은 읽지 않지만, 그 키가 들어 있는 예전 파일도 읽혀야 한다.
    func testReadsFileWrittenInPreviousFormat() throws {
        struct Legacy: Codable {
            let id: String
            let original: String
            let translated: String
            let pronunciation: String?
            let inputPronunciation: String?
            let date: Date
        }
        let id = UUID()
        let legacy = [Legacy(id: id.uuidString, original: "apple", translated: "사과",
                             pronunciation: "sagwa", inputPronunciation: "aepeul", date: Date())]
        try JSONEncoder().encode(legacy).write(to: file)

        let vm = TranslatorViewModel(savePath: file)
        XCTAssertEqual(vm.history.first?.id, id)
        XCTAssertEqual(vm.history.first?.translated, "사과")
    }
}
