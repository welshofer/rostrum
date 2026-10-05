import Foundation

/// All credential operations use the same dependency, including validation and
/// generation. Test sessions cannot reach the user's Keychain through a button
/// or a later AppState action after skipping the initial availability check.
@MainActor
struct CredentialStore {
    var save: (String, String) throws -> Void
    var read: (String) throws -> String
    var delete: (String) throws -> Void
    var presence: (String) -> KeychainStore.Presence

    static let keychain = CredentialStore(
        save: { try KeychainStore.saveOrFail($0, account: $1) },
        read: { try KeychainStore.readOrFail(account: $0) },
        delete: { try KeychainStore.deleteOrFail(account: $0) },
        presence: { KeychainStore.presence(account: $0) })

    enum IsolationError: Error { case disabled }

    /// No real credentials, retained secrets, or Keychain calls in a test host.
    static let disabled = CredentialStore(
        save: { _, _ in throw IsolationError.disabled },
        read: { _ in throw IsolationError.disabled },
        delete: { _ in throw IsolationError.disabled },
        presence: { _ in .missing })
}
