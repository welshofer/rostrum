import Foundation
import Testing
@testable import LecternCore

@Suite struct PreviewCacheTests {
    @Test func exactBytesAndDimensionsDetermineIdentity() throws {
        struct Key: Hashable { let content: PreviewContent; let width: Int }
        let svg = "<svg>" + String(repeating: "font/image bytes ", count: 100_000) + "</svg>"
        let original = PreviewContent(svg: svg)
        let regenerated = PreviewContent(svg: try #require(String(data: Data(svg.utf8), encoding: .utf8)))
        #expect(original == regenerated)
        #expect(original.byteCount == svg.utf8.count)
        #expect(Array(original.svg.utf8) == Array(svg.utf8))
        let cache = CostLimitedCache<Key, Int>(capacity: 4, costLimit: 10)
        cache.insert(1, forKey: Key(content: original, width: 640), cost: 1)
        #expect(cache.value(forKey: Key(content: regenerated, width: 640)) == 1)
        #expect(cache.value(forKey: Key(content: regenerated, width: 320)) == nil)
        #expect(cache.value(forKey: Key(content: PreviewContent(svg: svg + " "), width: 640)) == nil)
        // String equality normalizes Unicode, but cache identity must preserve bytes.
        #expect("\u{e9}" == "e\u{301}")
        #expect(PreviewContent(svg: "\u{e9}") != PreviewContent(svg: "e\u{301}"))
    }

    @Test func fingerprintCollisionNeverReusesDifferentContent() {
        let first = PreviewContent(svg: "<svg>font A</svg>", fingerprintOverride: 7)
        let second = PreviewContent(svg: "<svg>font B</svg>", fingerprintOverride: 7)
        #expect(first.byteCount == second.byteCount)
        let cache = CostLimitedCache<PreviewContent, Int>(capacity: 2, costLimit: 2)
        cache.insert(1, forKey: first, cost: 1)
        #expect(cache.value(forKey: second) == nil)
        cache.insert(2, forKey: second, cost: 1)
        #expect(cache.value(forKey: first) == 1)
        #expect(cache.value(forKey: second) == 2)
    }

    @Test func preparationOccursOncePerRecordAndRetainsFailedSlots() {
        let trace = PipelineTrace()
        PipelineTrace.$current.withValue(trace) {
            let record = SlidePreviewRecord(number: 3, title: "Missing", svg: nil, geometry: .widescreen)
            let copy = record
            #expect(record.svg == nil)
            #expect(copy.content == record.content)
            #expect(copy.displaySVG.contains("Preview unavailable"))
            #expect(copy.accessibilityLabel(total: 4) == "Slide 3 of 4: Missing. Preview unavailable")
            for _ in 0..<20 { _ = record.content.hashValue; _ = record.displaySVG }
        }
        #expect(trace.report.samples.map(\.stage) == ["preview.identity"])
    }

    @Test func byteBudgetEvictsLeastRecentlyUsedAndReplacementUpdatesCost() {
        let cache = CostLimitedCache<String, Int>(capacity: 10, costLimit: 10)
        cache.insert(1, forKey: "a", cost: 4)
        cache.insert(2, forKey: "b", cost: 4)
        #expect(cache.value(forKey: "a") == 1)
        cache.insert(3, forKey: "c", cost: 3)
        #expect(cache.value(forKey: "b") == nil)
        #expect(cache.totalCost == 7)
        cache.insert(4, forKey: "a", cost: 7)
        #expect(cache.totalCost == 10)
        #expect(cache.count == 2)
        cache.insert(5, forKey: "a", cost: 2)
        #expect(cache.totalCost == 5)
        #expect(cache.value(forKey: "a") == 5)
        cache.insert(6, forKey: "d", cost: 8)
        #expect(cache.totalCost == 10)
        #expect(cache.value(forKey: "c") == nil)
        #expect(cache.value(forKey: "a") == 5)
    }

    @Test func countLimitOversizedEntriesAndArithmeticBoundaries() {
        let cache = CostLimitedCache<String, Int>(capacity: 2, costLimit: Int.max)
        cache.insert(1, forKey: "a", cost: Int.max - 1)
        cache.insert(2, forKey: "b", cost: 1)
        #expect(cache.totalCost == Int.max)
        cache.insert(3, forKey: "c", cost: 2)
        #expect(cache.value(forKey: "a") == nil)
        #expect(cache.totalCost == 3)
        cache.insert(4, forKey: "d", cost: 0)
        #expect(cache.value(forKey: "b") == nil)
        #expect(cache.count == 2)
        #expect(!cache.insert(99, forKey: "c", cost: -1))
        #expect(cache.value(forKey: "c") == 3)
        let small = CostLimitedCache<String, Int>(capacity: 2, costLimit: 4)
        small.insert(1, forKey: "a", cost: 3)
        #expect(!small.insert(2, forKey: "b", cost: 5))
        #expect(small.value(forKey: "a") == 1)
        #expect(small.totalCost == 3)
        #expect(!CostLimitedCache<String, Int>(capacity: 0, costLimit: 4).insert(1, forKey: "a", cost: 0))
        #expect(!CostLimitedCache<String, Int>(capacity: 2, costLimit: 0).insert(1, forKey: "a", cost: 1))
    }

    @Test func evictionReleasesValuesAndCacheHasNoRetainCycle() {
        final class Value {}
        weak var retained: Value?
        do {
            let cache = CostLimitedCache<Int, Value>(capacity: 1, costLimit: 1)
            let value = Value()
            retained = value
            cache.insert(value, forKey: 1, cost: 1)
        }
        #expect(retained == nil)
        let cache = CostLimitedCache<Int, Value>(capacity: 1, costLimit: 1)
        do {
            let value = Value()
            retained = value
            cache.insert(value, forKey: 1, cost: 1)
        }
        #expect(retained != nil)
        cache.insert(Value(), forKey: 2, cost: 1)
        #expect(retained == nil)
    }
}
