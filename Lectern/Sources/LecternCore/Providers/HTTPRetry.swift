import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One place for "how hard do we try", so the providers cannot drift.
///
/// They had drifted. Anthropic retried once on 429/5xx after a flat two
/// seconds; Gemini made three attempts with real exponential backoff; OpenAI
/// did not retry at all, so a single 429 ended an image. And all three treated
/// a thrown `URLError` as final, which meant the longest call in the product —
/// a two-minute deck draft — discarded a paid generation on one dropped
/// connection, without ever asking again.
enum HTTPRetry {
    /// Attempts including the first.
    static let maxAttempts = 3

    /// Seconds to wait before the next attempt. `Retry-After` wins when the
    /// server sends one — it knows more than we do — otherwise exponential from
    /// two seconds, capped so a 5xx spike cannot park the UI for minutes.
    ///
    /// `attempt` is zero-based: the delay after the first failure.
    static func backoff(attempt: Int, retryAfter: Int?) -> Int {
        if let retryAfter, retryAfter >= 0 { return min(maxBackoffSeconds, retryAfter) }
        return min(maxBackoffSeconds, 2 << max(0, attempt))
    }

    static let maxBackoffSeconds = 60

    /// A status worth trying again: rate limiting, or the server failing in a
    /// way that says nothing about the request.
    static func isRetriable(status: Int) -> Bool {
        status == 429 || (500...599).contains(status)
    }

    /// A transport failure worth trying again.
    ///
    /// `.notConnectedToInternet` is deliberately absent: there is no radio, so
    /// waiting two seconds and asking again is theatre. Callers map it straight
    /// to `.networkOffline`, which tells the user the one thing they can act on.
    static func isRetriable(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .secureConnectionFailed,
             .resourceUnavailable, .badServerResponse:
            return true
        default:
            return false
        }
    }

    /// `Retry-After` as whole seconds. The header is also allowed to carry an
    /// HTTP date, which no provider here sends; an unparsable value reads as
    /// absent so the exponential schedule takes over.
    static func retryAfterSeconds(_ response: HTTPURLResponse) -> Int? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return seconds(raw)
    }

    /// Seconds from a header value or a Google-style `"3s"` duration string.
    static func seconds(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = trimmed.hasSuffix("s") ? String(trimmed.dropLast()) : trimmed
        guard let seconds = Double(number), seconds >= 0 else { return nil }
        return Int(ceil(seconds))
    }

    /// The longest a call may go on *starting* new attempts.
    ///
    /// Retries without a ceiling changed the worst case: three attempts at a
    /// 120-second timeout, plus backoff, is over six minutes during which
    /// `GeneratingView` shows a spinner and a stage label that never advances.
    ///
    /// This bounds when a retry may begin, not when it finishes — an attempt
    /// started just inside the deadline still gets its full timeout, so the
    /// true ceiling is this plus one request timeout. Bounding the finish
    /// instead would mean assuming every attempt takes the worst case, which
    /// refuses a cheap retry after a connection that failed in a millisecond.
    static let overallDeadline: TimeInterval = 180

    /// Whether there is still time to try again, given when the call started
    /// and how long the next wait would be. Checked before sleeping, so the
    /// backoff itself cannot carry the call past the deadline.
    static func hasTimeToRetry(startedAt: Date, nextWait: Int, now: Date = Date()) -> Bool {
        now.addingTimeInterval(TimeInterval(nextWait)).timeIntervalSince(startedAt) < overallDeadline
    }

    /// Sleep between attempts. Cancellation propagates: a user who pressed
    /// Cancel should not wait out a backoff first.
    static func wait(seconds: Int) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
    }
}
