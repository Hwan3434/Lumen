import XCTest
@testable import Lumen

/// 클램쉘 모드의 순수 로직. 실제 `pmset`/`sudo` 실행은 root·실기기가 필요해 여기서 다루지 않는다.
final class SleepPolicyServiceTests: XCTestCase {

    func testParsesSleepDisabledFromPmsetOutput() {
        let on = """
        System-wide power settings:
         SleepDisabled\t\t1
        Currently in use:
         sleep                1
        """
        XCTAssertTrue(SleepPolicyService.parseSleepDisabled(on))

        let off = on.replacingOccurrences(of: "SleepDisabled\t\t1", with: "SleepDisabled\t\t0")
        XCTAssertFalse(SleepPolicyService.parseSleepDisabled(off))
    }

    /// 줄이 아예 없으면 기본값(잠자기 허용)으로 본다.
    func testMissingSleepDisabledLineMeansSleepAllowed() {
        XCTAssertFalse(SleepPolicyService.parseSleepDisabled("Currently in use:\n sleep 1\n"))
    }

    /// 규칙은 정확히 pmset 세 명령만 허용해야 한다.
    func testSudoersRuleAllowsOnlyThreePmsetCommands() throws {
        let lines = try XCTUnwrap(SleepPolicyService.sudoersRule(for: "jane.doe"))
        let rule = try XCTUnwrap(lines.first { !$0.hasPrefix("#") })
        XCTAssertEqual(
            rule,
            "jane.doe ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset sleepnow"
        )
        XCTAssertTrue(lines.allSatisfy { $0.allSatisfy(\.isASCII) }, "sudoers 파일은 ASCII만 쓴다")
    }

    /// sudoers 문법을 깨거나 다른 규칙을 끼워 넣을 수 있는 이름은 거부한다.
    func testRejectsUnsafeUserNames() {
        for name in ["", "-x", ".hidden", "a b", "a,b", "a\nALL ALL=(ALL) NOPASSWD: ALL", "a'b", "한글", "%admin"] {
            XCTAssertNil(SleepPolicyService.sudoersRule(for: name), "\"\(name)\"은 거부해야 한다")
        }
    }
}
