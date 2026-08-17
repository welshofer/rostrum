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
        try? readOrFail(account: account)
    }

    /// Why a key that is demonstrably there still cannot be read.
    ///
    /// The distinction matters because the two need opposite responses from the
    /// user: one means "add a key", the other means "the key is fine, this
    /// build cannot open it".
    enum ReadProblem: Error, Equatable {
        /// No item for this account at all.
        case missing
        /// An item exists, but the keychain refused to hand over its contents —
        /// on macOS this is the login keychain's access control, which is bound
        /// to the signature of the build that saved it.
        case unreadable(OSStatus)
    }

    /// Read the secret, saying which kind of failure occurred.
    ///
    /// `exists` matches attributes and never decrypts; this decrypts. When a
    /// build's signature differs from the one that saved the item — which is
    /// what ad-hoc signing guarantees, since its cdhash changes every build —
    /// the first succeeds and the second does not. Reporting that as "no key
    /// stored" sent us looking for a save bug that was not there.
    static func readOrFail(account: String) throws -> String {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let key = String(data: data, encoding: .utf8) else {
                throw ReadProblem.unreadable(status)
            }
            return key
        case errSecItemNotFound:
            throw ReadProblem.missing
        default:
            // errSecAuthFailed / errSecInteractionNotAllowed land here, and so
            // does a user who declined the "wants to access" prompt.
            throw exists(account: account) ? ReadProblem.unreadable(status) : ReadProblem.missing
        }
        #else
        throw ReadProblem.missing
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
    static func readOrFail(for provider: ProviderID) throws -> String {
        try readOrFail(account: provider.rawValue)
    }
    @discardableResult
    static func delete(for provider: ProviderID) -> Bool { delete(account: provider.rawValue) }
    static func hasKey(for provider: ProviderID) -> Bool { exists(account: provider.rawValue) }

    // MARK: Image providers (separate namespace)

    @discardableResult
    static func save(_ key: String, forImage provider: ImageProviderID) -> Bool { save(key, account: "image:\(provider.rawValue)") }
    static func read(forImage provider: ImageProviderID) -> String? { read(account: "image:\(provider.rawValue)") }
    static func readOrFail(forImage provider: ImageProviderID) throws -> String {
        try readOrFail(account: "image:\(provider.rawValue)")
    }
    @discardableResult
    static func delete(forImage provider: ImageProviderID) -> Bool { delete(account: "image:\(provider.rawValue)") }
    static func hasKey(forImage provider: ImageProviderID) -> Bool { exists(account: "image:\(provider.rawValue)") }
}
