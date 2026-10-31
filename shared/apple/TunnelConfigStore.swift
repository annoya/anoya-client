import Foundation
import Security

enum TunnelConfigStore {
    private static var item: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "org.annoya.tunnel",
            kSecAttrAccount as String: "config",
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    static func load() -> String? {
        var query = item
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ config: String) throws {
        let fields: [String: Any] = [
            kSecValueData as String: Data(config.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(item as CFDictionary, fields as CFDictionary)
        if status != errSecSuccess {
            if status != errSecItemNotFound { SecItemDelete(item as CFDictionary) }
            status = SecItemAdd(item.merging(fields) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "could not store the tunnel config in the keychain (\(status))",
            ])
        }
    }

    static func delete() {
        SecItemDelete(item as CFDictionary)
    }
}
