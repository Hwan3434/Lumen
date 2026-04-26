import Foundation
import os

/// 앱 전체에서 쓰는 얇은 os.Logger 래퍼.
/// `try? LumenLog.x("...")` 처럼 try? 사이트에서 에러를 삼킬 때 최소한
/// console에 흔적이라도 남기기 위해 사용한다. 사용자에게 노출하지 않는
/// 진단용 — 사용자에게 보여줄 에러는 ErrorTone UI로 별도 처리.
enum LumenLog {
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let ui      = Logger(subsystem: subsystem, category: "ui")
    static let feature = Logger(subsystem: subsystem, category: "feature")

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.jh.Lumen"

    /// `try?`로 삼킨 에러를 로깅하면서 nil을 돌려준다.
    /// 사용 패턴:
    ///   `let data = LumenLog.swallow(LumenLog.storage, "load translation history") { try Data(contentsOf: url) }`
    static func swallow<T>(_ logger: Logger, _ context: String,
                           _ body: () throws -> T) -> T? {
        do {
            return try body()
        } catch {
            logger.error("\(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
