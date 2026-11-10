import XCTest
@testable import Lumen

/// 번역 화면의 판단 로직. 기록 파일은 임시 경로를 쓴다.
@MainActor
final class TranslatorViewModelTests: XCTestCase {
    private var file: URL!
    private var vm: TranslatorViewModel!

    override func setUp() async throws {
        file = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumenTranslatorVM-\(UUID().uuidString).json")
        vm = TranslatorViewModel(savePath: file)
        vm.handleTranslationResult(original: "두 번째", translated: "second")
        vm.handleTranslationResult(original: "첫 번째", translated: "first")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: file)
    }

    /// 기록의 원문은 번역을 보낼 때의 글이다. 결과가 올 때 입력 칸에 있는 글이 아니다.
    func testHistoryKeepsTheTextThatWasTranslated() {
        vm.inputText = "기다리는 동안 고친 글"
        vm.handleTranslationResult(original: "보낸 글", translated: "sent")
        XCTAssertEqual(vm.history.first?.original, "보낸 글")
        XCTAssertEqual(vm.history.first?.translated, "sent")
    }

    /// 쓰고 있는 글이 있으면 화살표는 입력 칸의 것이다. ↓ 한 번에 쓰던 글이 기록으로 바뀌면 안 된다.
    func testArrowsDoNotReplaceADraft() {
        vm.inputText = "쓰고 있는\n여러 줄 글"
        XCTAssertFalse(vm.moveDown())
        XCTAssertFalse(vm.moveUp())
        XCTAssertEqual(vm.inputText, "쓰고 있는\n여러 줄 글")
    }

    func testArrowsNavigateHistoryWhenInputIsEmptyOrASelectedItem() {
        vm.inputText = ""
        vm.selectedHistoryIndex = -1
        XCTAssertTrue(vm.moveDown())
        XCTAssertEqual(vm.inputText, "첫 번째")
        // 끝에 줄바꿈이 붙어도 고른 기록 그대로로 본다(기록은 앞뒤 공백을 뗀 원문을 담는다).
        vm.inputText = "첫 번째\n"
        XCTAssertTrue(vm.moveDown())
        XCTAssertEqual(vm.inputText, "두 번째")
        XCTAssertEqual(vm.translatedText, "second")
    }

    /// 번역에 실패한 뒤 기록을 고르면 오류 띠가 아니라 그 기록이 보인다.
    func testSelectingHistoryClearsErrorAndLoading() {
        vm.errorMessage = "실패"
        vm.isLoading = true
        vm.selectHistory(at: 1)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(vm.translatedText, "second")
    }
}
