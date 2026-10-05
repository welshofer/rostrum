import Foundation
import LecternCore
#if canImport(Security)
import Security
#else
typealias OSStatus = Int32
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

    enum Presence: Equatable {
        case present
        case missing
        /// A failed query does not establish whether an item is stored.
        case unavailable(OSStatus)
    }

    enum WriteProblem: Error, Equatable {
        case failed(OSStatus)
    }

    #if canImport(Security)
    /// Per-call injection keeps tests away from the user's Keychain. No global
    /// replacement or mutable shared Security client is installed.
    struct Operations {
        var update: ([String: Any], [String: Any]) -> OSStatus
        var add: ([String: Any]) -> OSStatus
        var copyMatching: ([String: Any]) -> (OSStatus, CFTypeRef?)
        var delete: ([String: Any]) -> OSStatus

        static var live: Operations {
            Operations(
                update: { SecItemUpdate($0 as CFDictionary, $1 as CFDictionary) },
                add: { SecItemAdd($0 as CFDictionary, nil) },
                copyMatching: {
                    var item: CFTypeRef?
                    let status = SecItemCopyMatching($0 as CFDictionary, &item)
                    return (status, item)
                },
                delete: { SecItemDelete($0 as CFDictionary) })
        }
    }

    private static func query(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func saveOrFail(_ key: String, account: String, operations: Operations = .live) throws {
        let match = query(account: account)
        // Updating data preserves an existing item's access control. Never
        // delete first: a denied/failed replacement must retain the old value.
        let data = [kSecValueData as String: Data(key.utf8)]
        let status = operations.update(match, data)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw WriteProblem.failed(status) }

        var attributes = match
        attributes[kSecValueData as String] = data[kSecValueData as String]
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        let added = operations.add(attributes)
        if added == errSecSuccess { return }
        // Another writer may have added the account after the first update.
        // Retry once without deleting that writer's item or changing its ACL.
        guard added == errSecDuplicateItem else { throw WriteProblem.failed(added) }
        let retried = operations.update(match, data)
        guard retried == errSecSuccess else { throw WriteProblem.failed(retried) }
    }
    #else
    static func saveOrFail(_ key: String, account: String) throws { throw WriteProblem.failed(-4) }
    #endif

    // MARK: Account-based core

    @discardableResult
    static func save(_ key: String, account: String) -> Bool {
        do { try saveOrFail(key, account: account); return true }
        catch { return false }
    }

    static func read(account: String) -> String? {
        try? readOrFail(account: account)
    }

    /// Absence and access failure need different recovery. An access failure
    /// does not prove presence, absence, or a code-signature mismatch.
    enum ReadProblem: Error, Equatable {
        /// No item for this account at all.
        case missing
        /// Keychain could not supply a valid value; retain the actual status.
        case unreadable(OSStatus)
    }

    /// Read the secret, saying which kind of failure occurred.
    ///
    /// Only errSecItemNotFound means missing. A second failed query cannot
    /// turn a locked, cancelled, or denied read into evidence of absence.
    #if canImport(Security)
    static func readOrFail(account: String, operations: Operations = .live) throws -> String {
        var match = query(account: account)
        match[kSecReturnData as String] = true
        match[kSecMatchLimit as String] = kSecMatchLimitOne
        let (status, item) = operations.copyMatching(match)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let key = String(data: data, encoding: .utf8) else {
                throw ReadProblem.unreadable(errSecDecode)
            }
            return key
        case errSecItemNotFound:
            throw ReadProblem.missing
        default:
            throw ReadProblem.unreadable(status)
        }
    }
    #else
    static func readOrFail(account: String) throws -> String { throw ReadProblem.unreadable(-4) }
    #endif

    #if canImport(Security)
    static func presence(account: String, operations: Operations = .live) -> Presence {
        var match = query(account: account)
        match[kSecReturnData as String] = false
        match[kSecMatchLimit as String] = kSecMatchLimitOne
        let (status, _) = operations.copyMatching(match)
        switch status {
        case errSecSuccess: return .present
        case errSecItemNotFound: return .missing
        default: return .unavailable(status)
        }
    }

    static func deleteOrFail(account: String, operations: Operations = .live) throws {
        let status = operations.delete(query(account: account))
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WriteProblem.failed(status)
        }
    }
    #else
    static func presence(account: String) -> Presence { .unavailable(-4) }
    static func deleteOrFail(account: String) throws { throw WriteProblem.failed(-4) }
    #endif

    /// Whether a key is stored, without decrypting it.
    ///
    /// `read` returns the secret itself, so using it to answer a boolean copies
    /// the API key into an unmanaged Swift `String` — six times per launch from
    /// `AppState` alone, two of them before the first frame. This asks the
    /// keychain the same question with `kSecReturnData: false`, so the plaintext
    /// only ever leaves when it is genuinely about to be sent.
    static func exists(account: String) -> Bool {
        presence(account: account) == .present
    }

    @discardableResult
    static func delete(account: String) -> Bool {
        do { try deleteOrFail(account: account); return true }
        catch { return false }
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
