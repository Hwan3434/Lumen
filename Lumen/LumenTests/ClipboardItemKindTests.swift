import AppKit
import XCTest
@testable import Lumen

/// 클립보드 항목 종류 판정과 종류별 화면 문구·아이콘 이름을 확인한다.
final class ClipboardItemKindTests: XCTestCase {
    private let fileURL = URL(fileURLWithPath: "/tmp/a.txt")

    func testTextOnlyIsText() {
        let item = ClipboardItem(date: Date(), text: "hello", fileURLs: nil, image: nil)
        XCTAssertEqual(item.kind, .text)
    }

    func testImageIsImage() {
        let item = ClipboardItem(date: Date(), text: nil, fileURLs: nil, image: NSImage())
        XCTAssertEqual(item.kind, .image)
    }

    func testImagePathOnlyIsImage() {
        let item = ClipboardItem(date: Date(), text: nil, fileURLs: nil, image: nil, imagePath: "/tmp/x.png")
        XCTAssertEqual(item.kind, .image)
    }

    func testFileWinsOverImageAndText() {
        let item = ClipboardItem(date: Date(), text: "t", fileURLs: [fileURL], image: NSImage(), imagePath: "/tmp/x.png")
        XCTAssertEqual(item.kind, .file)
    }

    func testImageWinsOverText() {
        let item = ClipboardItem(date: Date(), text: "t", fileURLs: nil, image: NSImage())
        XCTAssertEqual(item.kind, .image)
    }

    func testEmptyItemIsText() {
        let item = ClipboardItem(date: Date(), text: nil, fileURLs: nil, image: nil)
        XCTAssertEqual(item.kind, .text)
    }

    func testLabelsAndIcons() {
        XCTAssertEqual(ClipboardItem.Kind.text.label, "텍스트")
        XCTAssertEqual(ClipboardItem.Kind.image.label, "이미지")
        XCTAssertEqual(ClipboardItem.Kind.file.label, "파일")
        XCTAssertEqual(ClipboardItem.Kind.text.icon, "align-left")
        XCTAssertEqual(ClipboardItem.Kind.image.icon, "image")
        XCTAssertEqual(ClipboardItem.Kind.file.icon, "file")
    }
}
