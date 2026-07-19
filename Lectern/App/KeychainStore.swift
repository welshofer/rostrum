import Foundation
import LecternCore
#if canImport(Security)
import Security
#endif

/// The *only* home for API keys (invariant I1): a generic-password item per
/// account in the user's login keychain. Keys are never written to UserDefaults
/// and never logged — this type exposes presence and a one-shot read used at
/// generation time, nothing that would surface a secret to the UI. Text (LLM) and
/// image keys live under separate account namespaces.
enum KeychainStore {
    private static let service = "com.lectern.app.apikeys"

    // MARK: Account-based core

    @discardableResult
    static func save(_ key: String, account: String) -> Bool {
        #if canImport(Security)
        delete(account: account)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(key.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
        #else
        return false
        #endif
    }

    static func read(account: String) -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
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
    static func delete(account: String) -> Bool {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
        #else
        return false
        #endif
    }

    // MARK: LLM providers

    @discardableResult
    static func save(_ key: String, for provider: ProviderID) -> Bool { save(key, account: provider.rawValue) }
    static func read(for provider: ProviderID) -> String? { read(account: provider.rawValue) }
    @discardableResult
    static func delete(for provider: ProviderID) -> Bool { delete(account: provider.rawValue) }
    static func hasKey(for provider: ProviderID) -> Bool { read(for: provider) != nil }

    // MARK: Image providers (separate namespace)

    @discardableResult
    static func save(_ key: String, forImage provider: ImageProviderID) -> Bool { save(key, account: "image:\(provider.rawValue)") }
    static func read(forImage provider: ImageProviderID) -> String? { read(account: "image:\(provider.rawValue)") }
    @discardableResult
    static func delete(forImage provider: ImageProviderID) -> Bool { delete(account: "image:\(provider.rawValue)") }
    static func hasKey(forImage provider: ImageProviderID) -> Bool { read(forImage: provider) != nil }
}
