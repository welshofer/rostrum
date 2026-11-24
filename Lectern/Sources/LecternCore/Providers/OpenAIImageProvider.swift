import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// OpenAI image generation (Sunburst and Flare). Returns the base64 image. No vendor
/// SDK; key never logged (I1).
public struct OpenAIImageProvider: ImageProvider {
    public let id: ImageProviderID = .openAI
    /// Overall deadline for a single image generation call, retries and backoff
    /// included. Matches the former per-request ceiling so one slow image still
    /// completes, without nested retries multiplying it up to 9 × 600 s.
    static let imageDeadline: TimeInterval = 600

    private let apiKey: String
    private let model: String
    private let quality: ImageQuality
    private let send: HTTPRequestSender
    private let now: @Sendable () -> Date
    private let wait: @Sendable (Int) async throws -> Void

    public init(apiKey: String, model: String = ImageModel.flare.rawValue, quality: ImageQuality = .auto, session: URLSession = ProviderNetworking.session) {
        self.apiKey = apiKey
        self.model = model
        self.quality = quality
        self.send = { request in try await session.data(for: request) }
        self.now = { Date() }
        self.wait = { try await HTTPRetry.wait(seconds: $0) }
    }

    init(apiKey: String, model: String = ImageModel.flare.rawValue, quality: ImageQuality = .auto,
         now: @escaping @Sendable () -> Date = { Date() },
         wait: @escaping @Sendable (Int) async throws -> Void = { try await HTTPRetry.wait(seconds: $0) },
         send: @escaping HTTPRequestSender) {
        self.apiKey = apiKey
        self.model = model
        self.quality = quality
        self.now = now
        self.wait = wait
        self.send = send
    }

    /// The models endpoint for `model`, percent-encoded. `model` is public
    /// API surface (`ImageProviderFactory` takes any string), and a raw
    /// interpolation makes `URL(string:)` nil — and a force-unwrap a crash —
    /// on the first identifier with a space or `#` in it.
    static func endpoint(model: String) throws -> URL {
        let encoded = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        guard !encoded.isEmpty, let url = URL(
            string: "https://api.openai.com/v1/models/\(encoded)") else {
            throw LecternError.providerError(
                status: 0, message: "\"\(model)\" is not a usable model identifier")
        }
        return url
    }

    public func validate() async throws {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        var req = URLRequest(url: try Self.endpoint(model: model), timeoutInterval: 30)
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
            if let quota = HTTPRetry.openAIInsufficientQuotaMessage(in: data) {
                throw LecternError.providerError(status: 429, message: quota)
            }
            throw LecternError.rateLimited(afterSeconds: Int(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 5)
        default:
            throw LecternError.providerError(status: http.statusCode, message: message(data))
        }
    }

    public func image(prompt: String, style: String?, aspect: ImageAspect, role: ImageRole) async throws -> Data {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        let full = ImageStyleDirective.compose(style: style, role: role, subject: prompt, aspect: aspect)
        let body: [String: Any] = ["model": model, "prompt": full, "size": aspect.openAISize, "n": 1, "quality": quality.rawValue, "output_format": "png"]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let endpoint = URL(string: "https://api.openai.com/v1/images/generations")!

        var attempt = 0
        let startedAt = now()
        while true {
            try Task.checkCancellation()
            guard let timeout = HTTPRetry.timeout(
                startedAt: startedAt, cap: Self.imageDeadline, deadline: Self.imageDeadline, now: now()
            ) else {
                throw LecternError.providerError(
                    status: 0, message: "the image request ran out of time before it could finish")
            }

            var req = URLRequest(url: endpoint, timeoutInterval: timeout)
            req.httpMethod = "POST"
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")   // never logged (I1)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = bodyData

            let data: Data, response: URLResponse
            do {
                (data, response) = try await send(req)
            } catch let error as URLError where error.code == .notConnectedToInternet {
                throw LecternError.networkOffline
            } catch let error as URLError where HTTPRetry.isRetriable(error) {
                // A dropped or timed-out connection says nothing about the
                // request, so it is worth asking again — within the same
                // attempt budget and overall deadline as HTTP status retries.
                let delay = HTTPRetry.backoff(attempt: attempt, retryAfter: nil)
                guard attempt + 1 < HTTPRetry.maxAttempts,
                      HTTPRetry.hasTimeToRetry(
                        startedAt: startedAt, nextWait: delay, deadline: Self.imageDeadline, now: now()) else {
                    throw LecternError.providerError(status: 0, message: error.localizedDescription)
                }
                try await wait(delay)
                attempt += 1
                continue
            }

            guard let http = response as? HTTPURLResponse else {
                throw LecternError.providerError(status: 0, message: "no response")
            }
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
            case 429 where HTTPRetry.openAIInsufficientQuotaMessage(in: data) != nil:
                throw LecternError.providerError(
                    status: 429,
                    message: HTTPRetry.openAIInsufficientQuotaMessage(in: data) ?? message(data))
            case let status where HTTPRetry.isRetriable(status: status):
                // This used to give up on the first 429 — the one status a burst of
                // image requests is most likely to provoke — and the user read it
                // as an image that couldn't be generated. Gemini retried; this did
                // not; nothing about the two providers justified the difference.
                let retryAfter = HTTPRetry.retryAfterSeconds(http)
                let delay = HTTPRetry.backoff(attempt: attempt, retryAfter: retryAfter)
                if attempt + 1 < HTTPRetry.maxAttempts,
                   HTTPRetry.hasTimeToRetry(
                    startedAt: startedAt, nextWait: delay, deadline: Self.imageDeadline, now: now()) {
                    try await wait(delay)
                    attempt += 1
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
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        while true {
            try Task.checkCancellation()
            let data: Data, response: URLResponse
            do {
                (data, response) = try await send(request)
            } catch let error as URLError where error.code == .notConnectedToInternet {
                throw LecternError.networkOffline
            } catch let error as URLError where HTTPRetry.isRetriable(error)
                        && attempt + 1 < HTTPRetry.maxAttempts {
                try await wait(HTTPRetry.backoff(attempt: attempt, retryAfter: nil))
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
