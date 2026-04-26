import Foundation
import Security

/// 앱 전용 Keychain 래퍼. account 문자열을 키로, UTF-8 문자열을 값으로 다룬다.
/// service는 번들 식별자를 사용해 다른 앱과 격리된다.
enum Keychain {
    private static let service: String = Bundle.main.bundleIdentifier ?? "com.jh.Lumen"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str  = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    /// 빈 문자열을 쓰면 항목을 삭제한다.
    /// 항목 생성 시 ACL을 "이 앱만 신뢰"로 명시 — 매번 키체인 prompt가 뜨는 걸 막는다.
    /// (SecAccessCreate는 deprecated지만 self-signed 환경에서는 keychain-access-groups
    ///  entitlement 없이 ACL을 정확히 잡을 수 있는 유일한 경로다.)
    @discardableResult
    static func write(_ value: String, for account: String) -> Bool {
        if value.isEmpty {
            delete(account)
            return true
        }
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            if let access = makeSelfTrustedAccess() {
                addQuery[kSecAttrAccess as String] = access
            }
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    /// 현재 실행 중인 Lumen.app만 trusted app으로 갖는 SecAccess 객체.
    /// 다른 앱이 같은 항목 접근하려 하면 시스템이 prompt를 띄우지만, Lumen 자신은
    /// 매 업데이트마다 prompt 없이 통과한다 (designated requirement가 동일하므로).
    /// SecAccessCreate / SecTrustedApplicationCreateFromPath는 10.10에서 "deprecated"
    /// 표시됐지만 modern 대체재(keychain-access-groups entitlement)는 development cert
    /// 서명을 요구해 self-signed 빌드에선 쓸 수 없다. 자가서명 환경에선 이 경로가 정공법.
    private static func makeSelfTrustedAccess() -> SecAccess? {
        let bundlePath = Bundle.main.bundleURL.path
        var trustedApp: SecTrustedApplication?
        let status = SecTrustedApplicationCreateFromPath(bundlePath, &trustedApp)
        guard status == errSecSuccess, let app = trustedApp else { return nil }

        var access: SecAccess?
        let createStatus = SecAccessCreate("Lumen" as CFString, [app] as CFArray, &access)
        guard createStatus == errSecSuccess else { return nil }
        return access
    }

    @discardableResult
    static func delete(_ account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
