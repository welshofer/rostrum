import Foundation
import Testing
@testable import LecternCore

/// The provider the Settings picker has offered since the first release while
/// throwing "isn't wired up yet" on every press.
///
/// Exercised through the same seam as the Anthropic one: real request-building,
/// real retry and truncation handling, a stubbed wire.
@Suite struct OpenAIProviderTests {
    private static func http(_ status: Int, headers: [String: String]? = nil) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.openai.com/v1/chat/completions")!,
                        statusCode: status, httpVersion: nil, headerFields: headers)!
    }

    /// A chat-completions answer carrying `deck` as the forced call's arguments.
    ///
    /// `arguments` is a JSON *string* containing the deck, not an object — the
    /// one real difference from Anthropic's shape, so the helper has to encode
    /// it as a fragment rather than hand JSONSerialization a bare String.
    private func response(finish: String = "tool_calls", deck: String) -> String {
        let encoded = try! JSONSerialization.data(withJSONObject: deck,
                                                  options: [.fragmentsAllowed])
        let arguments = String(data: encoded, encoding: .utf8)!
        return """
        {"choices":[{"finish_reason":"\(finish)","message":{"tool_calls":[
          {"type":"function","function":{"name":"emit_deck","arguments":\(arguments)}}]}}],
         "usage":{"prompt_tokens":120,"completion_tokens":340}}
        """
    }

    private let deck = #"{"meta":{"title":"T"},"slides":[]}"#

    @Test func theFactoryNowBuildsIt() throws {
        #expect(ProviderFactory.isWired(.openAI))
        let provider = try ProviderFactory.make(id: .openAI, apiKey: "sk-test", model: "gpt-5.2")
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
        let provider = OpenAIProvider(apiKey: "sk-secret", model: "gpt-5.2", send: { request in
            seen.record(request)
            return (Data(self.response(deck: self.deck).utf8), Self.http(200))
        })

        _ = try await provider.draft(DeckRequest(prompt: "x", slideCount: 8), repairing: nil) { _ in }

        let request = try #require(seen.value)
        #expect(request.url?.host == "api.openai.com")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-secret")
        let httpBody = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        #expect(body["model"] as? String == "gpt-5.2")
        // `max_tokens` is rejected outright by current models rather than ignored.
        #expect(body["max_completion_tokens"] != nil)
        #expect(body["max_tokens"] == nil)
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages.first?["role"] == "system")
        #expect(messages.last?["role"] == "user")
        let choice = try #require(body["tool_choice"] as? [String: Any])
        #expect((choice["function"] as? [String: Any])?["name"] as? String == "emit_deck")
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
            let body = #"{"choices":[{"finish_reason":"stop","message":{"content":"Here is a deck!"}}]}"#
            return (Data(body.utf8), Self.http(200))
        })

        await #expect(throws: LecternError.providerError(
            status: 200, message: "the model replied with text instead of a deck")) {
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
