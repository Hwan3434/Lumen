import XCTest
@testable import Lumen

/// 임시 폴더를 앱 폴더로 삼아 폴더 감시와 캐시 무효화를 확인한다.
final class AppIndexerTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppIndexerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeApp(_ name: String) throws {
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("\(name).app"), withIntermediateDirectories: true
        )
    }

    @MainActor
    func testAddedAndRemovedAppsAreReflectedAfterChange() throws {
        let indexer = AppIndexer(directories: [dir])
        XCTAssertFalse(indexer.loadApps().contains { $0.name == "FakeApp" })

        var changed = expectation(description: "added")
        indexer.startWatching(debounce: 0.2) { changed.fulfill() }

        try makeApp("FakeApp")
        wait(for: [changed], timeout: 5)
        XCTAssertTrue(indexer.loadApps().contains { $0.name == "FakeApp" })

        changed = expectation(description: "removed")
        try FileManager.default.removeItem(at: dir.appendingPathComponent("FakeApp.app"))
        wait(for: [changed], timeout: 5)
        XCTAssertFalse(indexer.loadApps().contains { $0.name == "FakeApp" })
    }

    /// 연달아 바뀌어도 알림은 한 번만 온다.
    @MainActor
    func testBurstOfChangesIsDebounced() throws {
        let indexer = AppIndexer(directories: [dir])
        var count = 0
        indexer.startWatching(debounce: 0.5) { count += 1 }

        for i in 0..<5 { try makeApp("Burst\(i)") }

        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { settled.fulfill() }
        wait(for: [settled], timeout: 5)

        XCTAssertEqual(count, 1)
        XCTAssertEqual(indexer.loadApps().filter { $0.name.hasPrefix("Burst") }.count, 5)
    }
}
