import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // URLSession/URLRequest/HTTPURLResponse live here on Linux
#endif
import Testing
@testable import LecternCore

/// Responses API wire contract and failure handling.
@Suite struct OpenAIProviderTests {
    private static func http(_ status: Int, headers: [String: String]? = nil) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.openai.com/v1/responses")!,
                        statusCode: status, httpVersion: nil, headerFields: headers)!
    }

    private func response(finish: String = "tool_calls", deck: String) -> String {
        let body: [String: Any] = [
            "status": finish == "length" ? "incomplete" : "completed",
            "incomplete_details": ["reason": "max_output_tokens"],
            "output": [["type": "reasoning"],
                       ["type": "function_call", "name": "emit_deck", "status": "completed", "arguments": deck]],
            "usage": ["input_tokens": 120, "output_tokens": 340],
        ]
        return String(decoding: try! JSONSerialization.data(withJSONObject: body), as: UTF8.self)
    }

    private let deck = #"{"meta":{"title":"T"},"slides":[]}"#

    @Test func theFactoryNowBuildsIt() throws {
        #expect(ProviderFactory.isWired(.openAI))
        let provider = try ProviderFactory.make(id: .openAI, apiKey: "sk-test", model: TextStrength.sol.modelID)
        #expect(provider.id == .openAI)
        #expect(provider.displayName == "OpenAI")
    }

    @Test func geminiAndCustomStillSayWhatTheyAre() {
        #expect(!ProviderFactory.isWired(.gemini))
        #expect(!ProviderFactory.isWired(.custom))
    }

    @Test func aDraftComesBackAsTheForcedCallsArguments() async throws {
        let provider = OpenAIProvider(apiKey: "k", send: { _ in
            (Data(self.response(deck: self.deck).utf8), Self.http(200))
        })

        let draft = try await provider.draft(DeckRequest(prompt: "x"), repairing: nil) { _ in }

        #expect(draft.json.contains("\"title\""))
        #expect(draft.usage == Usage(inputTokens: 120, outputTokens: 340))
    }

    /// The request has to be shaped the way OpenAI expects, not the way
    /// Anthropic does — this is the part a live key would otherwise be the
    /// first to tell us about.
    @Test func theRequestIsShapedForOpenAI() async throws {
        let seen = SentRequest()
        let provider = OpenAIProvider(apiKey: "sk-secret", model: TextStrength.sol.modelID, send: { request in
            seen.record(request)
            return (Data(self.response(deck: self.deck).utf8), Self.http(200))
        })

        _ = try await provider.draft(DeckRequest(prompt: "x", slideCount: 8), repairing: nil) { _ in }

        let request = try #require(seen.value)
        #expect(request.url?.host == "api.openai.com")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-secret")
        let httpBody = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        #expect(body["model"] as? String == TextStrength.sol.modelID)
        // `max_tokens` is rejected outright by current models rather than ignored.
        #expect(body["max_output_tokens"] != nil)
        #expect(body["max_tokens"] == nil)
        #expect(request.url?.path == "/v1/responses")
        #expect(body["store"] as? Bool == false)
        #expect(body["instructions"] is String)
        let input = try #require(body["input"] as? [[String: String]])
        #expect(input.first?["role"] == "user")
        #expect(body["messages"] == nil)
        #expect(body["temperature"] == nil)
        #expect((body["reasoning"] as? [String: String])?["effort"] == "medium")
        let choice = try #require(body["tool_choice"] as? [String: Any])
        #expect(choice["name"] as? String == "emit_deck")
        #expect((body["tools"] as? [[String: Any]])?.first?["strict"] as? Bool == false)
        #expect(body["parallel_tool_calls"] as? Bool == false)

    }

    /// Same trap as Anthropic's: a cut-off answer still decodes, so a short
    /// deck is otherwise indistinguishable from a finished one.
    @Test func aTruncatedDraftIsReportedNotReturnedShort() async throws {
        let provider = OpenAIProvider(apiKey: "k", send: { _ in
            (Data(self.response(finish: "length", deck: self.deck).utf8), Self.http(200))
        })

        await #expect(throws: LecternError.responseTruncated(slideCount: 12)) {
            _ = try await provider.draft(DeckRequest(prompt: "x", slideCount: 12),
                                         repairing: nil) { _ in }
        }
    }

    @Test func aBadKeyIsAnAuthFailureNotAGenericError() async {
        let provider = OpenAIProvider(apiKey: "k", send: { _ in
            (Data(#"{"error":{"message":"Incorrect API key"}}"#.utf8), Self.http(401))
        })

        await #expect(throws: LecternError.authFailed(provider: "OpenAI")) {
            _ = try await provider.draft(DeckRequest(prompt: "x"), repairing: nil) { _ in }
        }
    }

    /// A model that answers in prose despite the forced call should say so,
    /// rather than surfacing as "unexpected response shape".
    @Test func proseInsteadOfADeckIsNamed() async {
        let provider = OpenAIProvider(apiKey: "k", send: { _ in
            let body = #"{"status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"Here is a deck!"}]}]}"#
            return (Data(body.utf8), Self.http(200))
        })

        await #expect(throws: LecternError.providerError(
            status: 200, message: "OpenAI did not return the requested deck function call.")) {
            _ = try await provider.draft(DeckRequest(prompt: "x"), repairing: nil) { _ in }
        }
    }

    @Test func aServerFaultIsRetriedRatherThanEndingTheDraft() async throws {
        let attempts = AttemptCounter()
        let provider = OpenAIProvider(apiKey: "k", send: { _ in
            if attempts.next() == 1 { return (Data(), Self.http(500)) }
            return (Data(self.response(deck: self.deck).utf8), Self.http(200))
        })

        let draft = try await provider.draft(DeckRequest(prompt: "x"), repairing: nil) { _ in }

        #expect(draft.json.contains("\"title\""))
        #expect(attempts.count == 2)
    }
}

/// Small thread-safe boxes so a `@Sendable` stub can report what it saw.
final class SentRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: URLRequest?
    var value: URLRequest? { lock.lock(); defer { lock.unlock() }; return stored }
    func record(_ request: URLRequest) { lock.lock(); stored = request; lock.unlock() }
}

final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return n }
    func next() -> Int { lock.lock(); defer { lock.unlock() }; n += 1; return n }
}
