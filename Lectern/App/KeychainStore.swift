import Foundation
import LecternCore
#if canImport(Security)
import Security
#endif

/// The *only* home for API keys (invariant I1): a generic-password item per
/// account in the user's login keychain (macOS) or the app's data-protection
/// keychain (iOS/iPadOS, automatic — sandboxed per app, encrypted at rest,
/// readable only while the device is unlocked per kSecAttrAccessibleWhenUnlocked).
/// Keys are never written to UserDefaults and never logged.
///
/// NOTE ON PERSISTENCE ACROSS REBUILDS (macOS): the login keychain gates access by the
/// app's code signature (designated requirement). With the stable Development
/// signing this project uses, a key saved once persists across rebuilds. The
/// signature-independent alternative — the data-protection keychain with a
/// keychain-access-group — is not usable here: that entitlement is rejected at
/// launch without a provisioning profile, which this local/CLI setup can't mint.
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

    /// Whether a key is stored, without decrypting it.
    ///
    /// `read` returns the secret itself, so using it to answer a boolean copies
    /// the API key into an unmanaged Swift `String` — six times per launch from
    /// `AppState` alone, two of them before the first frame. This asks the
    /// keychain the same question with `kSecReturnData: false`, so the plaintext
    /// only ever leaves when it is genuinely about to be sent.
    static func exists(account: String) -> Bool {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
        #else
        return false
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
    static func hasKey(for provider: ProviderID) -> Bool { exists(account: provider.rawValue) }

    // MARK: Image providers (separate namespace)

    @discardableResult
    static func save(_ key: String, forImage provider: ImageProviderID) -> Bool { save(key, account: "image:\(provider.rawValue)") }
    static func read(forImage provider: ImageProviderID) -> String? { read(account: "image:\(provider.rawValue)") }
    @discardableResult
    static func delete(forImage provider: ImageProviderID) -> Bool { delete(account: "image:\(provider.rawValue)") }
    static func hasKey(forImage provider: ImageProviderID) -> Bool { exists(account: "image:\(provider.rawValue)") }
}
