import Testing
import Foundation
@testable import Rostrum

/// The two tests that each build a 100,000-node tree, kept out of each other's
/// way.
///
/// They are memory-hungry by design — that is the point of them — and running
/// them concurrently with each other put peak usage high enough that Swift 6.1
/// on Linux died allocating, while the same commit passed on 6.0 and on macOS.
/// `.serialized` keeps the depth and the assertions exactly as they were and
/// simply stops the two biggest trees existing at the same moment.
@Suite(.serialized) struct DeepTreeTests {

    /// A chain of `depth` elements built in code, which no parser limit gates.
    private func deepTree(depth: Int) -> XML.Element {
        let root = XML.Element("a")
        var current = root
        for _ in 1..<depth {
            let child = XML.Element("a")
            current.appendElement(child)
            current = child
        }
        current.append(.text("x"))
        return root
    }

    @Test func deepTreeBuiltInCodeDeallocatesWithoutOverflowingTheStack() {
        // Well past the ~20,000 level where the recursive teardown died.
        do {
            let root = deepTree(depth: 100_000)
            #expect(root.name == "a")
        }
        // Reaching here at all is the assertion: the tree released iteratively.
        #expect(Bool(true))
    }

    @Test func deepTreeSerializesAndReadsTextWithoutOverflowingTheStack() {
        let root = deepTree(depth: 100_000)
        #expect(root.textContent == "x")
        let serialized = root.serialized()
        #expect(serialized.hasPrefix("<a><a><a>"))
        #expect(serialized.hasSuffix("</a></a></a>"))
        #expect(serialized.contains(">x<"))
    }
}
