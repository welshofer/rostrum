import Foundation
import Testing
@testable import Rostrum

@Suite struct SectionsTests {
    private func deck(slides: Int) throws -> Presentation {
        let deck = try Presentation()
        for _ in 1..<slides { try deck.slides.add() }
        return deck
    }

    @Test func setSectionsPartitionsAndRoundTrips() throws {
        let deck = try deck(slides: 5)
        try deck.setSections([("Intro", 0), ("Body", 2), ("Close", 4)])
        let reopened = try Presentation(data: try deck.serializedData())
        let secs = reopened.sections
        #expect(secs.count == 3)
        #expect(Array(secs).map(\.name) == ["Intro", "Body", "Close"])
        #expect(secs[0].slideIndices == [0, 1])
        #expect(secs[1].slideIndices == [2, 3])
        #expect(secs[2].slideIndices == [4])
        // Full partition: every slide is covered exactly once, in order.
        #expect(Array(secs).flatMap(\.slideIndices) == [0, 1, 2, 3, 4])
        // Ids are GUIDs.
        #expect(secs[0].id.hasPrefix("{") && secs[0].id.count == 38)
    }

    @Test func readingSectionsOnASectionlessDeckIsAByteIdenticalNoOp() throws {
        let a = try deck(slides: 3)
        let dataA = try a.serializedData()
        let b = try deck(slides: 3)
        #expect(b.sections.count == 0)          // reading does not create the list
        #expect(try b.serializedData() == dataA)
    }

    @Test func sectionGUIDsAndOutputAreDeterministic() throws {
        func build() throws -> Data {
            let deck = try deck(slides: 4)
            try deck.setSections([("Alpha", 0), ("Beta", 2)])
            return try deck.serializedData()
        }
        #expect(try build() == build())
    }

    @Test func addSectionSplitsAndRenameWorks() throws {
        let deck = try deck(slides: 4)
        try deck.setSections([("All", 0)])
        try deck.addSection("Later", startingAtSlide: 2)
        #expect(deck.sections.count == 2)
        #expect(deck.sections[1].name == "Later")
        #expect(deck.sections[1].slideIndices == [2, 3])
        deck.sections[0].name = "Earlier"
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(Array(reopened.sections).map(\.name) == ["Earlier", "Later"])
    }
}
