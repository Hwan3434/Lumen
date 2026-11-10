import AppKit
import XCTest
@testable import Lumen

/// 클립보드 항목 종류 판정, 종류별 화면 문구·아이콘 이름, 중복 판정을 확인한다.
final class ClipboardItemKindTests: XCTestCase {
    private let fileURL = URL(fileURLWithPath: "/tmp/a.txt")

    func testTextOnlyIsText() {
        let item = ClipboardItem(date: Date(), text: "hello", fileURLs: nil)
        XCTAssertEqual(item.kind, .text)
    }

    func testImagePathIsImage() {
        let item = ClipboardItem(date: Date(), text: nil, fileURLs: nil, imagePath: "/tmp/x.png")
        XCTAssertEqual(item.kind, .image)
    }

    func testFileWinsOverImageAndText() {
        let item = ClipboardItem(date: Date(), text: "t", fileURLs: [fileURL], imagePath: "/tmp/x.png")
        XCTAssertEqual(item.kind, .file)
    }

    func testImageWinsOverText() {
        let item = ClipboardItem(date: Date(), text: "t", fileURLs: nil, imagePath: "/tmp/x.png")
        XCTAssertEqual(item.kind, .image)
    }

    func testEmptyItemIsText() {
        let item = ClipboardItem(date: Date(), text: nil, fileURLs: nil)
        XCTAssertEqual(item.kind, .text)
    }

    // MARK: - 이미지 저장

    /// PNG 바이트는 그대로 쓰고, TIFF 바이트는 같은 크기의 PNG로 바꿔 쓴다.
    func testWritePNGPassesPNGThroughAndConvertsTIFF() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumenClipboardPNG-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 12, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let tiff = try XCTUnwrap(rep.tiffRepresentation)
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))

        let fromPNG = dir.appendingPathComponent("a.png")
        XCTAssertTrue(ClipboardManager.writePNG(png, isPNG: true, to: fromPNG))
        XCTAssertEqual(try Data(contentsOf: fromPNG), png)

        let fromTIFF = dir.appendingPathComponent("b.png")
        XCTAssertTrue(ClipboardManager.writePNG(tiff, isPNG: false, to: fromTIFF))
        let loaded = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: fromTIFF)))
        XCTAssertEqual(loaded.pixelsWide, 12)
        XCTAssertEqual(loaded.pixelsHigh, 8)

        XCTAssertFalse(ClipboardManager.writePNG(Data([0, 1, 2]), isPNG: false, to: dir.appendingPathComponent("c.png")))
    }

    // MARK: - 중복 판정

    /// 이미지는 모두 "[이미지]"로 보이지만 서로 중복이 아니다. 예전에는 새 이미지가 이전 이미지를 모두 지웠다.
    func testImagesAreNeverDuplicates() {
        let first = ClipboardItem(date: Date(), text: nil, fileURLs: nil, imagePath: "/tmp/a.png")
        let second = ClipboardItem(date: Date(), text: nil, fileURLs: nil, imagePath: "/tmp/b.png")
        XCTAssertFalse(second.isDuplicate(of: first))
    }

    func testTextThatLooksLikeImageLabelIsNotAnImage() {
        let image = ClipboardItem(date: Date(), text: nil, fileURLs: nil, imagePath: "/tmp/a.png")
        let text = ClipboardItem(date: Date(), text: "[이미지]", fileURLs: nil)
        XCTAssertFalse(text.isDuplicate(of: image))
    }

    /// 텍스트는 목록에 보이는 앞 200자가 아니라 본문 전체로 비교한다.
    func testTextDuplicatesCompareWholeBody() {
        let head = String(repeating: "가", count: ClipboardItem.displayPrefixLimit)
        let a = ClipboardItem(date: Date(), text: head + "A", fileURLs: nil)
        let b = ClipboardItem(date: Date(), text: head + "B", fileURLs: nil)
        let again = ClipboardItem(date: Date(), text: head + "A", fileURLs: nil)
        XCTAssertFalse(b.isDuplicate(of: a))
        XCTAssertTrue(again.isDuplicate(of: a))
    }

    /// 파일은 이름이 아니라 경로 전체로 비교한다.
    func testFilesWithSameNameInDifferentFoldersAreNotDuplicates() {
        let a = ClipboardItem(date: Date(), text: nil, fileURLs: [URL(fileURLWithPath: "/tmp/one/a.txt")])
        let b = ClipboardItem(date: Date(), text: nil, fileURLs: [URL(fileURLWithPath: "/tmp/two/a.txt")])
        let again = ClipboardItem(date: Date(), text: nil, fileURLs: [URL(fileURLWithPath: "/tmp/one/a.txt")])
        XCTAssertFalse(b.isDuplicate(of: a))
        XCTAssertTrue(again.isDuplicate(of: a))
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
