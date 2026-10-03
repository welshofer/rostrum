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
}
