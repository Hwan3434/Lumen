import Foundation

nonisolated enum DateParsers {
    static let iso8601Full: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static let ymd: DateFormatter = {
        let f = DateFormatter()
        // 고정 형식은 POSIX 로케일로 읽는다. 시스템 달력이 그레고리력이 아니면 연도가 틀어진다.
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parseISO8601(_ ts: String) -> Date? {
        iso8601Full.date(from: ts) ?? iso8601Basic.date(from: ts)
    }
}
