import XCTest
@testable import Lumen

/// 클립보드 화면의 선택은 위치가 아니라 항목을 따라간다.
/// 공용 `ClipboardStore.shared`의 메모리 속 기록만 잠깐 바꾸고 되돌린다. 저장을 부르는 함수(삭제, 다시 복사)는 쓰지 않는다.
@MainActor
final class ClipboardViewModelTests: XCTestCase {
    private var saved: [ClipboardItem] = []

    private func text(_ s: String) -> ClipboardItem {
        ClipboardItem(date: Date(), text: s, fileURLs: nil)
    }

    override func setUp() async throws {
        saved = ClipboardStore.shared.history
        ClipboardStore.shared.history = [text("가"), text("나"), text("다")]
    }

    override func tearDown() async throws {
        ClipboardStore.shared.history = saved
    }

    func testSelectionStaysOnItemWhenNewCopyArrives() {
        let vm = ClipboardViewModel()
        vm.panelWillShow()
        vm.moveDown()
        XCTAssertEqual(vm.selectedItem?.text, "나")

        ClipboardStore.shared.history.insert(text("새로 복사한 글"), at: 0)

        XCTAssertEqual(vm.selectedItem?.text, "나")
        XCTAssertEqual(vm.preview?.text, "나")
    }

    func testOpeningSelectsNewestAndQueryChangeSelectsFirstMatch() {
        let vm = ClipboardViewModel()
        vm.panelWillShow()
        XCTAssertEqual(vm.selectedItem?.text, "가")
        vm.query = "다"
        XCTAssertEqual(vm.selectedItem?.text, "다")
        XCTAssertEqual(vm.countLabel, "1 / 3")
    }

    /// 내려가 있는 패널은 미리보기(이미지 포함)를 들고 있지 않는다.
    func testHiddenPanelHasNoPreview() {
        let vm = ClipboardViewModel()
        vm.panelWillShow()
        XCTAssertNotNil(vm.preview)
        vm.panelDidHide()
        XCTAssertNil(vm.preview)
        vm.panelWillShow()
        XCTAssertEqual(vm.preview?.text, "가")
    }
}
