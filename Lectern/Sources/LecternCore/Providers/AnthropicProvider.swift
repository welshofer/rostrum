import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // URLSession/URLRequest/HTTPURLResponse live here on Linux
#endif

// A live provider on the Anthropic Messages API, hand-rolled on URLSession (no
// vendor SDK, per the house rules). Compiles and is structured to the spec; the
// network round-trip needs a real key to smoke-test (AT-03/23). OpenAI / Gemini
// / Custom follow the same shape: build request → send with one 429/5xx retry →
// extract the deck JSON → return RawDraft.
public struct AnthropicProvider: LLMProvider {
    public let id: ProviderID = .anthropic
    public let displayName = "Anthropic"

    private let apiKey: String
    private let model: String
    private let http: HTTPRequestSender
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    public init(apiKey: String, model: String = "claude-sonnet-5", session: URLSession = ProviderNetworking.session) {
        self.apiKey = apiKey
        self.model = model
        self.http = { request in try await session.data(for: request) }
    }

    /// Test seam, matching the image providers: exercises the real
    /// request-building, retry and truncation handling without a key or a
    /// network. The comment above about needing a live key is now true only of
    /// the round-trip itself.
    init(apiKey: String, model: String = "claude-sonnet-5", send: @escaping HTTPRequestSender) {
        self.apiKey = apiKey; self.model = model; self.http = send
    }

    /// The output ceiling a deck of this size needs.
    ///
    /// This was the constant 8,192 whatever was asked for. `PriceTable` already
    /// calibrates a slide at ~180 output tokens, so 40 — the ceiling the UI's
    /// stepper offers — is 7,200 before speaker notes, inside the old limit only
    /// by accident. With notes it is well past it, and the deck came back short
    /// with nothing anywhere saying so.
    ///
    /// Half again on top of the estimate, because an estimate that is right on
    /// average truncates half the time. Floored at the old constant so no
    /// request gets less room than it used to, and capped because a model asked
    /// for more than it supports rejects the call outright — `send` recovers
    /// from that, but it is better not to provoke it.
    ///
    /// Kept here as the name the tests know; the arithmetic is about the size
    /// of a deck rather than about Anthropic, so it lives in `DeckOutputBudget`
    /// where a second provider can use it without reaching across.
    static func outputTokenBudget(for request: DeckRequest) -> Int {
        DeckOutputBudget.tokens(for: request)
    }

    static let floorOutputTokens = DeckOutputBudget.floor
    static let maxOutputTokens = DeckOutputBudget.ceiling

    public func draft(_ request: DeckRequest, repairing: RepairContext?,
                      emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        emit(.preparingSource)
        emit(.outlining)

        let system = PromptTemplates.system(for: request)
        let user = repairing.map { RepairPrompt.make(invalidJSON: $0.invalidJSON, errors: $0.errors) }
            ?? PromptTemplates.deck(for: request)

        // Force tool-use so the response is a deck object matching the schema —
        // eliminates prose/fence/shape drift and the "couldn't parse" failure.
        let tool: [String: Any] = [
            "name": "emit_deck",
            "description": "Return the finished slide deck as a \(DeckIR.currentVersion) object.",
            "input_schema": DeckSchema.inputSchema(),
        ]
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": Self.outputTokenBudget(for: request),
            "system": system,
            "messages": [["role": "user", "content": user]],
            "tools": [tool],
            "tool_choice": ["type": "tool", "name": "emit_deck"],
        ]

        emit(.drafting(completed: 0, total: request.slideCount))
        let (data, usage) = try await send(payload)
        try Self.rejectIfTruncated(data, request: request)
        let json = try extractDeckJSON(from: data)
        emit(.drafting(completed: request.slideCount, total: request.slideCount))
        return RawDraft(json: json, usage: usage)
    }

    /// QA pass: hand the draft to a ruthless-editor system prompt and get a
    /// stronger deck back through the same forced-schema tool.
    public func revise(_ request: DeckRequest, deckJSON: String,
                       emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        let tool: [String: Any] = [
            "name": "emit_deck",
            "description": "Return the improved slide deck as a \(DeckIR.currentVersion) object.",
            "input_schema": DeckSchema.inputSchema(),
        ]
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": Self.outputTokenBudget(for: request),
            "system": PromptTemplates.editorSystem(for: request),
            "messages": [["role": "user", "content": PromptTemplates.editorUser(deckJSON: deckJSON, request: request)]],
            "tools": [tool],
            "tool_choice": ["type": "tool", "name": "emit_deck"],
        ]
        let (data, usage) = try await send(payload)
        // A truncated revision is thrown away rather than adopted: the caller
        // treats a failed QA pass as "keep the draft", which is the right
        // outcome for half an edit.
        try Self.rejectIfTruncated(data, request: request)
        return RawDraft(json: try extractDeckJSON(from: data), usage: usage)
    }

    /// Refuse a response the model stopped writing because it ran out of room.
    ///
    /// With tool use forced, a cut-off answer still arrives as a well-formed
    /// object — just one with fewer slides than were asked for, or a slide
    /// missing its notes. Nothing downstream can tell that from a complete
    /// deck: the validator's slide-count check catches some of it and reports
    /// it as a schema violation, which sends the one repair attempt after a
    /// defect the model did not make. Naming it here is the difference between
    /// "ask for fewer slides" and a deck that is quietly short.
    static func rejectIfTruncated(_ data: Data, request: DeckRequest) throws {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["stop_reason"] as? String == "max_tokens" else { return }
        throw LecternError.responseTruncated(slideCount: request.slideCount)
    }

    /// POST, retrying rate limits, server faults and dropped connections on the
    /// shared schedule in `HTTPRetry`. Auth failures and other 4xx are final —
    /// asking again cannot change the answer.
    ///
    /// A model that refuses the requested output budget is retried once at the
    /// floor. That is a different request rather than another go at the same
    /// one, so it does not spend an attempt.
    private func send(_ payload: [String: Any]) async throws -> (Data, Usage) {
        var payload = payload
        var attempt = 0
        var loweredBudget = false
        // Bounds the whole call, not each attempt. Three 120-second timeouts
        // plus backoff is over six minutes of a UI that looks hung.
        let startedAt = Date()
        while true {
            // The deadline is only real if a request cannot outlive it. An
            // attempt that starts late gets what is left, not a fresh 120.
            guard let timeout = HTTPRetry.timeout(startedAt: startedAt, cap: 120) else {
                throw LecternError.providerError(
                    status: 0, message: "the request ran out of time before it could finish")
            }
            var req = URLRequest(url: endpoint, timeoutInterval: timeout)
            req.httpMethod = "POST"
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")           // never logged (I1)
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let data: Data, response: URLResponse
            do {
                (data, response) = try await http(req)
            } catch let error as URLError where error.code == .notConnectedToInternet {
                throw LecternError.networkOffline
            } catch let error as URLError where HTTPRetry.isRetriable(error) {
                // A dropped or timed-out connection says nothing about the
                // request. This used to end the run: the longest, most
                // expensive call in the product threw away a paid generation
                // because one socket died.
                let wait = HTTPRetry.backoff(attempt: attempt, retryAfter: nil)
                guard attempt + 1 < HTTPRetry.maxAttempts,
                      HTTPRetry.hasTimeToRetry(startedAt: startedAt, nextWait: wait) else {
                    throw LecternError.providerError(status: 0, message: error.localizedDescription)
                }
                try await HTTPRetry.wait(seconds: wait)
                attempt += 1
                continue
            }

            guard let http = response as? HTTPURLResponse else { throw LecternError.providerError(status: 0, message: "no response") }
            switch http.statusCode {
            case 200:
                return (data, parseUsage(data))
            case 401, 403:
                throw LecternError.authFailed(provider: displayName)
            case 400 where !loweredBudget && rejectsOutputBudget(data):
                // This model's ceiling is below what the deck asked for. Drop to
                // the budget every model accepts rather than failing the run;
                // if the deck no longer fits, the truncation check says so in
                // words the user can act on.
                loweredBudget = true
                payload["max_tokens"] = Self.floorOutputTokens
                continue
            case let status where HTTPRetry.isRetriable(status: status):
                let retryAfter = HTTPRetry.retryAfterSeconds(http)
                let wait = HTTPRetry.backoff(attempt: attempt, retryAfter: retryAfter)
                if attempt + 1 < HTTPRetry.maxAttempts,
                   HTTPRetry.hasTimeToRetry(startedAt: startedAt, nextWait: wait) {
                    try await HTTPRetry.wait(seconds: wait)
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

    /// A 400 specifically about `max_tokens` exceeding what the model allows,
    /// rather than any other bad request. Anthropic names the field in the
    /// message, which is the only thing distinguishing it from a real defect.
    private func rejectsOutputBudget(_ data: Data) -> Bool {
        message(data).lowercased().contains("max_tokens")
    }

    private func parseUsage(_ data: Data) -> Usage {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let usage = obj["usage"] as? [String: Any] else { return Usage() }
        return Usage(inputTokens: usage["input_tokens"] as? Int ?? 0,
                     outputTokens: usage["output_tokens"] as? Int ?? 0)
    }

    private func message(_ data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? [String: Any], let m = err["message"] as? String else { return "provider error" }
        return m
    }

    /// Pull the deck JSON out of the forced `tool_use` block (with a text-JSON
    /// fallback in case the model ever answers in prose).
    private func extractDeckJSON(from data: Data) throws -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]] else {
            throw LecternError.providerError(status: 200, message: "unexpected response shape")
        }
        if let toolUse = content.first(where: { ($0["type"] as? String) == "tool_use" }),
           let input = toolUse["input"], JSONSerialization.isValidJSONObject(input),
           let jsonData = try? JSONSerialization.data(withJSONObject: input) {
            return String(decoding: jsonData, as: UTF8.self)
        }
        let text = content.compactMap { $0["text"] as? String }.joined()
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end {
            return String(text[start...end])
        }
        throw LecternError.schemaInvalid(errors: ["model returned no deck object"])
    }
}
