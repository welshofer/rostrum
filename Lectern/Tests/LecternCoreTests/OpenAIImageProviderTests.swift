import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // URLSession/URLRequest/HTTPURLResponse live here on Linux
#endif
import Testing
@testable import LecternCore

/// Image retry and deadline handling. One stuck image used to hold a
/// generation for over an hour: nested status and transport loops allowed nine
/// 600-second attempts and never looked at the clock.
@Suite struct OpenAIImageProviderTests {
    private static func http(_ status: Int, headers: [String: String]? = nil) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.openai.com/v1/images/generations")!,
                        statusCode: status, httpVersion: nil, headerFields: headers)!
    }

    private static let image = Data(#"{"data":[{"b64_json":"aW1hZ2U="}]}"#.utf8)

    private static func generate(_ provider: OpenAIImageProvider) async throws -> Data {
        try await provider.image(prompt: "A tree", style: nil, aspect: .wide, role: .background)
    }

    /// A connection that never answers is retried, but ONE counter covers the
    /// whole call: three attempts, not three times three.
    @Test func aTransportFailureGivesUpAfterThreeAttempts() async throws {
        let attempts = AttemptCounter(), waits = AttemptCounter()
        let clock = ImageTestClock()
        let provider = OpenAIImageProvider(apiKey: "k",
            now: { clock.now },
            wait: { _ in _ = waits.next() },
            send: { _ in
                _ = attempts.next()
                throw URLError(.timedOut)
            })

        await #expect(throws: URLError(.timedOut)) {
            _ = try await Self.generate(provider)
        }
        #expect(attempts.count == HTTPRetry.maxAttempts)
        #expect(attempts.count == 3)
        #expect(waits.count == 2)
    }

    @Test func aRateLimitIsRetriedOnceThenTheImageReturns() async throws {
        let attempts = AttemptCounter(), waits = IntervalLog()
        let clock = ImageTestClock()
        let provider = OpenAIImageProvider(apiKey: "k",
            now: { clock.now },
            wait: { seconds in
                // 2 s +/-25 %, kept at sub-second resolution.
                #expect(seconds >= 1.5 && seconds <= 2.5)
                waits.record(seconds)
                clock.advance(by: seconds)
            },
            send: { _ in
                if attempts.next() == 1 { return (Data(), Self.http(429)) }
                return (Self.image, Self.http(200))
            })

        let bytes = try await Self.generate(provider)

        #expect(bytes == Data("image".utf8))
        #expect(attempts.count == 2)
        #expect(waits.values.count == 1)
    }

    /// Past the deadline nothing new starts, and the user sees what actually
    /// went wrong rather than a synthetic "ran out of time".
    @Test func noAttemptStartsPastTheDeadlineAfterATransportFailure() async throws {
        let attempts = AttemptCounter(), waits = AttemptCounter()
        let clock = ImageTestClock()
        let provider = OpenAIImageProvider(apiKey: "k",
            now: { clock.now },
            wait: { _ in _ = waits.next() },
            send: { _ in
                _ = attempts.next()
                clock.advance(by: OpenAIImageProvider.imageDeadline + 1)
                throw URLError(.networkConnectionLost)
            })

        await #expect(throws: URLError(.networkConnectionLost)) {
            _ = try await Self.generate(provider)
        }
        #expect(attempts.count == 1)
        #expect(waits.count == 0)
    }

    @Test func noAttemptStartsPastTheDeadlineAfterAServerFault() async throws {
        let attempts = AttemptCounter(), waits = AttemptCounter()
        let clock = ImageTestClock()
        let provider = OpenAIImageProvider(apiKey: "k",
            now: { clock.now },
            wait: { _ in _ = waits.next() },
            send: { _ in
                _ = attempts.next()
                clock.advance(by: OpenAIImageProvider.imageDeadline + 1)
                return (Data(#"{"error":{"message":"upstream overloaded"}}"#.utf8), Self.http(503))
            })

        await #expect(throws: LecternError.providerError(status: 503, message: "upstream overloaded")) {
            _ = try await Self.generate(provider)
        }
        #expect(attempts.count == 1)
        #expect(waits.count == 0)
    }

    /// A retry late in the budget is still allowed, but cannot outlive the
    /// deadline it was allowed under: its timeout shrinks to the time left.
    @Test func eachAttemptsTimeoutShrinksAsTheDeadlineApproaches() async throws {
        let log = ImageRequestLog(), waits = IntervalLog()
        let clock = ImageTestClock()
        let provider = OpenAIImageProvider(apiKey: "k",
            now: { clock.now },
            wait: { seconds in
                waits.record(seconds)
                clock.advance(by: seconds)
            },
            send: { request in
                log.record(request)
                // Each attempt hangs for its whole timeout, then fails.
                clock.advance(by: request.timeoutInterval)
                throw URLError(.timedOut)
            })

        await #expect(throws: URLError(.timedOut)) {
            _ = try await Self.generate(provider)
        }

        let timeouts = log.requests.map(\.timeoutInterval)
        // 600 s first; then 900 − (600 + ~2 s jittered backoff) ≈ 298 s; then
        // the budget is spent, so there is no third attempt at all.
        #expect(timeouts.count == 2)
        #expect(timeouts.first == OpenAIImageProvider.attemptTimeout)
        #expect(timeouts[1] < 600)
        #expect(waits.values.count == 1)
        let backoff = try #require(waits.values.first)
        #expect(backoff >= 1.5 && backoff <= 2.5)
        // Within a microsecond: the stub clock is `Date` arithmetic, which
        // carries fractional seconds to about 1e-7 s.
        let expected = OpenAIImageProvider.imageDeadline - OpenAIImageProvider.attemptTimeout - backoff
        #expect(abs(timeouts[1] - expected) < 1e-6, "second timeout \(timeouts[1]), expected \(expected)")
        // The whole call stayed inside the image deadline.
        #expect(clock.now.timeIntervalSince(ImageTestClock.start) <= OpenAIImageProvider.imageDeadline)
    }

    @Test func authFailuresAreNotRetried() async throws {
        let attempts = AttemptCounter()
        let provider = OpenAIImageProvider(apiKey: "k",
            wait: { _ in Issue.record("an auth failure must not be retried") },
            send: { _ in
                _ = attempts.next()
                return (Data(), Self.http(401))
            })

        await #expect(throws: LecternError.authFailed(provider: "OpenAI")) {
            _ = try await Self.generate(provider)
        }
        #expect(attempts.count == 1)
    }

    @Test func aPersistentRateLimitIsNamedAfterThreeAttempts() async throws {
        let attempts = AttemptCounter()
        let provider = OpenAIImageProvider(apiKey: "k",
            now: { ImageTestClock.start },
            wait: { _ in },
            send: { _ in
                _ = attempts.next()
                return (Data(), Self.http(429, headers: ["Retry-After": "7"]))
            })

        await #expect(throws: LecternError.rateLimited(afterSeconds: 7)) {
            _ = try await Self.generate(provider)
        }
        #expect(attempts.count == 3)
    }

    /// Without Retry-After the hint is the jittered wait computed for the
    /// final 429, rounded up — not a second, independent draw.
    @Test func aPersistentRateLimitHintReusesTheComputedWait() async throws {
        let attempts = AttemptCounter(), waits = IntervalLog()
        let provider = OpenAIImageProvider(apiKey: "k",
            now: { ImageTestClock.start },
            wait: { waits.record($0) },
            send: { _ in
                _ = attempts.next()
                return (Data(), Self.http(429))
            })
        do {
            _ = try await Self.generate(provider)
            Issue.record("a persistent rate limit must surface")
        } catch LecternError.rateLimited(let afterSeconds) {
            #expect(attempts.count == 3)
            #expect(waits.values.count == 2)
            // Attempt 2's 8 s +/-25 %, rounded up to whole seconds.
            #expect((6...10).contains(afterSeconds), "hint was \(afterSeconds)s")
        }
    }
}

/// A controllable clock for `@Sendable` closures.
final class ImageTestClock: @unchecked Sendable {
    static let start = Date(timeIntervalSince1970: 1_000_000)
    private let lock = NSLock()
    private var current = ImageTestClock.start
    var now: Date { lock.lock(); defer { lock.unlock() }; return current }
    func advance(by seconds: TimeInterval) { lock.lock(); current += seconds; lock.unlock() }
}

/// Every request handed to the sender, in order.
final class ImageRequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [URLRequest] = []
    var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return stored }
    func record(_ request: URLRequest) { lock.lock(); stored.append(request); lock.unlock() }
}
