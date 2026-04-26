import Foundation
import IOKit

/// 자가서명 빌드에서 Keychain ACL prompt가 매 업데이트마다 뜨는 문제를 피하기 위한
/// 파일 기반 보관소. 기존 `Keychain` 과 동일한 read/write/delete 인터페이스를 가진다.
///
/// 저장 위치: `~/Library/Application Support/Lumen/secrets.dat`
/// - 평문 JSON을 저장하지 않고, 이 머신의 IOPlatformUUID를 키로 한 XOR로 가볍게 가린다.
///   머신을 통째로 들고 가는 위협은 막지 못하지만, 단순 파일 노출(백업, 실수 공유)에서
///   토큰이 그대로 보이는 사고는 차단한다. 자가서명·단일사용자 환경의 위협 모델과 균형.
/// - 파일은 owner-only(0600)로 만든다.
enum SecretStore {
    static func read(_ account: String) -> String? {
        load()[account]
    }

    @discardableResult
    static func write(_ value: String, for account: String) -> Bool {
        if value.isEmpty {
            return delete(account)
        }
        var dict = load()
        dict[account] = value
        return save(dict)
    }

    @discardableResult
    static func delete(_ account: String) -> Bool {
        var dict = load()
        guard dict.removeValue(forKey: account) != nil else { return true }
        return save(dict)
    }

    // MARK: - Storage

    private static let fileURL: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Lumen", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("secrets.dat", isDirectory: false)
    }()

    private static func load() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return [:] }
        let plain = xor(data, with: keyBytes)
        return (try? JSONDecoder().decode([String: String].self, from: plain)) ?? [:]
    }

    private static func save(_ dict: [String: String]) -> Bool {
        do {
            let plain = try JSONEncoder().encode(dict)
            let cipher = xor(plain, with: keyBytes)
            try cipher.write(to: fileURL, options: .atomic)
            // owner-only 권한 — 다른 user 계정에서 읽지 못하도록.
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Obfuscation key

    /// 머신 고유 UUID를 SHA 없이 raw bytes로 사용. 다른 머신에서 파일을 가져가도
    /// 키가 달라 복호화되지 않는다.
    private static let keyBytes: [UInt8] = {
        let uuid = ioPlatformUUID() ?? "Lumen-fallback-key-2026"
        return Array(uuid.utf8)
    }()

    private static func ioPlatformUUID() -> String? {
        let entry = IOServiceGetMatchingService(kIOMainPortDefault,
                                                IOServiceMatching("IOPlatformExpertDevice"))
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        guard let cf = IORegistryEntryCreateCFProperty(entry,
                                                       "IOPlatformUUID" as CFString,
                                                       kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String else { return nil }
        return cf
    }

    private static func xor(_ data: Data, with key: [UInt8]) -> Data {
        guard !key.isEmpty else { return data }
        var out = Data(count: data.count)
        for i in 0..<data.count {
            out[i] = data[i] ^ key[i % key.count]
        }
        return out
    }
}
