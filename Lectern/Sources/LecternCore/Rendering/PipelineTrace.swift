import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Opt-in host profiling, separate from document content and diagnostics.
/// Bind `current` around one operation. Child tasks inherit it; detached tasks
/// need an explicit binding. No clock reads or records occur while unbound.
/// CPU is process CPU (all threads), not task CPU; overlapping spans must not
/// be summed. WebKit helper processes are outside this process's CPU/RSS.
public final class PipelineTrace: @unchecked Sendable {
    @TaskLocal public static var current: PipelineTrace?

    public struct Sample: Codable, Sendable {
        public let stage: String
        public let slideNumber: Int?
        public let startSeconds: Double
        public let elapsedSeconds: Double
        public let cpuSeconds: Double
        public let outcome: String
    }

    public struct Report: Codable, Sendable {
        public let samples: [Sample]
        public let droppedSamples: Int
    }

    private struct Stamp: Sendable {
        let elapsed = ProcessInfo.processInfo.systemUptime
        let cpu = Double(clock()) / Double(CLOCKS_PER_SEC)
    }

    private let origin = Stamp()
    private let lock = NSLock()
    private let capacity: Int
    private var samples: [Sample] = []
    private var dropped = 0

    public init(capacity: Int = 10_000) { self.capacity = max(0, capacity) }

    public var report: Report {
        lock.lock(); defer { lock.unlock() }
        return Report(samples: samples, droppedSamples: dropped)
    }

    /// End explicitly (including failure/cancellation) to include the span.
    /// A span retains its trace, so WebKit callbacks can finish the originating
    /// request without relying on task-local propagation through Objective-C.
    public final class Span: @unchecked Sendable {
        private let trace: PipelineTrace
        private let stage: String
        private let slideNumber: Int?
        private let start = Stamp()
        private let lock = NSLock()
        private var ended = false

        fileprivate init(trace: PipelineTrace, stage: String, slideNumber: Int?) {
            self.trace = trace; self.stage = stage; self.slideNumber = slideNumber
        }

        public func end(outcome: String = "completed") {
            lock.lock(); defer { lock.unlock() }
            guard !ended else { return }
            ended = true
            let end = Stamp()
            trace.append(Sample(stage: stage, slideNumber: slideNumber,
                startSeconds: start.elapsed - trace.origin.elapsed,
                elapsedSeconds: end.elapsed - start.elapsed,
                cpuSeconds: end.cpu - start.cpu, outcome: outcome))
        }
    }

    public static func begin(_ stage: String, slideNumber: Int? = nil) -> Span? {
        current.map { Span(trace: $0, stage: stage, slideNumber: slideNumber) }
    }

    public static func measure<T>(_ stage: String, slideNumber: Int? = nil,
                                  _ operation: () throws -> T) rethrows -> T {
        let span = begin(stage, slideNumber: slideNumber)
        do {
            let value = try operation()
            span?.end()
            return value
        } catch {
            span?.end(outcome: error is CancellationError ? "cancelled" : "failed")
            throw error
        }
    }

    private func append(_ sample: Sample) {
        lock.lock(); defer { lock.unlock() }
        if samples.count < capacity { samples.append(sample) }
        else { dropped += 1 }
    }
}
