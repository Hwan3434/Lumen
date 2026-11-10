import Foundation
import IOKit

/// 자가서명 빌드에서 Keychain ACL prompt가 매 업데이트마다 뜨는 문제를 피하기 위한
/// 파일 기반 보관소.
///
/// 저장 위치: `~/Library/Application Support/Lumen/secrets.dat`
/// - 평문 JSON을 저장하지 않고, 이 머신의 IOPlatformUUID를 키로 한 XOR로 가볍게 가린다.
///   이는 암호화가 아니라 난독화다. 같은 사용자 계정/같은 머신에서 파일을 읽을 수 있는
///   공격자는 복구할 수 있으므로, 위협 모델은 "단순 파일 노출에서 평문 토큰을 피함"에 한정된다.
/// - 파일은 owner-only(0600)로 만든다.
/// - 저장된 파일을 풀지 못해도 그 위에 덮어쓰지 않는다(`loadForWrite`).
///
/// 백그라운드에서 불러도 되도록 상태 없는 `nonisolated` 도우미로 둔다. `url`은 테스트가 임시 경로를 넣을 때만 쓴다.
nonisolated enum SecretStore {
    static func read(_ account: String, at url: URL = fileURL) -> String? {
        load(from: url)?[account]
    }

    @discardableResult
    static func write(_ value: String, for account: String, at url: URL = fileURL) -> Bool {
        if value.isEmpty {
            return delete(account, at: url)
        }
        guard var dict = loadForWrite(from: url) else { return false }
        dict[account] = value
        return save(dict, to: url)
    }

    @discardableResult
    static func delete(_ account: String, at url: URL = fileURL) -> Bool {
        // 풀지 못한 파일은 지울 값이 있는지도 모르니 손대지 않는다 — 옮기면 다음 실행에서 원래 키로도 못 찾는다.
        guard var dict = load(from: url), dict.removeValue(forKey: account) != nil else { return true }
        return save(dict, to: url)
    }

    // MARK: - Storage

    static let fileURL = LumenStorage.url(for: "secrets.dat")

    /// 파일이 없거나 비어 있으면 빈 사전, 있는데 읽거나 풀지 못하면 nil.
    private static func load(from url: URL) -> [String: String]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard !data.isEmpty else { return [:] }
        return try? JSONDecoder().decode([String: String].self, from: xor(data, with: keyBytes))
    }

    /// 쓰기 전에 지금 값을 읽는다. 풀지 못한 파일(키가 바뀐 경우 — UUID를 한 번 못 읽어 대체 키를 썼거나,
    /// 홈 폴더를 다른 Mac으로 옮긴 경우)을 빈 사전으로 덮어쓰면 저장된 값이 모두 사라지므로,
    /// 먼저 `secrets.dat.bak-<초>`로 옮겨 둔다. 옮기지 못하면 nil — 쓰지 않는다.
    private static func loadForWrite(from url: URL) -> [String: String]? {
        if let dict = load(from: url) { return dict }
        let backup = url.appendingPathExtension("bak-\(Int(Date().timeIntervalSince1970))")
        guard (try? FileManager.default.moveItem(at: url, to: backup)) != nil else { return nil }
        return [:]
    }

    private static func save(_ dict: [String: String], to url: URL) -> Bool {
        do {
            let plain = try JSONEncoder().encode(dict)
            let cipher = xor(plain, with: keyBytes)
            try cipher.write(to: url, options: .atomic)
            // owner-only 권한 — 다른 user 계정에서 읽지 못하도록.
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
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
