import XCTest
@testable import Lumen

final class LumenStorageTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testMissingFileReadsNilWithoutBackup() throws {
        let url = dir.appendingPathComponent("items.json")
        XCTAssertNil(LumenStorage.read([String].self, from: url))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }

    /// 풀지 못한 파일은 다음 저장에 덮이지 않도록 옆으로 옮겨 둔다.
    func testUndecodableFileIsMovedAside() throws {
        let url = dir.appendingPathComponent("items.json")
        let original = Data("{\"not\": \"an array\"}".utf8)
        try original.write(to: url)

        XCTAssertNil(LumenStorage.read([String].self, from: url))
        LumenStorage.write(["new"], to: url)

        XCTAssertEqual(LumenStorage.read([String].self, from: url), ["new"])
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix("items.json.bak-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(backups[0])), original)
    }
}
