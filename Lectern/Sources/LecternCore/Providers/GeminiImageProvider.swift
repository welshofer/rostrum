import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Gemini 3.1 Flash Image ("Nano Banana 2") via the Interactions API. Returns
/// the final image content block. No vendor SDK (house rule); key never logged (I1).
public struct GeminiImageProvider: ImageProvider {
    public let id: ImageProviderID = .gemini
    private let apiKey: String
    private let model: String
    private let send: HTTPRequestSender

    public init(apiKey: String, model: String = "gemini-3.1-flash-image", session: URLSession = ProviderNetworking.session) {
        self.apiKey = apiKey
        self.model = model
        self.send = { request in try await session.data(for: request) }
    }

    init(apiKey: String, model: String = "gemini-3.1-flash-image",
         send: @escaping HTTPRequestSender) {
        self.apiKey = apiKey
        self.model = model
        self.send = send
    }

    /// Validate the key against the exact model Lectern will use, rather than
    /// treating successful Keychain storage as proof that Gemini accepted it.
    public func validate() async throws {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        // `model` is caller-supplied API surface: interpolated raw, one space
        // or `#` makes `URL(string:)` nil and the `!` a crash. Encode it.
        let url = try Self.endpoint(model: model)
        let (data, http) = try await perform(request(url: url))
        switch http.statusCode {
        case 200:
            return
        case 400 where invalidAPIKey(data):
            throw LecternError.authFailed(provider: "Gemini")
        case 401, 403:
            throw LecternError.authFailed(provider: "Gemini")
        case 400:
            throw LecternError.providerError(status: 400, message: message(data))
        case 404:
            throw LecternError.providerError(
                status: 404, message: "\(model) isn't available to this Gemini project.")
        case 429:
            throw LecternError.rateLimited(afterSeconds: retryDelay(http, data: data, fallback: 2))
        default:
            throw LecternError.providerError(status: http.statusCode, message: message(data))
        }
    }

    public func image(prompt: String, style: String?, aspect: ImageAspect, role: ImageRole) async throws -> Data {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        let full = ImageStyleDirective.compose(style: style, role: role, subject: prompt, aspect: aspect)
        let body: [String: Any] = [
            "model": model,
            "store": false,
            "input": [["type": "text", "text": full]],
            "generation_config": ["thinking_level": "high"],
            "response_format": [
                "type": "image",
                "mime_type": "image/jpeg",
                "aspect_ratio": aspect.rawValue,
                "image_size": "2K",
            ],
        ]
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!
        var req = request(url: url, method: "POST", timeout: 180)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        for attempt in 0..<HTTPRetry.maxAttempts {
            let (data, http) = try await perform(req)
            switch http.statusCode {
            case 200:
                guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let steps = obj["steps"] as? [[String: Any]] else {
                    throw LecternError.providerError(status: 200, message: "unexpected Gemini response")
                }
                for step in steps where step["type"] as? String == "model_output" {
                    guard let content = step["content"] as? [[String: Any]] else { continue }
                    for block in content where block["type"] as? String == "image" {
                        if let b64 = block["data"] as? String, let bytes = Data(base64Encoded: b64) {
                            return bytes
                        }
                    }
                }
                throw LecternError.providerError(status: 200, message: "no image in Gemini response")
            case 400 where invalidAPIKey(data):
                throw LecternError.authFailed(provider: "Gemini")
            case 401, 403:
                throw LecternError.authFailed(provider: "Gemini")
            case 400:
                throw LecternError.providerError(status: 400, message: message(data))
            case 429:
                let retryAfter = retryDelay(http, data: data, fallback: -1)
                let delay = retryAfter >= 0
                    ? HTTPRetry.backoff(attempt: attempt, retryAfter: retryAfter)
                    : HTTPRetry.backoff(attempt: attempt, retryAfter: nil)
                if attempt + 1 < HTTPRetry.maxAttempts {
                    try await HTTPRetry.wait(seconds: delay)
                    continue
                }
                throw LecternError.rateLimited(afterSeconds: delay)
            default:
                throw LecternError.providerError(status: http.statusCode, message: message(data))
            }
        }
        throw LecternError.providerError(status: 0, message: "Gemini image retry loop exhausted")
    }


    /// The models endpoint for `model`, percent-encoded. `model` is public
    /// API surface (`ImageProviderFactory` takes any string), and a raw
    /// interpolation makes `URL(string:)` nil — and a force-unwrap a crash —
    /// on the first identifier with a space or `#` in it.
    static func endpoint(model: String) throws -> URL {
        let encoded = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        guard !encoded.isEmpty, let url = URL(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(encoded)") else {
            throw LecternError.providerError(
                status: 0, message: "\"\(model)\" is not a usable model identifier")
        }
        return url
    }

    private func request(url: URL, method: String = "GET", timeout: TimeInterval = 30) -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")           // never logged (I1)
        return req
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
                // The 429 arm below was retried; a dropped connection was not,
                // though it says even less about the request.
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

    private func retryDelay(_ response: HTTPURLResponse, data: Data, fallback: Int) -> Int {
        if let value = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = HTTPRetry.seconds(value) {
            return seconds
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = obj["error"] as? [String: Any],
           let details = error["details"] as? [[String: Any]] {
            for detail in details {
                if let value = detail["retryDelay"] as? String, let seconds = HTTPRetry.seconds(value) {
                    return seconds
                }
            }
        }
        return fallback
    }

    private func message(_ data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? [String: Any], let m = err["message"] as? String else { return "image request failed" }
        return m
    }

    private func invalidAPIKey(_ data: Data) -> Bool {
        let text = message(data).lowercased()
        return text.contains("key") && (text.contains("invalid") || text.contains("not valid"))
    }
}
