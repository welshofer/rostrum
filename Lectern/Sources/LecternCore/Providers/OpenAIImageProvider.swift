import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// OpenAI image generation (Sunburst and Flare). Returns the base64 image. No vendor
/// SDK; key never logged (I1).
public struct OpenAIImageProvider: ImageProvider {
    public let id: ImageProviderID = .openAI
    private let apiKey: String
    private let model: String
    private let quality: ImageQuality
    private let send: HTTPRequestSender
    private let now: @Sendable () -> Date
    private let wait: @Sendable (TimeInterval) async throws -> Void

    /// The ceiling for one image, retries and backoff included. Images
    /// legitimately take longer than the 180-second text default, but one
    /// stuck image used to hold a generation for over an hour: an outer status
    /// loop and an inner transport loop multiplied to nine attempts of 600
    /// seconds each, with nothing watching the clock.
    static let imageDeadline: TimeInterval = 900

    /// The longest a single attempt may take, before the deadline clamps it.
    static let attemptTimeout: TimeInterval = 600

    public init(apiKey: String, model: String = ImageModel.flare.rawValue, quality: ImageQuality = .auto, session: URLSession = ProviderNetworking.session) {
        self.apiKey = apiKey
        self.model = model
        self.quality = quality
        self.send = { request in try await session.data(for: request) }
        self.now = { Date() }
        self.wait = { try await HTTPRetry.wait(seconds: $0) }
    }

    /// Test seam: real request-building and retry handling without a key or a
    /// network. Clock and wait injection let retry tests run the deadline
    /// without sleeping through it.
    init(apiKey: String, model: String = ImageModel.flare.rawValue, quality: ImageQuality = .auto,
         now: @escaping @Sendable () -> Date = { Date() },
         wait: @escaping @Sendable (TimeInterval) async throws -> Void = { try await HTTPRetry.wait(seconds: $0) },
         send: @escaping HTTPRequestSender) {
        self.apiKey = apiKey
        self.model = model
        self.quality = quality
        self.send = send
        self.now = now
        self.wait = wait
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
        let (data, http, _) = try await perform(req, startedAt: now(), cap: 30,
                                                deadline: HTTPRetry.overallDeadline, retryingStatuses: false)
        switch http.statusCode {
        case 200:
            return
        case 401, 403:
            throw LecternError.authFailed(provider: "OpenAI")
        case 404:
            throw LecternError.providerError(status: 404, message: "\(model) isn't available to this OpenAI project.")
        case 429:
            throw LecternError.rateLimited(afterSeconds: HTTPRetry.retryAfterSeconds(http) ?? 5)
        default:
            throw LecternError.providerError(status: http.statusCode, message: message(data))
        }
    }

    public func image(prompt: String, style: String?, aspect: ImageAspect, role: ImageRole) async throws -> Data {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        let startedAt = now()
        let full = ImageStyleDirective.compose(style: style, role: role, subject: prompt, aspect: aspect)
        let body: [String: Any] = ["model": model, "prompt": full, "size": aspect.openAISize, "n": 1, "quality": quality.rawValue, "output_format": "png"]

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!,
                             timeoutInterval: Self.attemptTimeout)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")   // never logged (I1)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, http, lastWait) = try await perform(req, startedAt: startedAt, cap: Self.attemptTimeout,
                                                      deadline: Self.imageDeadline, retryingStatuses: true)
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
        case 429:
            // Retries (or the deadline) are spent: name the rate limit rather
            // than reporting an image that couldn't be generated. The hint is
            // the wait `perform` computed for this response, not a fresh draw.
            throw LecternError.rateLimited(
                afterSeconds: HTTPRetry.retryAfterSeconds(http)
                    ?? Int(ceil(lastWait ?? HTTPRetry.backoff(attempt: 0, retryAfter: nil))))
        default:
            throw LecternError.providerError(status: http.statusCode, message: message(data))
        }
    }

    /// Sends `request`, retrying dropped connections — and, when
    /// `retryingStatuses`, rate limits and server faults — under ONE attempt
    /// counter and one deadline measured from `startedAt`.
    ///
    /// This used to be two nested loops (statuses outside, transport inside),
    /// each allowed `HTTPRetry.maxAttempts`, so the worst case was nine
    /// 600-second attempts with no clock in sight. Now each attempt's timeout
    /// is clamped to the time left, and no retry — nor its backoff — starts
    /// that would run past `deadline`. When retries stop, the last failure is
    /// what the caller sees: a transport error is rethrown as-is, a status is
    /// returned for the caller to map.
    ///
    /// - Returns: the response, and the backoff computed after it (`nil` when
    ///   it was not a retriable status), so a rate-limit hint reuses the same
    ///   jittered value rather than drawing a new one.
    private func perform(_ request: URLRequest, startedAt: Date, cap: TimeInterval,
                         deadline: TimeInterval, retryingStatuses: Bool) async throws
        -> (Data, HTTPURLResponse, TimeInterval?) {
        var attempt = 0
        var lastFailure: Result<(Data, HTTPURLResponse), Error>?
        var lastStatusWait: TimeInterval?
        while true {
            try Task.checkCancellation()
            guard let timeout = HTTPRetry.timeout(startedAt: startedAt, cap: cap, deadline: deadline, now: now()) else {
                // The backoff ate the remaining time: report what last went
                // wrong, not a new error the user cannot act on.
                switch lastFailure {
                case .success(let (data, http)): return (data, http, lastStatusWait)
                case .failure(let error): throw error
                case nil:
                    throw LecternError.providerError(
                        status: 0, message: "the image request ran out of time before it could finish")
                }
            }
            var attemptRequest = request
            attemptRequest.timeoutInterval = timeout

            let data: Data, response: URLResponse
            do {
                (data, response) = try await send(attemptRequest)
            } catch let error as URLError where error.code == .notConnectedToInternet {
                throw LecternError.networkOffline
            } catch let error as URLError where HTTPRetry.isRetriable(error) {
                // A dropped or timed-out connection says nothing about the
                // request, so it is worth asking again — if there is time.
                let nextWait = HTTPRetry.backoff(attempt: attempt, retryAfter: nil)
                guard attempt + 1 < HTTPRetry.maxAttempts,
                      HTTPRetry.hasTimeToRetry(startedAt: startedAt, nextWait: nextWait,
                                               deadline: deadline, now: now()) else {
                    throw error
                }
                lastFailure = .failure(error)
                try await wait(nextWait)
                attempt += 1
                continue
            }
            guard let http = response as? HTTPURLResponse else {
                throw LecternError.providerError(status: 0, message: "no response")
            }
            if retryingStatuses, HTTPRetry.isRetriable(status: http.statusCode) {
                // This used to give up on the first 429 — the one status a
                // burst of image requests is most likely to provoke.
                let nextWait = HTTPRetry.backoff(attempt: attempt, retryAfter: HTTPRetry.retryAfterSeconds(http))
                if attempt + 1 < HTTPRetry.maxAttempts,
                   HTTPRetry.hasTimeToRetry(startedAt: startedAt, nextWait: nextWait,
                                            deadline: deadline, now: now()) {
                    lastFailure = .success((data, http))
                    lastStatusWait = nextWait
                    try await wait(nextWait)
                    attempt += 1
                    continue
                }
                return (data, http, nextWait)
            }
            return (data, http, nil)
        }
    }

    private func message(_ data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? [String: Any], let m = err["message"] as? String else { return "image request failed" }
        return m
    }
}
