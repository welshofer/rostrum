import Foundation

/// Deck generation through OpenAI's chat completions API.
///
/// Structurally the same bargain as `AnthropicProvider`: the deck comes back
/// through a forced function call rather than as prose, so there is no fence
/// stripping, no "the model wrote a preamble" branch, and no shape drift. Only
/// the wire format differs — `tools`/`tool_choice` in OpenAI's spelling, a
/// bearer token instead of `x-api-key`, and `finish_reason` where Anthropic
/// says `stop_reason`.
///
/// The picker has offered this provider since the first release and it threw
/// `"openAI isn't wired up yet"` on every press.
public struct OpenAIProvider: LLMProvider {
    public let id: ProviderID = .openAI
    public let displayName = "OpenAI"

    private let apiKey: String
    private let model: String
    private let http: HTTPRequestSender
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    public init(apiKey: String,
                model: String = "gpt-5.2",
                session: URLSession = ProviderNetworking.session) {
        self.apiKey = apiKey
        self.model = model
        self.http = { request in try await session.data(for: request) }
    }

    /// Test seam, matching the other providers: exercises real request-building,
    /// retry and truncation handling without a key or a network.
    init(apiKey: String, model: String = "gpt-5.2", send: @escaping HTTPRequestSender) {
        self.apiKey = apiKey; self.model = model; self.http = send
    }

    // MARK: - Drafting

    public func draft(_ request: DeckRequest, repairing: RepairContext?,
                      emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        emit(.preparingSource)
        emit(.outlining)

        let user = repairing.map { RepairPrompt.make(invalidJSON: $0.invalidJSON, errors: $0.errors) }
            ?? PromptTemplates.deck(for: request)

        emit(.drafting(completed: 0, total: request.slideCount))
        let (data, usage) = try await send(payload(
            system: PromptTemplates.system(for: request),
            user: user,
            request: request,
            toolDescription: "Return the finished slide deck as a \(DeckIR.currentVersion) object."))
        try Self.rejectIfTruncated(data, request: request)
        let json = try extractDeckJSON(from: data)
        emit(.drafting(completed: request.slideCount, total: request.slideCount))
        return RawDraft(json: json, usage: usage)
    }

    public func revise(_ request: DeckRequest, deckJSON: String,
                       emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        let (data, usage) = try await send(payload(
            system: PromptTemplates.editorSystem(for: request),
            user: PromptTemplates.editorUser(deckJSON: deckJSON, request: request),
            request: request,
            toolDescription: "Return the improved slide deck as a \(DeckIR.currentVersion) object."))
        // A truncated revision is thrown away rather than adopted: the caller
        // treats a failed QA pass as "keep the draft", which is the right
        // outcome for half an edit.
        try Self.rejectIfTruncated(data, request: request)
        return RawDraft(json: try extractDeckJSON(from: data), usage: usage)
    }

    private func payload(system: String, user: String,
                         request: DeckRequest, toolDescription: String) -> [String: Any] {
        [
            "model": model,
            // OpenAI renamed this; the older `max_tokens` is rejected outright
            // by current models rather than ignored.
            "max_completion_tokens": DeckOutputBudget.tokens(for: request),
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "tools": [[
                "type": "function",
                "function": [
                    "name": "emit_deck",
                    "description": toolDescription,
                    "parameters": DeckSchema.inputSchema(),
                ],
            ]],
            "tool_choice": ["type": "function", "function": ["name": "emit_deck"]],
        ]
    }

    // MARK: - Reading the answer

    /// Refuse a response the model stopped writing because it ran out of room.
    ///
    /// The same trap as Anthropic's: with the call forced, a cut-off answer
    /// still arrives as a well-formed object, just one with fewer slides than
    /// were asked for. OpenAI spells it `finish_reason: "length"`.
    static func rejectIfTruncated(_ data: Data, request: DeckRequest) throws {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              choices.first?["finish_reason"] as? String == "length" else { return }
        throw LecternError.responseTruncated(slideCount: request.slideCount)
    }

    /// The deck is the function call's `arguments`, which is a JSON *string*
    /// rather than an object — the one real difference from Anthropic's shape.
    private func extractDeckJSON(from data: Data) throws -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else {
            throw LecternError.providerError(status: 200, message: "unexpected response shape")
        }
        if let calls = message["tool_calls"] as? [[String: Any]],
           let function = calls.first?["function"] as? [String: Any],
           let arguments = function["arguments"] as? String, !arguments.isEmpty {
            return arguments
        }
        // Forced tool choice makes this the abnormal path, but a model that
        // answers in prose anyway should say so in words rather than surface as
        // "unexpected response shape".
        if let content = message["content"] as? String, !content.isEmpty {
            throw LecternError.providerError(
                status: 200, message: "the model replied with text instead of a deck")
        }
        throw LecternError.providerError(status: 200, message: "no deck in the response")
    }

    private func parseUsage(_ data: Data) -> Usage {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let usage = obj["usage"] as? [String: Any] else { return Usage() }
        return Usage(inputTokens: usage["prompt_tokens"] as? Int ?? 0,
                     outputTokens: usage["completion_tokens"] as? Int ?? 0)
    }

    private func message(_ data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = obj["error"] as? [String: Any],
              let text = error["message"] as? String else {
            return String(data: data, encoding: .utf8) ?? "unreadable error"
        }
        return text
    }

    // MARK: - Sending

    /// POST, retrying rate limits, server faults and dropped connections on the
    /// shared schedule in `HTTPRetry`. Auth failures and other 4xx are final —
    /// asking again cannot change the answer.
    private func send(_ payload: [String: Any]) async throws -> (Data, Usage) {
        var attempt = 0
        let startedAt = Date()
        while true {
            guard let timeout = HTTPRetry.timeout(startedAt: startedAt, cap: 120) else {
                throw LecternError.providerError(
                    status: 0, message: "the request ran out of time before it could finish")
            }
            var req = URLRequest(url: endpoint, timeoutInterval: timeout)
            req.httpMethod = "POST"
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")  // never logged (I1)
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let data: Data, response: URLResponse
            do {
                (data, response) = try await http(req)
            } catch let error as URLError where error.code == .notConnectedToInternet {
                throw LecternError.networkOffline
            } catch let error as URLError where HTTPRetry.isRetriable(error) {
                let wait = HTTPRetry.backoff(attempt: attempt, retryAfter: nil)
                guard attempt + 1 < HTTPRetry.maxAttempts,
                      HTTPRetry.hasTimeToRetry(startedAt: startedAt, nextWait: wait) else {
                    throw LecternError.providerError(status: 0, message: error.localizedDescription)
                }
                try await HTTPRetry.wait(seconds: wait)
                attempt += 1
                continue
            }

            guard let http = response as? HTTPURLResponse else {
                throw LecternError.providerError(status: 0, message: "no response")
            }
            switch http.statusCode {
            case 200:
                return (data, parseUsage(data))
            case 401, 403:
                throw LecternError.authFailed(provider: displayName)
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
}
