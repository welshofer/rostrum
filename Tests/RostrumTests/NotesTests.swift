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

    @Test func notesMasterOwnsDistinctThemePart() throws {
        // Sharing theme1.xml between slide master and notes master trips
        // PowerPoint's repair dialog (found by scripted-PowerPoint bisect,
        // 2026-07-18). Every master must own its theme.
        let deck = try Presentation()
        try deck.slides[0].setNotes("x")
        let package = try Presentation(data: try deck.serializedData()).package
        let slideMaster = try package.part(at: PackURI("/ppt/slideMasters/slideMaster1.xml"))
        let notesMaster = try package.part(at: PackURI("/ppt/notesMasters/notesMaster1.xml"))
        func themeTarget(_ part: Part) -> String? {
            part.rels.first(ofType: RelType.theme).map {
                PackURI.resolve(target: $0.target, relativeTo: part.uri.baseURI).value
            }
        }
        let slideTheme = try #require(themeTarget(slideMaster))
        let notesTheme = try #require(themeTarget(notesMaster))
        #expect(slideTheme != notesTheme)
        _ = try package.part(at: PackURI(notesTheme))  // and it exists
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

    @Test func multiParagraphNotesRoundTrip() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes(["First line of the talk track.", "Second beat.", "Land the point."])
        try deck.slides[0].appendNote("And a closing aside.")
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slides[0].notesParagraphs == ["First line of the talk track.", "Second beat.", "Land the point.", "And a closing aside."])
    }

    @Test func emptyNotesArrayIsValid() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes([String]())
        #expect(try deck.validate().isEmpty)
        _ = try Presentation(data: try deck.serializedData())
    }

}
