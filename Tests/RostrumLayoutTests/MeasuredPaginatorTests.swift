import Testing
@testable import RostrumLayout

@Suite struct MeasuredPaginatorTests {
    @Test func keepsOrderAndEveryItem() throws {
        let input = Array(0..<17)
        let pages = try MeasuredPaginator.pages(input) { $0.count <= 4 }
        #expect(pages.flatMap { $0 } == input)
        #expect(pages.map(\.count) == [4, 4, 4, 4, 1])
    }
    @Test func paragraphSplittingPreservesWhitespaceAndUnicode() throws {
        let input = "Ocean CO₂  warms\nEarth — and   choices matter."
        let parts = try MeasuredPaginator.text(input) { $0.count <= 14 }
        #expect(parts.count > 1)
        #expect(parts.joined() == input)
        #expect(parts.allSatisfy { $0.count <= 14 })
    }
    @Test func oversizedSingleItemFailsWithoutTruncation() {
        #expect(throws: LayoutError.self) {
            try MeasuredPaginator.pages(["oversized"]) { _ in false }
        }
    }
    @Test func cancellationStopsPagination() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try MeasuredPaginator.pages([1, 2, 3]) { _ in true }
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func maximalPrefixesMatchAnIndependentGreedyPartition() throws {
        for count in [0, 1, 2, 7, 31, 128, 1024] {
            for (firstCapacity, laterCapacity) in [(9, 9), (13, 13), (40, 40), (10_000, 10_000),
                                                   (9, 1_000), (1_000, 9)] {
                let input = Array(0..<count)
                func weight(_ item: Int) -> Int { item * 7 % 9 + 1 }
                // A different budget at each starting item exercises changing
                // page capacities, including abrupt growth and shrinkage;
                // every individual prefix is still monotonic.
                func limit(_ first: Int) -> Int { (first == 0 ? firstCapacity : laterCapacity) + first % 11 }
                var expected: [[Int]] = [], page: [Int] = [], used = 0
                for item in input {
                    if let first = page.first, used + weight(item) > limit(first) {
                        expected.append(page); page = []; used = 0
                    }
                    page.append(item); used += weight(item)
                }
                if !page.isEmpty { expected.append(page) }
                let actual = try MeasuredPaginator.pages(input) { prefix in
                    prefix.reduce(0) { $0 + weight($1) } <= limit(prefix.first ?? 0)
                }
                #expect(actual == expected)
            }
        }
    }

    @Test func longInputsBoundRepeatedMeasurementWork() throws {
        let input = Array(0..<20_000)
        var visited = 0
        let pages = try MeasuredPaginator.pages(input) { prefix in
            visited += prefix.count
            return prefix.count <= 7
        }
        #expect(pages.flatMap { $0 } == input)
        #expect(pages.dropLast().allSatisfy { $0.count == 7 })
        // An input-size bound catches repeated measurement of huge suffixes,
        // independent of CPU speed and the search's precise probe sequence.
        #expect(visited < 20 * input.count)
    }

    @Test func alreadyFittingAndEmptyInputsAvoidExtraMeasurements() throws {
        var calls = 0
        let whole = try MeasuredPaginator.pages(Array(0..<100)) { _ in calls += 1; return true }
        let empty = try MeasuredPaginator.pages([Int]()) { _ in calls += 1; return true }
        #expect(whole == [Array(0..<100)] && empty.isEmpty)
        #expect(calls == 1)
    }

    @Test func predicateErrorsArePropagated() {
        enum Failure: Error { case measurement }
        #expect(throws: Failure.self) {
            try MeasuredPaginator.pages(Array(0..<20)) { prefix in
                if prefix.count < 20 { throw Failure.measurement }
                return false
            }
        }
    }

    @Test(arguments: [true, false])
    func cancellationDuringMeasurementDoesNotReturnPages(wholeFits: Bool) async {
        let task = Task {
            try MeasuredPaginator.pages(Array(0..<20)) { prefix in
                if wholeFits || prefix.count < 20 {
                    withUnsafeCurrentTask { $0?.cancel() }
                    return true
                }
                return false
            }
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test(arguments: ["é e\u{301}  café\r\n\tExact words stay. ",
                      "אבג  مرحبا \n日本語 👩🏽‍💻 words\t", "  a\n b\r\nc\t d  "])
    func textPagesRetainExactBytesAcrossWhitespace(text: String) throws {
        let input = String(repeating: text, count: 8)
        let pages = try MeasuredPaginator.text(input) { $0.utf8.count <= 48 }
        #expect(pages.count > 1)
        #expect(pages.joined().utf8.elementsEqual(input.utf8))
        #expect(pages.allSatisfy { $0.utf8.count <= 48 })
    }

    @Test(arguments: [true, false])
    func cancellationDuringInitialTextMeasurementStopsSplitting(fits: Bool) async {
        let task = Task {
            try MeasuredPaginator.text("Exact source text") { _ in
                withUnsafeCurrentTask { $0?.cancel() }
                return fits
            }
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
