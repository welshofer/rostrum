import Foundation
import LecternCore
#if canImport(Security)
import Security
#endif

/// The *only* home for API keys (invariant I1): a generic-password item per
/// account. Keys are never written to UserDefaults and never logged.
///
/// Storage uses the **data-protection keychain** with a keychain-access-group
/// keyed to team + bundle id (see `Lectern.entitlements`). Unlike the login
/// keychain — whose ACL is bound to the *code signature* and so orphaned the key
/// on every rebuild — the data-protection keychain grants access by the app's
/// stable identity, so a saved key survives all future rebuilds. Every operation
/// falls back to the login keychain if the entitlement isn't granted, so there is
/// no regression: worst case is the old (signature-bound) behavior, never a hard
/// failure.
enum KeychainStore {
    private static let service = "com.lectern.app.apikeys"
    private static let accessGroup = "QGNJVQUKK7.com.lectern.app"

    private static func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    /// Rebuild-stable query: data-protection keychain + access group.
    private static func modern(_ account: String) -> [String: Any] {
        var q = base(account)
        #if canImport(Security)
        q[kSecUseDataProtectionKeychain as String] = true
        q[kSecAttrAccessGroup as String] = accessGroup
        #endif
        return q
    }

    // MARK: Account-based core

    @discardableResult
    static func save(_ key: String, account: String) -> Bool {
        #if canImport(Security)
        delete(account: account)   // clear both keychains first
        let data = Data(key.utf8)
        // Prefer the data-protection keychain; fall back to the login keychain if
        // the entitlement isn't granted (errSecMissingEntitlement etc.).
        for var attrs in [modern(account), base(account)] {
            attrs[kSecValueData as String] = data
            attrs[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            if SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess { return true }
        }
        return false
        #else
        return false
        #endif
    }

    static func read(account: String) -> String? {
        #if canImport(Security)
        for var query in [modern(account), base(account)] {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
               let data = item as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        return nil
        #else
        return nil
        #endif
    }

    @discardableResult
    static func delete(account: String) -> Bool {
        #if canImport(Security)
        SecItemDelete(modern(account) as CFDictionary)
        SecItemDelete(base(account) as CFDictionary)
        return true
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
