import XCTest
@testable import Lumen

/// 검색창 계산기. 핵심은 "미완성 입력에서 죽지 않는다"는 것 —
/// 예전 구현(`NSExpression(format:)`)은 잡을 수 없는 ObjC 예외를 raise했고,
/// 검색창은 키 입력마다 평가하므로 계산식을 치는 동안 매번 그 예외를 맞았다.
final class ArithmeticEvaluatorTests: XCTestCase {

    /// `5 * (3+2)`를 타이핑하며 거치는 모든 중간 상태. 하나라도 죽으면 안 된다.
    func testEveryPrefixOfAnExpressionIsSafe() {
        let target = "5 * (3+2)"
        for length in 1...target.count {
            let prefix = String(target.prefix(length))
            // 죽지 않고 값 아니면 nil을 돌려주는 것 자체가 이 테스트의 목적.
            _ = ArithmeticEvaluator.evaluate(prefix)
        }
        XCTAssertEqual(ArithmeticEvaluator.evaluate(target), "25")
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
}
