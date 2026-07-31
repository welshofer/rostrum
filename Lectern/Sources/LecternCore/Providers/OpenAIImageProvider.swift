import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// OpenAI image generation (gpt-image-1). Returns the base64 image. No vendor
/// SDK; key never logged (I1).
public struct OpenAIImageProvider: ImageProvider {
    public let id: ImageProviderID = .openAI
    private let apiKey: String
    private let model: String
    private let send: HTTPRequestSender

    public init(apiKey: String, model: String = "gpt-image-1", session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.send = { request in try await session.data(for: request) }
    }

    init(apiKey: String, model: String = "gpt-image-1",
         send: @escaping HTTPRequestSender) {
        self.apiKey = apiKey
        self.model = model
        self.send = send
    }

    public func validate() async throws {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/models/\(model)")!, timeoutInterval: 30)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, http) = try await perform(req)
        switch http.statusCode {
        case 200:
            return
        case 401, 403:
            throw LecternError.authFailed(provider: "OpenAI")
        case 404:
            throw LecternError.providerError(status: 404, message: "\(model) isn't available to this OpenAI project.")
        case 429:
            throw LecternError.rateLimited(afterSeconds: Int(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 5)
        default:
            throw LecternError.providerError(status: http.statusCode, message: message(data))
        }
    }

    public func image(prompt: String, style: String?, aspect: ImageAspect, role: ImageRole) async throws -> Data {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        let full = ImageStyleDirective.compose(style: style, role: role, subject: prompt, aspect: aspect)
        let body: [String: Any] = ["model": model, "prompt": full, "size": aspect.openAISize, "n": 1]

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")   // never logged (I1)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        for attempt in 0..<HTTPRetry.maxAttempts {
        let (data, http) = try await perform(req)
        switch http.statusCode {
        case 200:
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = obj["data"] as? [[String: Any]],
                  let b64 = arr.first?["b64_json"] as? String,
                  let bytes = Data(base64Encoded: b64) else {
                throw LecternError.providerError(status: 200, message: "no image in OpenAI response")
            }
            return bytes
        case 401, 403:
            throw LecternError.authFailed(provider: "OpenAI")
        case let status where HTTPRetry.isRetriable(status: status):
            // This used to give up on the first 429 — the one status a burst of
            // image requests is most likely to provoke — and the user read it
            // as an image that couldn't be generated. Gemini retried; this did
            // not; nothing about the two providers justified the difference.
            let retryAfter = HTTPRetry.retryAfterSeconds(http)
            if attempt + 1 < HTTPRetry.maxAttempts {
                try await HTTPRetry.wait(
                    seconds: HTTPRetry.backoff(attempt: attempt, retryAfter: retryAfter))
                continue
            }
            if status == 429 {
                throw LecternError.rateLimited(
                    afterSeconds: retryAfter ?? HTTPRetry.backoff(attempt: attempt, retryAfter: nil))
            }
            throw LecternError.providerError(status: status, message: message(data))
        default:
            throw LecternError.providerError(status: http.statusCode, message: message(data))
        }
        }
        throw LecternError.providerError(status: 0, message: "OpenAI image retry loop exhausted")
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        while true {
            let data: Data, response: URLResponse
            do {
                (data, response) = try await send(request)
            } catch let error as URLError where error.code == .notConnectedToInternet {
                throw LecternError.networkOffline
            } catch let error as URLError where HTTPRetry.isRetriable(error)
                        && attempt + 1 < HTTPRetry.maxAttempts {
                // A dropped or timed-out connection says nothing about the
                // request, so it is worth asking again rather than reporting a
                // failed image.
                try await HTTPRetry.wait(seconds: HTTPRetry.backoff(attempt: attempt, retryAfter: nil))
                attempt += 1
                continue
            }
            guard let http = response as? HTTPURLResponse else {
                throw LecternError.providerError(status: 0, message: "no response")
            }
            return (data, http)
        }
    }

    private func message(_ data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? [String: Any], let m = err["message"] as? String else { return "image request failed" }
        return m
    }
}
