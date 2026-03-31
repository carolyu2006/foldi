import Security
import Foundation

/// Thin wrapper around macOS Keychain for storing small sensitive strings.
enum KeychainHelper {
    private static let service = "app.foldi"

    /// Save (or overwrite) a string value under `key`.
    @discardableResult
    static func save(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        // Try update first; if not found, add fresh.
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as CFString: data] as CFDictionary
        )
        if updateStatus == errSecItemNotFound {
            var attrs = query
            attrs[kSecValueData] = data
            return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
        }
        return updateStatus == errSecSuccess
    }

    /// Load a string value previously stored under `key`, or nil if absent.
    static func load(for key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Remove the item stored under `key`.
    static func delete(for key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
