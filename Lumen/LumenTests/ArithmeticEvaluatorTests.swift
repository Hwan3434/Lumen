import XCTest
@testable import Lumen

/// 검색창 계산기. 핵심은 "미완성 입력에서 죽지 않는다"는 것 —
/// 예전 구현(`NSExpression(format:)`)은 잡을 수 없는 ObjC 예외를 raise했고,
/// 검색창은 키 입력마다 평가하므로 계산식을 치는 동안 매번 그 예외를 맞았다.
final class ArithmeticEvaluatorTests: XCTestCase {

    /// 식을 타이핑하며 거치는 모든 중간 상태. 하나라도 죽으면 안 된다.
    func testEveryPrefixOfAnExpressionIsSafe() {
        let targets = [("5 * (3+2)", "25"), ("-2^3^2 + 200*15%", "-482"), ("(10+10)%^2", "0.04")]
        for (target, expected) in targets {
            for length in 1...target.count {
                let prefix = String(target.prefix(length))
                // 죽지 않고 값 아니면 nil을 돌려주는 것 자체가 이 테스트의 목적.
                _ = ArithmeticEvaluator.evaluate(prefix)
            }
            assertCases([(target, expected)])
        }
    }

    /// `^`는 오른쪽부터 묶고 단항 부호보다 먼저 계산한다 — Python `**`와 같은 해석.
    func testPowerOperator() {
        assertCases([
            ("2^10", "1024"),
            ("2^0", "1"),
            ("2^-1", "0.5"),
            ("0^0", "1"),        // IEEE `pow`·Python과 같이 1
            ("2^3^2", "512"),    // 2^(3^2)
            ("-2^2", "-4"),      // -(2^2)
            ("(-2)^2", "4"),
            ("2*3^2", "18"),     // 곱셈보다 먼저
        ])
    }

    /// Double이 정확히 담는 2^53 미만 정수는 자릿수를 다 쓰고, 그보다 크면 유효숫자 15자리 지수 표기다.
    func testLargeIntegersKeepAllDigits() {
        assertCases([
            ("1234567890123456+1", "1234567890123457"),
            ("10^15", "1000000000000000"),
            ("2^64", "1.84467440737096e+19"),
        ])
    }

    /// Double의 음의 0이 결과에 `-0`으로 나오지 않는다.
    func testNegativeZeroIsShownAsZero() {
        assertCases([
            ("-0%", "0"),
            ("0*-1", "0"),
        ])
    }

    /// 너무 긴 숫자는 무한대로 읽혀 `1/무한대` = 0 같은 결과를 만든다. 계산식으로 받지 않는다.
    func testOverflowingLiteralReturnsNil() {
        let huge = "1" + String(repeating: "0", count: 400)
        assertCases([
            ("1/" + huge, nil),
            (huge + "^0", nil),
        ])
    }

    /// 피연산자가 빠졌거나 결과가 무한대·숫자 아님(NaN)이면 계산 결과가 없다.
    func testIncompleteOrNonFinitePowerReturnsNil() {
        assertCases([
            ("2^", nil),
            ("^2", nil),
            ("10^400", nil),          // 무한대
            ("0^-1", nil),            // 무한대
            ("(-8)^(1/3)", nil),      // NaN
            ("1/10^400", nil),        // 중간에 무한대가 나오면 식 전체가 결과 없음
            ("10^400-10^400", nil),
        ])
    }

    /// `%`는 바로 앞의 숫자나 괄호를 100으로 나누는 후위 연산이다. 나머지 연산이 아니다.
    func testPercentOperator() {
        assertCases([
            ("50%", "0.5"),
            ("200*15%", "30"),
            ("(10+10)%", "0.2"),
            ("100*7%", "7"),
            ("100+10%", "100.1"),  // 휴대폰 계산기의 110이 아니라 10%를 0.1로 읽는다
            ("-50%", "-0.5"),
            ("5%%", "0.0005"),     // 붙일 때마다 100으로 나눈다
            ("4^50%", "2"),        // 4^(0.5) — %가 ^보다 먼저
            ("50%^2", "0.25"),
            ("1,000%", "10"),
        ])
    }

    func testMalformedPercentReturnsNil() {
        assertCases([
            ("%5", nil),
            ("%", nil),
            ("50%3", nil),    // 나머지 연산도, 생략된 곱셈도 아니다
            ("50%(3)", nil),
            ("(%)", nil),
        ])
    }

    /// 이진 부동소수 오차가 결과에 꼬리로 붙지 않는다.
    func testFloatingPointNoiseIsHidden() {
        assertCases([
            ("0.1+0.2", "0.3"),
            ("3*7%", "0.21"),
            ("1/3", "0.333333333333333"),
        ])
    }

    /// 예전 구현을 터뜨렸던 입력들.
    func testMalformedInputReturnsNil() {
        let malformed = ["1+", "1-", "1*", "1/", "3.14+", "()+1", "1+2)",
                         "5 * (", "5 * (3+", "(", ")", "+", "1..2+1", "1.2.3+1"]
        for input in malformed {
            XCTAssertNil(ArithmeticEvaluator.evaluate(input), "\"\(input)\"는 nil이어야 한다")
        }
    }

    /// 연산자 뒤에 오는 +/-는 단항으로 읽는다 — C·Swift·Python과 같은 해석.
    func testUnarySignAfterOperator() {
        XCTAssertEqual(ArithmeticEvaluator.evaluate("1++2"), "3")
        XCTAssertEqual(ArithmeticEvaluator.evaluate("1--2"), "3")
        XCTAssertEqual(ArithmeticEvaluator.evaluate("2*-3"), "-6")
    }

    func testValidExpressions() {
        XCTAssertEqual(ArithmeticEvaluator.evaluate("1+2"), "3")
        XCTAssertEqual(ArithmeticEvaluator.evaluate("10 / 4"), "2.5")
        XCTAssertEqual(ArithmeticEvaluator.evaluate("2*3+4"), "10")
        XCTAssertEqual(ArithmeticEvaluator.evaluate("2+3*4"), "14", "곱셈이 먼저")
        XCTAssertEqual(ArithmeticEvaluator.evaluate("(2+3)*4"), "20", "괄호가 우선")
        XCTAssertEqual(ArithmeticEvaluator.evaluate("-5+3"), "-2", "단항 마이너스")
        XCTAssertEqual(ArithmeticEvaluator.evaluate("1,000+500"), "1500", "천단위 콤마 허용")
        XCTAssertEqual(ArithmeticEvaluator.evaluate("6×7"), "42")
        XCTAssertEqual(ArithmeticEvaluator.evaluate("84÷2"), "42")
    }

    /// 계산식이 아닌 검색어가 계산 결과로 둔갑하면 안 된다.
    func testNonExpressionsReturnNil() {
        for input in ["", "   ", "safari", "42", "3.14", "note-1", "FUNCTION(1,'log:')", "1e5+1"] {
            XCTAssertNil(ArithmeticEvaluator.evaluate(input), "\"\(input)\"는 계산식이 아니다")
        }
    }

    func testDivisionByZeroIsNotAResult() {
        XCTAssertNil(ArithmeticEvaluator.evaluate("1/0"))
        XCTAssertNil(ArithmeticEvaluator.evaluate("5/(3-3)"))
    }

    /// 검색 뷰모델을 통해서도 같은 보장 — didSet이 키 입력마다 평가를 부른다.
    @MainActor
    func testSearchViewModelSurvivesPartialExpression() {
        let vm = SearchViewModel()
        for query in ["1", "1+", "1+2", "5 * (", "5 * (3+2)"] {
            vm.query = query
        }
        XCTAssertTrue(vm.results.contains { item in
            if case .calculation(_, let result) = item { return result == "25" }
            return false
        }, "완성된 식은 계산 결과 행으로 나와야 한다")
    }

    @MainActor
    func testSearchViewModelShowsPowerAndPercent() {
        let vm = SearchViewModel()
        for (query, expected) in [("2^10", "1024"), ("200*15%", "30")] {
            vm.query = query
            let actual = vm.results.compactMap { item -> String? in
                if case .calculation(_, let result) = item { return result }
                return nil
            }.first
            print("[calc] SearchViewModel \"\(query)\" expected=\(expected) actual=\(actual ?? "nil")")
            XCTAssertEqual(actual, expected, "\"\(query)\"는 계산 결과 행으로 나와야 한다")
        }
    }

    // MARK: - Helpers

    /// 경우마다 기대값과 실제값을 출력해 테스트 로그만으로 값을 확인할 수 있게 한다.
    private func assertCases(_ cases: [(String, String?)], line: UInt = #line) {
        for (input, expected) in cases {
            let actual = ArithmeticEvaluator.evaluate(input)
            print("[calc] \"\(input)\" expected=\(expected ?? "nil") actual=\(actual ?? "nil")")
            XCTAssertEqual(actual, expected, "\"\(input)\"", line: line)
        }
    }
}
