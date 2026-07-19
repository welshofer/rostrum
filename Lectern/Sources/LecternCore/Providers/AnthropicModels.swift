import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Live model discovery + key validation against the Anthropic Messages API
/// (§294 Validate button / §130 availableModels). A successful call both proves
/// the key works and returns the current model ids — so the model Picker reflects
/// reality instead of a hardcoded guess.
public enum AnthropicModels {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/models")!

    /// GET /v1/models. Returns model ids newest-first (the API's order).
    /// - Throws: `.noKey`, `.authFailed`, `.rateLimited`, `.networkOffline`, or
    ///   `.providerError` — the same taxonomy the UI already renders.
    public static func list(apiKey: String, session: URLSession = .shared) async throws -> [String] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LecternError.noKey }
        var req = URLRequest(url: endpoint, timeoutInterval: 30)
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")           // never logged (I1)
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: req) }
        catch let error as URLError where error.code == .notConnectedToInternet { throw LecternError.networkOffline }

        guard let http = response as? HTTPURLResponse else { throw LecternError.providerError(status: 0, message: "no response") }
        switch http.statusCode {
        case 200:
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let models = (obj?["data"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
            return models
        case 401, 403:
            throw LecternError.authFailed(provider: "Anthropic")
        case 429:
            let retry = Int(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 2
            throw LecternError.rateLimited(afterSeconds: retry)
        default:
            throw LecternError.providerError(status: http.statusCode, message: "couldn't list models")
        }
    }
}
