import Foundation
import Testing
@testable import LecternCore

@Suite struct AuthoredProbeCacheTests {
    @Test func reusesFitAndRejectionButMeasuresUsageWhenFirstRequested() throws {
        let cache = AuthoredProbeCache()
        let input = IRSlide(id: "a", layout: "bullets", title: "Evidence")
        var calls = 0
        func evaluate(_ usage: Bool) throws -> AuthoredProbeCache.Outcome {
            try cache.evaluate(input, hasImage: false, needsUsage: usage) {
                calls += 1
                return .fits(usage: usage ? 0.3 : nil)
            }
        }
        _ = try evaluate(false); _ = try evaluate(false)
        #expect(calls == 1)
        if case .fits(let value) = try evaluate(true) { #expect(value == 0.3) }
        else { Issue.record("Usage was rejected") }
        _ = try evaluate(true); _ = try evaluate(false)
        #expect(calls == 2)
        #expect(cache.count == 1)

        let rejected = IRSlide(id: "b", layout: "bullets", title: "Oversized")
        for usage in [false, true, false] {
            let result = try cache.evaluate(rejected, hasImage: false, needsUsage: usage) {
                calls += 1; return .rejected("Exact original failure")
            }
            if case .rejected(let message) = result { #expect(message == "Exact original failure") }
            else { Issue.record("Rejected content was accepted") }
        }
        #expect(calls == 3)
    }

    @Test func contentLayoutImagesAndExactUnicodeRemainDistinct() throws {
        let cache = AuthoredProbeCache()
        let original = IRSlide(id: "a", layout: "bullets", title: "Evidence", body: Body(bullets: [Bullet(text: "é")]))
        var decomposed = original; decomposed.body?.bullets = [Bullet(text: "e\u{301}")]
        var changed = original; changed.body?.source = "New source"
        var layout = original; layout.layout = "imageRight"
        var calls = 0
        for (input, image) in [(original, false), (decomposed, false), (changed, false), (layout, false), (original, true)] {
            _ = try cache.evaluate(input, hasImage: image, needsUsage: false) { calls += 1; return .fits(usage: nil) }
        }
        #expect(calls == 5)
        // A fresh operation must measure again, even for identical content:
        // font registrations, style and host measurements may have changed.
        _ = try AuthoredProbeCache().evaluate(original, hasImage: false, needsUsage: false) { calls += 1; return .rejected("Different font metrics") }
        #expect(calls == 6)
    }

    @Test func storageIsBoundedAndOversizedInputsUseOrdinaryPath() throws {
        let cache = AuthoredProbeCache()
        var calls = 0
        let large = IRSlide(id: "large", layout: "bullets", title: String(repeating: "x", count: 70_000))
        for _ in 0..<2 {
            _ = try cache.evaluate(large, hasImage: false, needsUsage: false) { calls += 1; return .fits(usage: nil) }
        }
        #expect(calls == 2 && cache.count == 0)
        for index in 0..<100 {
            _ = try cache.evaluate(IRSlide(id: String(index), layout: "bullets", title: String(repeating: "x", count: 8_000)),
                hasImage: false, needsUsage: false) { .rejected("Failure") }
        }
        #expect(cache.count > 0 && cache.count <= 64 && cache.retainedBytes <= 262_144)
        let small = AuthoredProbeCache()
        for index in 0..<100 {
            _ = try small.evaluate(IRSlide(id: String(index), layout: "bullets"), hasImage: false, needsUsage: false) { .fits(usage: nil) }
        }
        #expect(small.count == 64)
    }

    @Test func thrownErrorsAreNotMemoized() throws {
        enum Failure: Error { case transient }
        let cache = AuthoredProbeCache(), input = IRSlide(id: "a", layout: "bullets")
        #expect(throws: Failure.self) {
            try cache.evaluate(input, hasImage: false, needsUsage: false) { throw Failure.transient }
        }
        #expect(cache.count == 0)
        _ = try cache.evaluate(input, hasImage: false, needsUsage: false) { .fits(usage: nil) }
        #expect(cache.count == 1)
    }

    @Test func cancellationStillInterruptsCacheHits() async throws {
        let task = Task {
            let cache = AuthoredProbeCache(), input = IRSlide(id: "a", layout: "bullets")
            _ = try cache.evaluate(input, hasImage: false, needsUsage: false) { .fits(usage: nil) }
            withUnsafeCurrentTask { $0?.cancel() }
            _ = try cache.evaluate(input, hasImage: false, needsUsage: false) { Issue.record("Cache miss"); return .fits(usage: nil) }
        }
        do { try await task.value; Issue.record("Cancelled probe returned") }
        catch is CancellationError { }
    }
}
