import Foundation

/// 검색창의 계산식 평가기. 사칙연산, 거듭제곱(`^`), 퍼센트(`%`)를 받는다.
///
/// `NSExpression(format:)`을 쓰지 않는 이유: 파싱에 실패하면 Swift에서 잡을 수 없는
/// ObjC 예외(`NSInvalidArgumentException`)를 raise한다. `try?`는 throwing 함수가 아니라
/// 아무것도 잡아주지 못한다. 검색창은 키 입력마다 평가하므로 `5 * (3+2)`를 치는 동안
/// `5 *`, `5 * (`, `5 * (3+` 같은 미완성 문자열이 전부 평가되고, 그때마다 예외가
/// SwiftUI 업데이트 한복판을 뚫고 나간다.
///
/// 그래서 예외를 던질 수 없는 재귀하강 파서를 직접 둔다. 어떤 입력이 들어와도
/// 결과 아니면 nil이다.
///
/// 문법:
/// ```
/// expression := term (('+' | '-') term)*
/// term       := unary (('*' | '/') unary)*
/// unary      := ('+' | '-') unary | power
/// power      := postfix ('^' unary)?
/// postfix    := primary '%'*
/// primary    := number | '(' expression ')'
/// ```
/// - `^`는 오른쪽부터 묶고 단항 부호보다 먼저 계산한다(`2^3^2` = 512, `-2^2` = -4, `2^-1` = 0.5).
///   Python `**`와 같은 해석이다.
/// - `%`는 바로 앞의 숫자나 괄호를 100으로 나눈다(`200*15%` = 30, `5%%` = 0.0005).
///   나머지 연산이 아니고, 휴대폰 계산기처럼 `100+10%`를 110으로 읽지도 않는다(100.1).
enum ArithmeticEvaluator {

    /// 계산식을 평가한다. 계산식이 아니거나 형태가 온전치 않으면 nil.
    /// 연산자가 하나도 없는 순수 숫자(`"42"`)도 nil — 검색어를 계산 결과로 오인하지 않기 위함.
    static func evaluate(_ input: String) -> String? {
        let normalized = input
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: ",", with: "")

        guard let tokens = tokenize(normalized) else { return nil }
        // 연산자 없이 숫자만 있는 입력은 계산식으로 취급하지 않는다.
        guard tokens.contains(where: { if case .op = $0 { return true } else { return false } }) else {
            return nil
        }

        var parser = Parser(tokens: tokens)
        guard let value = parser.parseExpression(), parser.isAtEnd else { return nil }
        guard value.isFinite else { return nil }

        return format(value)
    }

    // MARK: - Tokenizer

    private enum Token: Equatable {
        case number(Double)
        case op(Character)
        case leftParen
        case rightParen
    }

    /// 허용된 문자만 받아들인다. 알파벳이 하나라도 섞이면 nil —
    /// 이 가드가 `FUNCTION(...)` 같은 표현이 파서에 닿지 않게 막는 역할도 겸한다.
    private static func tokenize(_ s: String) -> [Token]? {
        var tokens: [Token] = []
        var index = s.startIndex

        while index < s.endIndex {
            let ch = s[index]

            if ch == " " {
                index = s.index(after: index)
                continue
            }

            if ch.isNumber || ch == "." {
                var literal = ""
                var sawDot = false
                while index < s.endIndex, s[index].isNumber || s[index] == "." {
                    if s[index] == "." {
                        // "1.2.3" 같은 입력은 여기서 거른다.
                        if sawDot { return nil }
                        sawDot = true
                    }
                    literal.append(s[index])
                    index = s.index(after: index)
                }
                // 309자리가 넘는 숫자는 무한대로 읽힌다. 받으면 `1/무한대` = 0 같은 결과가 나온다.
                guard let value = Double(literal), value.isFinite else { return nil }
                tokens.append(.number(value))
                continue
            }

            switch ch {
            case "+", "-", "*", "/", "^", "%": tokens.append(.op(ch))
            case "(":                tokens.append(.leftParen)
            case ")":                tokens.append(.rightParen)
            default:                 return nil
            }
            index = s.index(after: index)
        }

        return tokens.isEmpty ? nil : tokens
    }

    // MARK: - Parser

    private struct Parser {
        let tokens: [Token]
        var position = 0

        var isAtEnd: Bool { position >= tokens.count }

        private func peek() -> Token? {
            position < tokens.count ? tokens[position] : nil
        }

        mutating func parseExpression() -> Double? {
            guard var left = parseTerm() else { return nil }
            while case .op(let symbol)? = peek(), symbol == "+" || symbol == "-" {
                position += 1
                guard let right = parseTerm() else { return nil }
                left = (symbol == "+") ? left + right : left - right
            }
            return left
        }

        private mutating func parseTerm() -> Double? {
            guard var left = parseUnary() else { return nil }
            while case .op(let symbol)? = peek(), symbol == "*" || symbol == "/" {
                position += 1
                guard let right = parseUnary() else { return nil }
                if symbol == "/" {
                    // 0으로 나누면 inf/nan이 되므로 계산식이 아니었던 것으로 취급한다.
                    guard right != 0 else { return nil }
                    left /= right
                } else {
                    left *= right
                }
            }
            return left
        }

        private mutating func parseUnary() -> Double? {
            if case .op(let symbol)? = peek(), symbol == "+" || symbol == "-" {
                position += 1
                guard let operand = parseUnary() else { return nil }
                return symbol == "-" ? -operand : operand
            }
            return parsePower()
        }

        /// 지수 자리에서 `parseUnary`를 다시 불러 오른쪽부터 묶고 `2^-1`의 부호도 받는다.
        private mutating func parsePower() -> Double? {
            guard let base = parsePostfix() else { return nil }
            guard case .op(let symbol)? = peek(), symbol == "^" else { return base }
            position += 1
            guard let exponent = parseUnary() else { return nil }
            let value = pow(base, exponent)
            // 넘치거나(`10^400`) 실수가 아니면(`(-8)^(1/3)`) 계산식이 아니었던 것으로 취급한다.
            // 여기서 끊지 않으면 `1/10^400`처럼 무한대를 거쳐 0이 결과로 나온다.
            return value.isFinite ? value : nil
        }

        private mutating func parsePostfix() -> Double? {
            guard var value = parsePrimary() else { return nil }
            while case .op(let symbol)? = peek(), symbol == "%" {
                position += 1
                value /= 100
            }
            return value
        }

        private mutating func parsePrimary() -> Double? {
            switch peek() {
            case .number(let value):
                position += 1
                return value
            case .leftParen:
                position += 1
                guard let inner = parseExpression() else { return nil }
                guard case .rightParen? = peek() else { return nil }  // 짝이 안 맞는 괄호
                position += 1
                return inner
            default:
                // 피연산자가 와야 할 자리가 비었다 — "1+" 같은 미완성 입력이 여기로 온다.
                return nil
            }
        }
    }

    // MARK: - Formatting

    /// 2^53 미만의 정수는 Double이 정확히 담으므로 자릿수를 다 쓴다(`10^15` = 1000000000000000).
    /// 그 밖의 수는 유효숫자 15자리로 쓴다. Double은 십진 15자리까지 그대로 담으므로 이진 부동소수 오차
    /// (`0.1+0.2` = 0.30000000000000004, `100*7%` = 7.000000000000001)가 꼬리로 붙지 않는다.
    private static func format(_ value: Double) -> String {
        if value == 0 { return "0" }  // 음의 0(`0*-1`)이 `-0`으로 나오지 않게
        if value == value.rounded() && abs(value) < 9_007_199_254_740_992 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.15g", value)
    }
}
