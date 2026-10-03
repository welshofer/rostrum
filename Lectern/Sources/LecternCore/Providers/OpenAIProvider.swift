import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // URLSession/URLRequest/HTTPURLResponse live here on Linux
#endif

/// Deck generation through the Responses API, using a forced emit_deck call.
/// The selected model and reasoning effort are shared by draft, repair and QA.
public struct OpenAIProvider: LLMProvider {
    public let id: ProviderID = .openAI
    public let displayName = "OpenAI"

    private let apiKey: String
    private let model: String
    private let effort: ReasoningEffort
    private let http: HTTPRequestSender
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    public init(apiKey: String,
                model: String = TextStrength.sol.modelID,
                effort: ReasoningEffort = .medium,
                session: URLSession = ProviderNetworking.session) {
        self.apiKey = apiKey
        self.model = model
        self.effort = TextStrength.resolve(modelID: model).supported(effort)
        self.http = { request in try await session.data(for: request) }
    }

    /// Test seam, matching the other providers: exercises real request-building,
    /// retry and truncation handling without a key or a network.
    init(apiKey: String, model: String = TextStrength.sol.modelID,
                effort: ReasoningEffort = .medium, send: @escaping HTTPRequestSender) {
        self.apiKey = apiKey; self.model = model; self.http = send
        self.effort = TextStrength.resolve(modelID: model).supported(effort)
    }

    // MARK: - Drafting

    public func draft(_ request: DeckRequest, repairing: RepairContext?,
                      emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        emit(.preparingSource)
        emit(.outlining)

        let user = repairing.map { PromptTemplates.repair(for: request, context: $0) }
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
            "store": false,
            "max_output_tokens": DeckOutputBudget.tokens(for: request) + effort.tokenAllowance,
            "reasoning": ["effort": effort.rawValue],
            "instructions": system,
            "input": [["role": "user", "content": user]],
            "tools": [[
                "type": "function", "name": "emit_deck",
                "description": toolDescription,
                "parameters": DeckSchema.inputSchema(),
                // Keep the existing optional-field IR. The validator and one-shot
                // repair remain the authority for structural correctness.
                "strict": false,
            ]],
            "parallel_tool_calls": false,
            "tool_choice": ["type": "function", "name": "emit_deck"],
        ]
    }

    static func rejectIfTruncated(_ data: Data, request: DeckRequest) throws {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if obj["status"] as? String == "incomplete" {
            let reason = (obj["incomplete_details"] as? [String: Any])?["reason"] as? String
            if reason == "max_output_tokens" {
                throw LecternError.responseTruncated(slideCount: request.slideCount)
            }
            throw LecternError.providerError(status: 200, message: "OpenAI could not complete the deck (\(reason ?? "incomplete response")).")
        }
    }

    private func extractDeckJSON(from data: Data) throws -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["status"] as? String == "completed",
              let output = obj["output"] as? [[String: Any]] else {
            throw LecternError.providerError(status: 200, message: "OpenAI did not return a completed response")
        }
        // Reasoning and message items may precede the function call.
        let calls = output.filter { $0["type"] as? String == "function_call" }
        guard calls.count == 1, let call = calls.first, call["name"] as? String == "emit_deck",
              call["status"] as? String == "completed",
              let arguments = call["arguments"] as? String, !arguments.isEmpty else {
            let refused = output.contains { item in
                (item["content"] as? [[String: Any]])?.contains { $0["type"] as? String == "refusal" } == true
            }
            throw LecternError.providerError(status: 200, message: refused
                ? "OpenAI declined this deck request."
                : "OpenAI did not return the requested deck function call.")
        }
        return arguments
    }

    private func parseUsage(_ data: Data) -> Usage {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let usage = obj["usage"] as? [String: Any] else { return Usage() }
        return Usage(inputTokens: usage["input_tokens"] as? Int ?? 0,
                     outputTokens: usage["output_tokens"] as? Int ?? 0)
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
            try Task.checkCancellation()
            guard let timeout = HTTPRetry.timeout(startedAt: startedAt, cap: effort.timeout, deadline: effort.timeout) else {
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
                      HTTPRetry.hasTimeToRetry(startedAt: startedAt, nextWait: wait, deadline: effort.timeout) else {
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
                   HTTPRetry.hasTimeToRetry(startedAt: startedAt, nextWait: wait, deadline: effort.timeout) {
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
