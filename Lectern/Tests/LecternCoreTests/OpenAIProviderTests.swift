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
        let attempts = AttemptCounter(), waits = IntervalLog(), seen = SentRequest()
        let start = Date(timeIntervalSince1970: 0)
        let budget = ReasoningEffort.medium.timeout
        let provider = OpenAIProvider(apiKey: "k",
            now: { start.addingTimeInterval(waits.values.reduce(0, +)) },
            wait: { seconds in
                // 2 s +/-25 %, kept at sub-second resolution.
                #expect(seconds >= 1.5 && seconds <= 2.5)
                waits.record(seconds)
            }, send: { request in
            seen.record(request)
            if attempts.next() == 1 {
                #expect(request.timeoutInterval == budget)
                return (Data(), Self.http(500))
            }
            return (Data(self.response(deck: self.deck).utf8), Self.http(200))
        })

        let draft = try await provider.draft(DeckRequest(prompt: "x"), repairing: nil) { _ in }

        #expect(draft.json.contains("\"title\""))
        #expect(attempts.count == 2)
        #expect(waits.values.count == 1)
        // The second attempt's timeout shrinks by the jittered wait, to within
        // the ~1e-7 s that `Date` arithmetic in the stub clock carries.
        let second = try #require(seen.value?.timeoutInterval)
        #expect(abs(second - (budget - waits.values[0])) < 1e-6)
    }

    /// A persistent 429 without Retry-After names the wait it last computed,
    /// rounded up, rather than drawing a fresh jittered value for the hint.
    @Test func aPersistentRateLimitHintReusesTheComputedWait() async throws {
        let attempts = AttemptCounter(), waits = IntervalLog()
        let provider = OpenAIProvider(apiKey: "k",
            now: { Date(timeIntervalSince1970: 0) },
            wait: { waits.record($0) }, send: { _ in
                _ = attempts.next()
                return (Data(), Self.http(429))
            })
        do {
            _ = try await provider.draft(DeckRequest(prompt: "x"), repairing: nil) { _ in }
            Issue.record("a persistent rate limit must surface")
        } catch LecternError.rateLimited(let afterSeconds) {
            // Two waits slept (attempts 0 and 1); the hint is attempt 2's
            // 8 s +/-25 %, rounded up to whole seconds.
            #expect(attempts.count == HTTPRetry.maxAttempts)
            #expect(waits.values.count == 2)
            #expect((6...10).contains(afterSeconds), "hint was \(afterSeconds)s")
        }
    }
}

/// Small thread-safe boxes so a `@Sendable` stub can report what it saw.
final class SentRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: URLRequest?
    var value: URLRequest? { lock.lock(); defer { lock.unlock() }; return stored }
    func record(_ request: URLRequest) { lock.lock(); stored = request; lock.unlock() }
}

/// Every wait (or timeout) a `@Sendable` stub saw, in order, at full
/// sub-second resolution.
final class IntervalLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [TimeInterval] = []
    var values: [TimeInterval] { lock.lock(); defer { lock.unlock() }; return stored }
    func record(_ value: TimeInterval) { lock.lock(); stored.append(value); lock.unlock() }
}

final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return n }
    func next() -> Int { lock.lock(); defer { lock.unlock() }; n += 1; return n }
}
