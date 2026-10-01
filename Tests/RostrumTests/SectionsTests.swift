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
        #expect(try secs[0].slideIndices == [0, 1])
        #expect(try secs[1].slideIndices == [2, 3])
        #expect(try secs[2].slideIndices == [4])
        // Full partition: every slide is covered exactly once, in order.
        #expect(Array(secs).flatMap(\.slideIndices) == [0, 1, 2, 3, 4])
        // Ids are GUIDs.
        #expect(try secs[0].id.hasPrefix("{") && secs[0].id.count == 38)
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
        #expect(try deck.sections[1].name == "Later")
        #expect(try deck.sections[1].slideIndices == [2, 3])
        try deck.sections[0].name = "Earlier"
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(Array(reopened.sections).map(\.name) == ["Earlier", "Later"])
    }

    @Test func badBoundariesThrowInsteadOfTrapping() throws {
        // Boundaries routinely arrive from dynamic data (an outline, a model's
        // plan). Every malformed shape must surface as a thrown error the
        // caller can catch — never a process abort.
        let deck = try deck(slides: 4)
        #expect(throws: RostrumError.self) { try deck.setSections([]) }
        #expect(throws: RostrumError.self) { try deck.setSections([("Late", 1)]) }
        #expect(throws: RostrumError.self) {
            try deck.setSections([("A", 0), ("B", 2), ("C", 1)])
        }
        #expect(throws: RostrumError.self) {
            try deck.setSections([("A", 0), ("A again", 0)])
        }
        // And the deck is untouched after every refusal.
        #expect(deck.sections.count == 0)
    }

    @Test func sectionSubscriptThrowsOutOfRange() throws {
        // Same contract as `Slides.subscript`: the index space comes from the
        // file, so out-of-range reports rather than aborts.
        let deck = try deck(slides: 2)
        try deck.setSections([("Only", 0)])
        #expect(throws: RostrumError.self) { try deck.sections[1] }
        #expect(throws: RostrumError.self) { try deck.sections[-1] }
        #expect(try deck.sections[0].name == "Only")
    }
}

@Suite struct SectionLifecycleTests {
    private func deck() throws -> Presentation {
        let deck = try Presentation()
        for _ in 0..<3 { try deck.slides.add() }
        try deck.setSections([("First", 0), ("Second", 2)])
        return deck
    }

    private func assertPartition(_ deck: Presentation) throws {
        let indices = Array(deck.sections).flatMap(\.slideIndices)
        #expect(indices == Array(0..<deck.slides.count))
        #expect(Set(indices).count == indices.count)
        #expect(try deck.sections.membership() != nil)
        #expect(try deck.validate().isEmpty)
    }

    @Test func everySlideOperationMaintainsMembershipAndOriginalSectionXML() throws {
        let deck = try deck()
        let first = try deck.sections[0]
        let second = try deck.sections[1]
        let ids = [first.id, second.id]
        let unknown = XML.Element("custom:payload", attributes: [("xmlns:custom", "urn:section"), ("id", "opaque")])
        first.element.appendElement(unknown)
        deck.presentationPart.markDirty()
        try deck.slides.duplicate(at: 1)
        #expect(first.slideIndices == [0, 1, 2])
        #expect(second.slideIndices == [3, 4])
        try deck.slides.add()
        #expect(second.slideIndices == [3, 4, 5])
        try deck.slides.move(from: 0, to: 4)
        #expect(first.slideIndices == [0, 1])
        #expect(second.slideIndices == [2, 3, 4, 5])
        try deck.slides.remove(at: 1)
        try assertPartition(deck)
        #expect(Array(deck.sections).map(\.id) == ids)
        #expect(first.element.firstChild(named: "custom:payload")?.serialized() == unknown.serialized())
        let reopened = try Presentation(data: try deck.serializedData())
        try assertPartition(reopened)
        #expect(Array(reopened.sections).map(\.id) == ids)
        #expect(try reopened.sections[0].element.firstChild(named: "custom:payload")?.serialized() == unknown.serialized())
    }

    @Test func importsAtBoundariesJoinFollowingSectionAndAppendsJoinLast() throws {
        let source = try Presentation()
        let dest = try deck()
        let ids = Array(dest.sections).map(\.id)
        try dest.slides.import(from: source, at: 0, insertAt: 2)
        #expect(try dest.sections[0].slideIndices == [0, 1])
        #expect(try dest.sections[1].slideIndices == [2, 3, 4])
        try dest.slides.import(from: source, at: 0, insertAt: 0)
        #expect(try dest.sections[0].slideIndices == [0, 1, 2])
        try dest.slides.importAll(from: source)
        #expect(try dest.sections[1].slideIndices == [3, 4, 5, 6])
        #expect(Array(dest.sections).map(\.id) == ids)
        try assertPartition(try Presentation(data: try dest.serializedData()))
    }

    @Test func emptySectionsArePreservedAndReusable() throws {
        let deck = try deck()
        let ids = Array(deck.sections).map(\.id)
        try deck.slides.remove(at: 3)
        try deck.slides.remove(at: 2)
        #expect(try deck.sections[1].slideCount == 0)
        #expect(Array(deck.sections).map(\.id) == ids)
        try deck.slides.add()
        #expect(try deck.sections[1].slideIndices == [2])
        while deck.slides.count > 0 { try deck.slides.remove(at: 0) }
        #expect(deck.sections.count == 2)
        try deck.slides.add()
        #expect(try deck.sections[1].slideIndices == [0])
        try assertPartition(deck)
    }

    @Test func sectionSplitReorderingAndRemovalPreserveUnaffectedIdentities() throws {
        let deck = try deck()
        let firstID = try deck.sections[0].id
        let secondID = try deck.sections[1].id
        let firstSlides = try deck.sections[0].slides.map { $0.part.uri }
        let secondSlides = try deck.sections[1].slides.map { $0.part.uri }
        let split = try deck.addSection("Split", startingAtSlide: 1)
        #expect(try deck.sections[0].id == firstID)
        #expect(try deck.sections[2].id == secondID)
        try deck.sections.move(from: 2, to: 0)
        #expect(Array(deck.slides).map { $0.part.uri } == secondSlides + firstSlides)
        #expect(Array(deck.sections).map(\.id) == [secondID, firstID, split.id])
        try assertPartition(deck)
        try deck.sections.remove(at: 1)
        #expect(Array(deck.sections).map(\.id) == [secondID, split.id])
        try assertPartition(deck)
        try deck.sections.remove(at: 0)
        #expect(try deck.sections[0].id == split.id)
        #expect(try deck.sections[0].slideCount == 4)
        try deck.sections.remove(at: 0)
        #expect(deck.sections.count == 0)
        #expect(deck.slides.count == 4)
    }

    @Test func invalidSectionPartitionRefusesSlideMutationAtomically() throws {
        let deck = try deck()
        let first = try deck.sections[0]
        first.element.firstChild(named: "p14:sldIdLst")?.appendElement(XML.Element("p14:sldId", attributes: [("id", "999")]))
        deck.presentationPart.markDirty()
        let before = try deck.serializedData()
        #expect(throws: (any Error).self) { try deck.slides.add() }
        #expect(throws: (any Error).self) { try deck.slides.remove(at: 0) }
        #expect(throws: (any Error).self) { try deck.slides.move(from: 0, to: 3) }
        #expect(throws: (any Error).self) { try deck.slides.duplicate(at: 0) }
        #expect(throws: (any Error).self) { try deck.slides.importAll(from: Presentation()) }
        #expect(try deck.serializedData() == before)
    }
}
