import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// OpenAI model access checks without a generation request.
public enum OpenAIModels {
    private static let endpoint = URL(string: "https://api.openai.com/v1/models")!

    /// GET /v1/models. Returns the model identifiers available to this key.
    /// - Throws: `.noKey`, `.authFailed`, `.rateLimited`, `.networkOffline`, or
    ///   `.providerError` — the same taxonomy the UI already renders.
    public static func list(apiKey: String, session: URLSession = ProviderNetworking.session) async throws -> [String] {
        try await list(apiKey: apiKey, send: { request in try await session.data(for: request) })
    }

    /// Test seam, matching the providers: exercises the real retry and
    /// response handling without a key or a network.
    static func list(apiKey: String, send: HTTPRequestSender) async throws -> [String] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LecternError.noKey }
        var req = URLRequest(url: endpoint, timeoutInterval: 30)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")           // never logged (I1)

        // Retried on the shared schedule. This was the one network call in the
        // target that HTTPRetry did not reach, which meant a dropped
        // connection made a perfectly good key report as broken — from the
        // button whose entire job is answering that question.
        var attempt = 0
        while true {
            let data: Data, response: URLResponse
            do {
                (data, response) = try await send(req)
            } catch let error as URLError where error.code == .notConnectedToInternet {
                throw LecternError.networkOffline
            } catch let error as URLError where HTTPRetry.isRetriable(error)
                        && attempt + 1 < HTTPRetry.maxAttempts {
                try await HTTPRetry.wait(seconds: HTTPRetry.backoff(attempt: attempt, retryAfter: nil))
                attempt += 1
                continue
            }

            guard let http = response as? HTTPURLResponse else {
                throw LecternError.providerError(status: 0, message: "no response")
            }
            switch http.statusCode {
            case 200:
                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                return (obj?["data"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
            case 401, 403:
                throw LecternError.authFailed(provider: "OpenAI")
            case let status where HTTPRetry.isRetriable(status: status):
                let retryAfter = HTTPRetry.retryAfterSeconds(http)
                if attempt + 1 < HTTPRetry.maxAttempts {
                    try await HTTPRetry.wait(
                        seconds: HTTPRetry.backoff(attempt: attempt, retryAfter: retryAfter))
                    attempt += 1
                    continue
                }
                if status == 429 {
                    throw LecternError.rateLimited(
                        afterSeconds: retryAfter ?? HTTPRetry.backoff(attempt: attempt, retryAfter: nil))
                }
                throw LecternError.providerError(status: status, message: "couldn't list models")
            default:
                throw LecternError.providerError(status: http.statusCode, message: "couldn't list models")
            }
        }
    }
}
