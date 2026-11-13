import Foundation
import Testing
@testable import Rostrum

/// Saves reuse the encoded `.rels` and content-type streams only while their
/// serialized bytes are unchanged.
@Suite struct RelationshipStreamCacheTests {
    private func entries(_ data: Data) throws -> [String: Data] {
        let zip = try ZipReader(data: data)
        return try Dictionary(uniqueKeysWithValues: zip.entryNames.map { ($0, try zip.data(forEntry: $0)) })
    }

    @Test func repeatedSavesAreIdenticalAndEditsReachTheArchive() throws {
        let deck = try Presentation()
        let first = try deck.serializedData()
        #expect(try deck.serializedData() == first)

        // A new slide changes [Content_Types].xml, presentation.xml.rels and
        // adds a slide .rels: none of the cached streams may be reused stale.
        _ = try deck.slides.add()
        let second = try deck.serializedData()
        let fresh = try Presentation(data: second)
        #expect(fresh.slideCount == 2)
        // An independent package built from the same bytes has no cache at
        // all; its save must match the cached one byte for byte.
        #expect(try fresh.serializedData() == second)
        let before = try entries(first), after = try entries(second)
        #expect(before["[Content_Types].xml"] != after["[Content_Types].xml"])
        #expect(before["ppt/_rels/presentation.xml.rels"] != after["ppt/_rels/presentation.xml.rels"])
        #expect(after["ppt/slides/_rels/slide2.xml.rels"] != nil)

        // Removing the slide again must drop its stream and restore the rest.
        try deck.slides.remove(at: 1)
        let third = try entries(try deck.serializedData())
        #expect(third["ppt/slides/_rels/slide2.xml.rels"] == nil)
        #expect(third["ppt/slides/_rels/slide1.xml.rels"] == before["ppt/slides/_rels/slide1.xml.rels"])
    }

    @Test func aReusedNameWithDifferentRelationshipsIsReencoded() throws {
        let deck = try Presentation()
        _ = try deck.slides.add()
        _ = try deck.serializedData()                       // caches slide2's .rels
        try deck.slides.remove(at: 1)
        let slide = try deck.slides.add()                   // slide2 again
        try slide.setNotes("Speaker notes add a relationship")
        let saved = try deck.serializedData()
        let reopened = try Presentation(data: saved)
        #expect(try reopened.slides[1].notesText == "Speaker notes add a relationship")
        #expect(try reopened.serializedData() == saved)
    }
}
