import Foundation

/// open.er-api.com 무료 API에서 USD 기준 환율을 받아 LumenStorage에 캐싱.
/// 앱 시작 시 24시간 경과 캐시면 백그라운드 갱신, 그 외에는 캐시만으로 변환.
/// 외부 의존성(네트워크)이 죽어도 캐시가 있으면 변환은 계속 동작한다.
final class CurrencyService {
    static let shared = CurrencyService()

    /// 디스크 + 메모리에 들고 있는 가장 최근 환율 (USD 1당 X 통화).
    private(set) var rates: [String: Double] = [:]
    private(set) var lastUpdated: Date?

    private struct Cache: Codable {
        let rates: [String: Double]
        let updated: Date
    }

    private struct APIResponse: Decodable {
        let rates: [String: Double]
    }

    private init() {
        if let cached = LumenStorage.read(Cache.self, from: .currencyRates) {
            self.rates = cached.rates
            self.lastUpdated = cached.updated
        }
    }

    /// 앱 시작 시 한 번 호출. 캐시가 24시간 내면 그대로 두고, 오래됐거나 비어있으면
    /// 백그라운드 fetch. 실패해도 silent — 캐시로 계속 동작.
    func refreshIfStale() {
        if let updated = lastUpdated, Date().timeIntervalSince(updated) < 86_400 {
            return
        }
        Task.detached(priority: .background) { [weak self] in
            await self?.fetch()
        }
    }

    private func fetch() async {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let resp = try JSONDecoder().decode(APIResponse.self, from: data)
            await MainActor.run {
                self.rates = resp.rates
                self.lastUpdated = Date()
                LumenStorage.write(Cache(rates: resp.rates, updated: Date()), to: .currencyRates)
            }
        } catch {
            // 캐시가 있으면 그걸 쓰고, 없으면 다음 refresh까지 변환은 비활성.
        }
    }

    /// USD를 base로 한 환율 테이블에서 from→to 변환.
    func convert(amount: Double, from: String, to: String) -> Double? {
        let f = from.uppercased()
        let t = to.uppercased()
        if f == t { return amount }
        guard let fromRate = (f == "USD") ? 1.0 : rates[f],
              let toRate   = (t == "USD") ? 1.0 : rates[t] else { return nil }
        return amount / fromRate * toRate
    }
}

// MARK: - Query parser

/// Search 입력에서 "100 usd", "5만원", "$100" 같은 패턴을 골라낸다.
/// 대상 통화는 입력에 명시된 통화의 "반대편"으로 자동 결정 — USD↔KRW, EUR/JPY는 KRW 기준.
enum CurrencyQuery {
    struct Match {
        let amount: Double
        let from: String
        let to: String
    }

    /// Search 한 줄 입력을 받아 Match 또는 nil. nil이면 환율 결과 행 비표시.
    static func parse(_ raw: String) -> Match? {
        let q = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return nil }

        // 명시 통화 추출 — symbol/code/한국어 별칭 모두 수용.
        let aliases: [(token: String, code: String)] = [
            ("$", "USD"), ("usd", "USD"), ("dollar", "USD"), ("달러", "USD"),
            ("₩", "KRW"), ("krw", "KRW"), ("won", "KRW"), ("원", "KRW"),
            ("€", "EUR"), ("eur", "EUR"), ("euro", "EUR"), ("유로", "EUR"),
            ("¥", "JPY"), ("jpy", "JPY"), ("yen", "JPY"), ("엔", "JPY"),
        ]

        // 가장 길게 매칭되는 alias부터 시도 (예: "달러"가 "$"보다 우선).
        let sorted = aliases.sorted { $0.token.count > $1.token.count }
        guard let hit = sorted.first(where: { q.contains($0.token) }) else { return nil }

        // alias 토큰을 제거해서 숫자 부분만 남기고, 한글 단위 (`만`, `천`) 처리.
        var numberPart = q.replacingOccurrences(of: hit.token, with: " ")
        numberPart = numberPart.replacingOccurrences(of: ",", with: "")

        guard let amount = parseAmount(numberPart) else { return nil }

        let to = hit.code == "KRW" ? "USD" : "KRW"
        return Match(amount: amount, from: hit.code, to: to)
    }

    /// "5만", "100", "1.5천" 같은 표현을 Double로. 한글 단위는 만/천만 지원.
    private static func parseAmount(_ raw: String) -> Double? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }

        // "5만", "5만원" 같은 패턴 — 숫자 + 만/천
        if let manRange = s.range(of: "만") {
            let head = String(s[..<manRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            guard let n = Double(head) else { return nil }
            return n * 10_000
        }
        if let chunRange = s.range(of: "천") {
            let head = String(s[..<chunRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            guard let n = Double(head) else { return nil }
            return n * 1_000
        }
        return Double(s)
    }
}
