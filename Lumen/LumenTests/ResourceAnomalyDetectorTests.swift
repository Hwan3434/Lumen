import XCTest
@testable import Lumen

/// 리소스 이상 감지 규칙. 감지 결과는 테스트가 넘긴 배열에만 쌓인다(실제 저장소는 쓰지 않는다).
@MainActor
final class ResourceAnomalyDetectorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private var found: [ResourceAnomaly] = []
    private var detector: ResourceAnomalyDetector!

    override func setUp() async throws {
        found = []
        detector = ResourceAnomalyDetector(startTime: start) { [unowned self] in self.found.append($0) }
    }

    private func ingest(after seconds: TimeInterval, memory: Double = 100, cpu: Double = 0, threads: Int = 10) {
        detector.ingest(ResourceSnapshot(timestamp: start.addingTimeInterval(seconds),
                                         memoryMB: memory, cpuPercent: cpu, threadCount: threads))
    }

    private var kinds: [ResourceAnomaly.Kind] { found.map(\.kind) }

    /// 6회 연속 넘어야 알리고, 내려갔다 다시 6회 넘기 전에는 또 알리지 않는다.
    func testCPUSustainedNeedsSixSamplesInARowAndAlertsOncePerStreak() {
        let high = ResourceAnomalyDetector.cpuHighThreshold + 1
        for i in 0..<5 { ingest(after: Double(i), cpu: high) }
        XCTAssertTrue(found.isEmpty)
        ingest(after: 5, cpu: high)
        XCTAssertEqual(kinds, [.cpuSustained])
        ingest(after: 6, cpu: high)
        XCTAssertEqual(kinds, [.cpuSustained])

        ingest(after: 7, cpu: 0)
        for i in 0..<6 { ingest(after: 8 + Double(i), cpu: high) }
        XCTAssertEqual(kinds, [.cpuSustained, .cpuSustained])
    }

    func testMemoryThresholdsFireOnceEach() {
        ingest(after: 1, memory: 480)
        ingest(after: 2, memory: 510)
        ingest(after: 3, memory: 520)
        XCTAssertEqual(kinds, [.memoryHigh])
        ingest(after: 4, memory: 1030)
        XCTAssertEqual(kinds.filter { $0 == .memoryHigh }.count, 2)
    }

    /// 기준값은 시작 60초 뒤의 측정으로 잡는다. 그 전에는 증가를 알리지 않는다.
    func testGrowthRulesWaitForBaseline() {
        ingest(after: 10, memory: 100, threads: 10)
        ingest(after: 20, memory: 140, threads: 30)
        XCTAssertTrue(found.isEmpty)

        ingest(after: 61, memory: 140, threads: 30)   // 기준값: 140MB, 스레드 30
        ingest(after: 66, memory: 170, threads: 59)
        XCTAssertTrue(found.isEmpty)
        ingest(after: 71, memory: 211, threads: 60)
        XCTAssertEqual(Set(kinds), [.memoryGrowth, .threadGrowth])
    }

    /// 직전 측정보다 50MB 이상이면서 25% 이상 늘어야 점프로 본다.
    func testMemorySpikeNeedsBothAbsoluteAndRelativeJump() {
        ingest(after: 1, memory: 100)
        ingest(after: 2, memory: 140)   // +40MB
        ingest(after: 3, memory: 300)   // +160MB, 2.1배
        ingest(after: 4, memory: 360)   // +60MB, 1.2배
        XCTAssertEqual(kinds, [.memorySpike])
    }
}
