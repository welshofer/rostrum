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
    private let session: URLSession
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    public init(apiKey: String, model: String = "claude-sonnet-5", session: URLSession = .shared) {
        self.apiKey = apiKey; self.model = model; self.session = session
    }

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
            "max_tokens": 8192,
            "system": system,
            "messages": [["role": "user", "content": user]],
            "tools": [tool],
            "tool_choice": ["type": "tool", "name": "emit_deck"],
        ]

        emit(.drafting(completed: 0, total: request.slideCount))
        let (data, usage) = try await send(payload)
        let json = try extractDeckJSON(from: data)
        emit(.drafting(completed: request.slideCount, total: request.slideCount))
        return RawDraft(json: json, usage: usage)
    }

    /// POST with exactly one retry on 429/5xx (honoring Retry-After); no retry on
    /// 4xx auth errors (§7.6).
    private func send(_ payload: [String: Any]) async throws -> (Data, Usage) {
        for attempt in 0...1 {
            var req = URLRequest(url: endpoint, timeoutInterval: 120)
            req.httpMethod = "POST"
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")           // never logged (I1)
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let data: Data, response: URLResponse
            do { (data, response) = try await session.data(for: req) }
            catch let error as URLError where error.code == .notConnectedToInternet { throw LecternError.networkOffline }

            guard let http = response as? HTTPURLResponse else { throw LecternError.providerError(status: 0, message: "no response") }
            switch http.statusCode {
            case 200:
                return (data, parseUsage(data))
            case 401, 403:
                throw LecternError.authFailed(provider: displayName)
            case 429, 500...599:
                let retryAfter = Int(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 2
                if attempt == 0 { try? await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000); continue }
                if http.statusCode == 429 { throw LecternError.rateLimited(afterSeconds: retryAfter) }
                throw LecternError.providerError(status: http.statusCode, message: message(data))
            default:
                throw LecternError.providerError(status: http.statusCode, message: message(data))
            }
        }
        throw LecternError.providerError(status: 0, message: "unreachable")
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
