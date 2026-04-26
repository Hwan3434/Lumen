import Foundation

/// Application Support/Lumen 디렉터리에 대한 단일 진입점.
/// Feature가 직접 경로를 만들지 않고 이 namespace를 통과하게 해서
/// 마이그레이션·purge·로깅이 한 곳에 모이도록 한다.
enum LumenStorage {
    /// `~/Library/Application Support/Lumen` — 첫 접근 시 디렉터리가 없으면 생성.
    static let baseURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Lumen", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// `~/Library/Logs/Lumen` — 진단 로그 (메모리 trace 등).
    static let logsURL: URL = {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let dir = library.appendingPathComponent("Logs/Lumen", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// 베이스 디렉터리 안의 하위 path 헬퍼. 디렉터리 component면 자동 mkdir.
    static func url(for relative: String, isDirectory: Bool = false) -> URL {
        let url = baseURL.appendingPathComponent(relative, isDirectory: isDirectory)
        if isDirectory {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    // MARK: - Slot — 알려진 파일/디렉터리

    enum Slot {
        case translationHistory
        case note
        case clipboardHistory
        case clipboardImagesDir
        case hiddenApps
        case usageHistory
        case claudeJSONLCache
        case resourceAnomalies
        case currencyRates

        var relativePath: String {
            switch self {
            case .translationHistory:  return "translation_history.json"
            case .note:                return "note.md"
            case .clipboardHistory:    return "clipboard_history.json"
            case .clipboardImagesDir:  return "images"
            case .hiddenApps:          return "hidden_apps.json"
            case .usageHistory:        return "usage_history.json"
            case .claudeJSONLCache:    return "jsonl_cache.json"
            case .resourceAnomalies:   return "resource_anomalies.json"
            case .currencyRates:       return "currency_rates.json"
            }
        }

        var isDirectory: Bool { self == .clipboardImagesDir }
    }

    static func url(for slot: Slot) -> URL {
        url(for: slot.relativePath, isDirectory: slot.isDirectory)
    }

    // MARK: - Codable convenience

    static func read<T: Decodable>(_ type: T.Type, from slot: Slot,
                                   decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = try? Data(contentsOf: url(for: slot)) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    /// JSON 인코딩 후 atomic 쓰기. 실패 시 silently drop — 호출부가 critical하면 직접 try.
    static func write<T: Encodable>(_ value: T, to slot: Slot,
                                    encoder: JSONEncoder = JSONEncoder()) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url(for: slot), options: .atomic)
    }
}
