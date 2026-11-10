import XCTest
@testable import Lumen

/// 검색창의 순수 로직: 앱 순위, 기능 검색, 환율 환산과 표기.
/// 실제 실행 횟수·환율 파일·기능 등록부(`shared`)는 쓰지 않는다.
@MainActor
final class SearchLogicTests: XCTestCase {

    private func app(_ name: String, aliases: [String] = []) -> AppItem {
        AppItem(id: "test.\(name)", name: name, path: URL(fileURLWithPath: "/Applications/\(name).app"), aliases: aliases)
    }

    private func ranked(_ apps: [AppItem], query: String, usage: [String: Int] = [:]) -> [String] {
        SearchViewModel.rankedApps(apps, query: query) { usage[$0] ?? 0 }.map(\.name)
    }

    // MARK: - 앱 순위

    func testEmptyQueryReturnsAllAppsByName() {
        XCTAssertEqual(ranked([app("Notes"), app("Calendar"), app("Mail")], query: ""), ["Calendar", "Mail", "Notes"])
    }

    func testQueryMatchesNameOrAliasIgnoringCase() {
        let apps = [app("Notes"), app("System Settings", aliases: ["시스템 설정"]), app("Mail")]
        XCTAssertEqual(ranked(apps, query: "NOT"), ["Notes"])
        XCTAssertEqual(ranked(apps, query: "시스템"), ["System Settings"])
    }

    func testPrefixMatchComesFirstWhenUsageIsEqual() {
        let apps = [app("Keynote"), app("Notes")]
        XCTAssertEqual(ranked(apps, query: "no"), ["Notes", "Keynote"])
    }

    /// 지금 규칙을 고정한다: 실행 횟수가 이름 앞부분 일치보다 먼저다. 이 순서를 바꿀지는 따로 정할 일이다.
    func testCurrentRuleUsageCountOutranksPrefixMatch() {
        let apps = [app("Keynote"), app("Notes")]
        XCTAssertEqual(ranked(apps, query: "no", usage: ["test.Keynote": 3]), ["Keynote", "Notes"])
    }

    // MARK: - 기능 검색

    private final class FakeFeature: BuiltInFeature {
        let name: String
        let featureDescription = ""
        let iconName = "star"
        let searchKeywords: [String]
        init(name: String, keywords: [String]) { self.name = name; self.searchKeywords = keywords }
        func activate() {}
    }

    private func registry() -> FeatureRegistry {
        let registry = FeatureRegistry()
        registry.register(FakeFeature(name: "클립보드", keywords: ["clipboard", "복사"]))
        registry.register(FakeFeature(name: "메모", keywords: ["note", "memo"]))
        return registry
    }

    func testFeatureSearchWithEmptyQueryReturnsAll() {
        XCTAssertEqual(registry().search(query: "").map(\.name), ["클립보드", "메모"])
    }

    func testFeatureSearchMatchesNameAndKeywordIgnoringCase() {
        XCTAssertEqual(registry().search(query: "메").map(\.name), ["메모"])
        XCTAssertEqual(registry().search(query: "CLIP").map(\.name), ["클립보드"])
    }

    func testFeatureSearchWithoutMatchIsEmpty() {
        XCTAssertTrue(registry().search(query: "zzz").isEmpty)
    }

    // MARK: - 환율

    private let rates = ["KRW": 1400.0, "EUR": 0.5]

    func testConvertGoesThroughUSD() throws {
        XCTAssertEqual(CurrencyService.convert(amount: 2, from: "usd", to: "KRW", rates: rates), 2800)
        XCTAssertEqual(CurrencyService.convert(amount: 1400, from: "KRW", to: "USD", rates: rates), 1)
        let eurToKrw = try XCTUnwrap(CurrencyService.convert(amount: 1, from: "EUR", to: "KRW", rates: rates))
        XCTAssertEqual(eurToKrw, 2800, accuracy: 0.0001)
    }

    func testConvertSameCurrencyAndUnknownCurrency() {
        XCTAssertEqual(CurrencyService.convert(amount: 5, from: "JPY", to: "jpy", rates: [:]), 5)
        XCTAssertNil(CurrencyService.convert(amount: 5, from: "JPY", to: "KRW", rates: rates))
    }

    /// 원·엔은 정수, 그 밖은 소수 둘째 자리까지.
    func testFormatUsesWholeNumbersForWonAndYen() {
        XCTAssertEqual(CurrencyService.format(1234.4, code: "KRW"), "1,234")
        XCTAssertEqual(CurrencyService.format(1234.4, code: "JPY"), "1,234")
        XCTAssertEqual(CurrencyService.format(1234.567, code: "USD"), "1,234.57")
        XCTAssertEqual(CurrencyService.format(12, code: "USD"), "12")
    }
}
