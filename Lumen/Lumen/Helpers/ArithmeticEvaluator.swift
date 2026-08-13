import Foundation

/// 검색창의 사칙연산 평가기.
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
/// unary      := ('+' | '-')* primary
/// primary    := number | '(' expression ')'
/// ```
enum ArithmeticEvaluator {

    /// 계산식을 평가한다. 계산식이 아니거나 형태가 온전치 않으면 nil.
    /// 연산자가 하나도 없는 순수 숫자(`"42"`)도 nil — 검색어를 계산 결과로 오인하지 않기 위함.
    static func evaluate(_ input: String) -> String? {
        let normalized = input
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: ",", with: "")

        guard var tokens = tokenize(normalized) else { return nil }
        // 연산자 없이 숫자만 있는 입력은 계산식으로 취급하지 않는다.
        guard tokens.contains(where: { if case .op = $0 { return true } else { return false } }) else {
            return nil
        }

        var parser = Parser(tokens: tokens)
        guard let value = parser.parseExpression(), parser.isAtEnd else { return nil }
        guard value.isFinite else { return nil }

        tokens.removeAll()
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
                guard let value = Double(literal) else { return nil }
                tokens.append(.number(value))
                continue
            }

            switch ch {
            case "+", "-", "*", "/": tokens.append(.op(ch))
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
            return parsePrimary()
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

    private static func format(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(format: "%.0f", value)
        }
        return String(value)
    }
}
