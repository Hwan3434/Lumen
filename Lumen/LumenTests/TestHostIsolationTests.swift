import XCTest
@testable import Lumen

/// 테스트 호스트는 실제 앱이다. 테스트로 뜰 때 앱 시작 작업(기능 등록, 단축키, 클립보드 기록,
/// 클램쉘 모드 복구)이 돌면 설치된 Lumen의 상태를 건드리므로, `AppDelegate`가 건너뛰는지 확인한다.
final class TestHostIsolationTests: XCTestCase {
    func testAppStartupIsSkippedUnderTests() {
        XCTAssertTrue(FeatureRegistry.shared.enabledFeatures.isEmpty)
    }
}
