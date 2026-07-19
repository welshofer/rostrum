import Foundation

/// Chooses a live provider from a stored API key, falling back to the Mock so the
/// app is *always* runnable offline (§13). The one place the "which provider"
/// decision lives, kept UI-free so it can be unit-tested without a keychain.
///
/// Invariant I1: this takes the key as a plain argument (read from the Keychain
/// by the caller) and never persists, copies, or logs it.
public enum ProviderFactory {
    /// - Parameters:
    ///   - id: the user's selected provider.
    ///   - apiKey: the key for that provider, or `nil`/blank if none is stored.
    ///   - model: the model identifier to request.
    ///   - mockJSON: the fixture the Mock replays when there's no key (or the
    ///     selected provider isn't wired live yet).
    /// - Returns: a live provider when a non-blank key is present *and* the
    ///   provider is implemented; otherwise `MockProvider`.
    public static func make(id: ProviderID, apiKey: String?, model: String,
                            mockJSON: String) -> any LLMProvider {
        guard let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            return MockProvider(validJSON: mockJSON)
        }
        switch id {
        case .anthropic:
            return AnthropicProvider(apiKey: key, model: model)
        case .openAI, .gemini, .custom:
            // Not wired live yet (§7.2) — stay on the Mock rather than pretend.
            return MockProvider(validJSON: mockJSON)
        }
    }

    /// Whether selecting `id` with `apiKey` would produce a *live* provider (vs a
    /// silent Mock fallback) — lets the UI tell the truth about what will run.
    public static func isLive(id: ProviderID, apiKey: String?) -> Bool {
        guard let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else { return false }
        switch id {
        case .anthropic: return true
        case .openAI, .gemini, .custom: return false
        }
    }
}
