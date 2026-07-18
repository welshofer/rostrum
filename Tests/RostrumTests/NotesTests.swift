import Foundation
import Testing
@testable import Rostrum

@Suite struct NotesTests {
    @Test func notesRoundTrip() throws {
        let deck = try Presentation()
        #expect(!deck.slides[0].hasNotes)
        #expect(deck.slides[0].notesText == "")

        try deck.slides[0].setNotes("Remember to pause here.")
        #expect(deck.slides[0].hasNotes)

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slides[0].hasNotes)
        #expect(reopened.slides[0].notesText == "Remember to pause here.")
    }

    @Test func oneNotesMasterSharedAcrossSlides() throws {
        let deck = try Presentation()
        try deck.slides.add()
        try deck.slides[0].setNotes("first")
        try deck.slides[1].setNotes("second")

        let masters = deck.package.parts.keys.filter { $0.value.hasPrefix("/ppt/notesMasters/") }
        #expect(masters.count == 1)
        let notesSlides = deck.package.parts.keys.filter { $0.value.hasPrefix("/ppt/notesSlides/") }
        #expect(notesSlides.count == 2)

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slides[0].notesText == "first")
        #expect(reopened.slides[1].notesText == "second")
    }

    @Test func notesMasterIdLstPositionedBeforeSldIdLst() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes("x")
        let names = try deck.presentationPart.dom().childElements.map(\.name)
        let notesIdx = names.firstIndex(of: "p:notesMasterIdLst")
        let sldIdx = names.firstIndex(of: "p:sldIdLst")
        let masterIdx = names.firstIndex(of: "p:sldMasterIdLst")
        #expect(notesIdx != nil && sldIdx != nil && masterIdx != nil)
        #expect(masterIdx! < notesIdx! && notesIdx! < sldIdx!)
    }

    @Test func settingNotesTwiceReplacesText() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes("v1")
        try deck.slides[0].setNotes("v2")
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slides[0].notesText == "v2")
        // Still exactly one notes part.
        #expect(reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/notesSlides/") }.count == 1)
    }

    @Test func duplicatedSlideSharesNotesPartSafely() throws {
        // duplicate(at:) copies rels — both slides point at the same notes
        // part. That is lossless (PowerPoint tolerates shared notes refs);
        // editing either edits both until per-slide notes copy lands.
        let deck = try Presentation()
        try deck.slides[0].setNotes("shared")
        try deck.slides.duplicate(at: 0)
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slides[1].notesText == "shared")
    }
}
