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
    public static func make(id: ProviderID, apiKey: String?, model: String) throws -> any LLMProvider {
        guard let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            throw LecternError.noKey
        }
        switch id {
        case .anthropic:
            return AnthropicProvider(apiKey: key, model: model)
        case .openAI, .gemini, .custom:
            throw LecternError.providerError(status: 0, message: "\(id.rawValue) isn't wired up yet — use Anthropic.")
        }
    }

    /// Whether `id` currently has a live implementation (independent of any key).
    public static func isWired(_ id: ProviderID) -> Bool { id == .anthropic }
}
