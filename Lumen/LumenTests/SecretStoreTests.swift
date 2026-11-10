import XCTest
@testable import Lumen

final class SecretStoreTests: XCTestCase {
    private var dir: URL!
    private var url: URL { dir.appendingPathComponent("secrets.dat") }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testRoundTripAndDelete() {
        XCTAssertNil(SecretStore.read("a", at: url))
        XCTAssertTrue(SecretStore.write("token-1", for: "a", at: url))
        XCTAssertTrue(SecretStore.write("token-2", for: "b", at: url))
        XCTAssertEqual(SecretStore.read("a", at: url), "token-1")
        XCTAssertTrue(SecretStore.delete("a", at: url))
        XCTAssertNil(SecretStore.read("a", at: url))
        XCTAssertEqual(SecretStore.read("b", at: url), "token-2")
    }

    /// 풀지 못하는 파일(키가 바뀐 경우)에 쓰면 빈 사전으로 덮어쓰지 않고 원본을 옆에 남긴다.
    func testWriteOverUndecodableFileKeepsBackup() throws {
        let original = Data("not decodable with this key".utf8)
        try original.write(to: url)

        XCTAssertNil(SecretStore.read("a", at: url))
        XCTAssertTrue(SecretStore.write("token", for: "a", at: url))

        XCTAssertEqual(SecretStore.read("a", at: url), "token")
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix("secrets.dat.bak-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(backups[0])), original)
    }

    /// 지우기(빈 값 쓰기 포함)는 풀지 못하는 파일을 옮기지도 덮어쓰지도 않는다.
    func testDeleteLeavesUndecodableFileAlone() throws {
        let original = Data("not decodable with this key".utf8)
        try original.write(to: url)

        XCTAssertTrue(SecretStore.delete("a", at: url))
        XCTAssertTrue(SecretStore.write("", for: "a", at: url))

        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path), ["secrets.dat"])
    }
}
