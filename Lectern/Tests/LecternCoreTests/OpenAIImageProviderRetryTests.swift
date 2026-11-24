import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import LecternCore

/// Retry budget and overall-deadline checks for `OpenAIImageProvider`.
@Suite struct OpenAIImageProviderRetryTests {
    private static func http(_ status: Int, headers: [String: String]? = nil) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.openai.com/v1/images/generations")!,
                        statusCode: status, httpVersion: nil, headerFields: headers)!
    }

    private final class FakeClock: @unchecked Sendable {
        private let lock = NSLock()
        private var current: Date
        init(_ start: Date = Date(timeIntervalSince1970: 0)) { self.current = start }
        var now: Date { lock.lock(); defer { lock.unlock() }; return current }
        func advance(by seconds: TimeInterval) {
            lock.lock(); defer { lock.unlock() }
            current = current.addingTimeInterval(seconds)
        }
    }

    private final class RecordedTimeouts: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [TimeInterval] = []
        var all: [TimeInterval] { lock.lock(); defer { lock.unlock() }; return values }
        func append(_ timeout: TimeInterval) {
            lock.lock(); defer { lock.unlock() }
            values.append(timeout)
        }
    }

    @Test func alternatingRateLimitsAndTimeoutsShareOneRetryBudget() async {
        let clock = FakeClock()
        let attempts = AttemptCounter()
        let waits = AttemptCounter()
        let timeouts = RecordedTimeouts()
        let deadline = OpenAIImageProvider.imageDeadline

        let provider = OpenAIImageProvider(
            apiKey: "k",
            now: { clock.now },
            wait: { seconds in
                _ = waits.next()
                clock.advance(by: TimeInterval(seconds))
            },
            send: { request in
                timeouts.append(request.timeoutInterval)
                let n = attempts.next()
                clock.advance(by: 50)
                if n % 2 == 1 {
                    return (Data(), Self.http(429, headers: ["Retry-After": "10"]))
                }
                throw URLError(.timedOut)
            }
        )

        await #expect(throws: LecternError.self) {
            _ = try await provider.image(prompt: "A bridge", style: nil, aspect: .wide, role: .background)
        }
        #expect(attempts.count == HTTPRetry.maxAttempts)
        #expect(waits.count == HTTPRetry.maxAttempts - 1)
        // First attempt gets the full deadline; subsequent attempts clamp to
        // what remains after prior request time and backoff waits.
        #expect(timeouts.all == [deadline, deadline - 60, deadline - 114])
    }

    @Test func exhaustedDeadlinePreventsWaitingOrSendingAnotherAttempt() async {
        let clock = FakeClock()
        let attempts = AttemptCounter()
        let waits = AttemptCounter()
        let deadline = OpenAIImageProvider.imageDeadline

        let provider = OpenAIImageProvider(
            apiKey: "k",
            now: { clock.now },
            wait: { seconds in
                _ = waits.next()
                clock.advance(by: TimeInterval(seconds))
            },
            send: { request in
                #expect(request.timeoutInterval == deadline)
                _ = attempts.next()
                // Simulate a single hung request consuming almost the entire deadline.
                clock.advance(by: deadline - 1)
                throw URLError(.timedOut)
            }
        )

        await #expect(throws: LecternError.self) {
            _ = try await provider.image(prompt: "A bridge", style: nil, aspect: .wide, role: .background)
        }
        #expect(attempts.count == 1)
        #expect(waits.count == 0)
    }

    @Test func retriesTransientTimeoutAndSucceedsWithClampedTimeout() async throws {
        let clock = FakeClock()
        let attempts = AttemptCounter()
        let waits = AttemptCounter()
        let timeouts = RecordedTimeouts()
        let deadline = OpenAIImageProvider.imageDeadline

        let provider = OpenAIImageProvider(
            apiKey: "k",
            now: { clock.now },
            wait: { seconds in
                #expect(seconds == 2)
                _ = waits.next()
                clock.advance(by: TimeInterval(seconds))
            },
            send: { request in
                timeouts.append(request.timeoutInterval)
                if attempts.next() == 1 {
                    clock.advance(by: 120)
                    throw URLError(.timedOut)
                }
                return (Data(#"{"data":[{"b64_json":"aW1hZ2U="}]}"#.utf8), Self.http(200))
            }
        )

        let bytes = try await provider.image(prompt: "A bridge", style: nil, aspect: .wide, role: .background)
        #expect(bytes == Data("image".utf8))
        #expect(attempts.count == 2)
        #expect(waits.count == 1)
        #expect(timeouts.all == [deadline, deadline - 122])
    }

    @Test func authFailureAndOfflineFailImmediatelyWithoutRetry() async {
        let authAttempts = AttemptCounter()
        let authWaits = AttemptCounter()
        let authProvider = OpenAIImageProvider(
            apiKey: "k",
            wait: { _ in _ = authWaits.next() },
            send: { _ in
                _ = authAttempts.next()
                return (Data(), Self.http(401))
            }
        )
        await #expect(throws: LecternError.authFailed(provider: "OpenAI")) {
            _ = try await authProvider.image(prompt: "A bridge", style: nil, aspect: .wide, role: .background)
        }
        #expect(authAttempts.count == 1)
        #expect(authWaits.count == 0)

        let offlineAttempts = AttemptCounter()
        let offlineWaits = AttemptCounter()
        let offlineProvider = OpenAIImageProvider(
            apiKey: "k",
            wait: { _ in _ = offlineWaits.next() },
            send: { _ in
                _ = offlineAttempts.next()
                throw URLError(.notConnectedToInternet)
            }
        )
        await #expect(throws: LecternError.networkOffline) {
            _ = try await offlineProvider.image(prompt: "A bridge", style: nil, aspect: .wide, role: .background)
        }
        #expect(offlineAttempts.count == 1)
        #expect(offlineWaits.count == 0)
    }

    @Test func insufficientQuota429FailsImmediatelyWithoutRetry() async {
        let quotaBody = Data(#"{"error":{"type":"insufficient_quota","code":"insufficient_quota","message":"You exceeded your current quota"}}"#.utf8)
        let attempts = AttemptCounter()
        let waits = AttemptCounter()

        let provider = OpenAIImageProvider(
            apiKey: "k",
            wait: { _ in _ = waits.next() },
            send: { _ in
                _ = attempts.next()
                return (quotaBody, Self.http(429, headers: ["Retry-After": "0"]))
            }
        )

        await #expect(throws: LecternError.providerError(status: 429, message: "You exceeded your current quota")) {
            _ = try await provider.image(prompt: "A bridge", style: nil, aspect: .wide, role: .background)
        }
        #expect(attempts.count == 1)
        #expect(waits.count == 0)

        let validateAttempts = AttemptCounter()
        let validateProvider = OpenAIImageProvider(
            apiKey: "k",
            wait: { _ in },
            send: { _ in
                _ = validateAttempts.next()
                return (quotaBody, Self.http(429, headers: ["Retry-After": "0"]))
            }
        )
        await #expect(throws: LecternError.providerError(status: 429, message: "You exceeded your current quota")) {
            try await validateProvider.validate()
        }
        #expect(validateAttempts.count == 1)
    }
}
