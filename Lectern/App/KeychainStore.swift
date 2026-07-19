import Foundation
import LecternCore
#if canImport(Security)
import Security
#endif

/// The *only* home for provider API keys (invariant I1): a generic-password item
/// per provider in the user's login keychain. Keys are never written to
/// UserDefaults and never logged — this type exposes presence and a one-shot read
/// used at generation time, nothing that would surface a secret to the UI.
enum KeychainStore {
    private static let service = "com.lectern.app.apikeys"

    /// Upsert the key for `provider` (delete-then-add keeps it idempotent).
    @discardableResult
    static func save(_ key: String, for provider: ProviderID) -> Bool {
        #if canImport(Security)
        delete(for: provider)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecValueData as String: Data(key.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
        #else
        return false
        #endif
    }

    /// The stored key for `provider`, or `nil`. Called at generation time only.
    static func read(for provider: ProviderID) -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
        #else
        return nil
        #endif
    }

    @discardableResult
    static func delete(for provider: ProviderID) -> Bool {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
        #else
        return false
        #endif
    }

    /// Presence check — a keychain read returning nothing is the only thing the UI
    /// ever learns about a stored key.
    static func hasKey(for provider: ProviderID) -> Bool { read(for: provider) != nil }
}
