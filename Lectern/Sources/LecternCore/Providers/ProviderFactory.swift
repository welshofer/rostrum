import Foundation

/// Builds the live provider for a stored key. There is **no Mock fallback** — a
/// deck is only ever produced by a real provider (a missing key is an error the
/// UI surfaces, not something papered over with fake output).
///
/// Invariant I1: the key arrives as a plain argument (read from the Keychain by
/// the caller) and is never persisted, copied, or logged here.
public enum ProviderFactory {
    /// - Throws: `.noKey` when no key is stored; `.providerError` for a provider
    ///   that isn't wired up yet.
    public static func make(id: ProviderID, apiKey: String?, model: String, effort: ReasoningEffort = .medium) throws -> any LLMProvider {
        guard let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            throw LecternError.noKey
        }
        guard id == .openAI else {
            throw LecternError.providerError(status: 0, message: "Lectern now uses OpenAI only.")
        }
        return OpenAIProvider(apiKey: key, model: model, effort: effort)
    }

    /// Whether `id` currently has a live implementation (independent of any key).
    public static func isWired(_ id: ProviderID) -> Bool { id == .openAI }
}
