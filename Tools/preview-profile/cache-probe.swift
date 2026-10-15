// Cache-only control frozen from e35bf24; production candidate sources are compiled alongside this file.
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

private struct BaselineCache<Key: Hashable, Value> {
    /// The hard upper bound on live entries. Never exceeded after `insert`.
    let capacity: Int
    private var entries: [Key: Value] = [:]
    /// Keys in use order, least-recently-used first, most-recently-used last.
    private var recency: [Key] = []

    init(capacity: Int) {
        precondition(capacity > 0, "BoundedCache needs a positive capacity")
        self.capacity = capacity
    }

    /// Live entry count; never greater than `capacity`.
    var count: Int { entries.count }

    /// Returns the value for `key`, marking it most-recently-used on a hit.
    /// Synchronous by construction — the fast path a view can call from `body`.
    mutating func value(forKey key: Key) -> Value? {
        guard let value = entries[key] else { return nil }
        promote(key)
        return value
    }

    /// Inserts (or replaces) `value` for `key` and, if that pushes the cache
    /// past `capacity`, evicts the single least-recently-used entry.
    mutating func insert(_ value: Value, forKey key: Key) {
        entries[key] = value
        promote(key)
        while entries.count > capacity, let oldest = recency.first {
            recency.removeFirst()
            entries.removeValue(forKey: oldest)
        }
    }

    private mutating func promote(_ key: Key) {
        if let index = recency.firstIndex(of: key) { recency.remove(at: index) }
        recency.append(key)
    }
}

/// No WebKit or bitmap allocations: isolates identity/preparation/LRU overhead.
/// Usage: cache-probe baseline|candidate /absolute/svg-paths.json
@main
private struct CacheProbe {
    struct BaselineKey: Hashable { let svg: String; let width = 640; let height = 360 }
    struct CandidateKey: Hashable { let content: PreviewContent; let width = 640; let height = 360 }
    struct Sample: Codable { let stage: String; let elapsedSeconds: Double; let cpuSeconds: Double }
    struct Report: Codable {
        let variant: String
        let slides: Int
        let svgBytes: Int
        let peakRSSBytes: Int
        let accountedCacheBytes: Int?
        let receipt: Int
        let stages: [Sample]
    }
    static func main() throws {
        precondition(CommandLine.arguments.count == 3)
        let variant = CommandLine.arguments[1]
        precondition(["baseline", "candidate"].contains(variant))
        let paths = try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        // Independent storage models a fresh Inspect operation, not only a shared
        // String copy. File reads/UTF-8 decoding are outside the stage samples.
        let originals = try paths.map { try String(contentsOfFile: $0, encoding: .utf8) }
        let repeated = try paths.map { try String(contentsOfFile: $0, encoding: .utf8) }
        var samples: [Sample] = []
        func measure<T>(_ stage: String, _ body: () -> T) -> T {
            let cpu = Double(clock()) / Double(CLOCKS_PER_SEC)
            let start = ProcessInfo.processInfo.systemUptime
            let result = body()
            samples.append(Sample(stage: stage, elapsedSeconds: ProcessInfo.processInfo.systemUptime - start,
                cpuSeconds: Double(clock()) / Double(CLOCKS_PER_SEC) - cpu))
            return result
        }
        var receipt = 0
        var accounted: Int?
        if variant == "baseline" {
            var cache = BaselineCache<BaselineKey, Int>(capacity: 256)
            measure("insert") {
                for (index, svg) in originals.enumerated() { cache.insert(index, forKey: .init(svg: svg)) }
            }
            measure("repeatLookup") {
                for (index, svg) in repeated.enumerated() {
                    let value = cache.value(forKey: .init(svg: svg))
                    precondition(value == index); receipt += value!
                }
            }
            measure("sharedLookup") {
                for (index, svg) in originals.enumerated().reversed() {
                    let value = cache.value(forKey: .init(svg: svg))
                    precondition(value == index); receipt += value!
                }
            }
        } else {
            let cache = CostLimitedCache<CandidateKey, Int>(capacity: 256, costLimit: 256 * 1024 * 1024)
            let first = measure("initialPreparation") { originals.map { PreviewContent(svg: $0) } }
            measure("insert") {
                for (index, content) in first.enumerated() {
                    precondition(cache.insert(index, forKey: .init(content: content), cost: content.byteCount + 640 * 360 * 4))
                }
            }
            let second = measure("repeatPreparation") { repeated.map { PreviewContent(svg: $0) } }
            measure("repeatLookup") {
                for (index, content) in second.enumerated() {
                    let value = cache.value(forKey: .init(content: content))
                    precondition(value == index); receipt += value!
                }
            }
            measure("sharedLookup") {
                for (index, content) in first.enumerated().reversed() {
                    let value = cache.value(forKey: .init(content: content))
                    precondition(value == index); receipt += value!
                }
            }
            accounted = cache.totalCost
        }
        var usage = rusage()
        #if canImport(Darwin)
        precondition(getrusage(RUSAGE_SELF, &usage) == 0)
        let rss = Int(usage.ru_maxrss)
        #else
        precondition(getrusage(__rusage_who_t(RUSAGE_SELF.rawValue), &usage) == 0)
        let rss = Int(usage.ru_maxrss) * 1024
        #endif
        let report = Report(variant: variant, slides: paths.count, svgBytes: originals.reduce(0) { $0 + $1.utf8.count },
            peakRSSBytes: rss, accountedCacheBytes: accounted, receipt: receipt, stages: samples)
        print(String(decoding: try JSONEncoder().encode(report), as: UTF8.self))
    }
}


