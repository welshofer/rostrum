import Foundation
import Testing
@testable import Rostrum

@Suite struct NotesTests {
    @Test func notesRoundTrip() throws {
        let deck = try Presentation()
        #expect(try deck.slides[0].hasNotes == false)
        #expect(try deck.slides[0].notesText == "")

        try deck.slides[0].setNotes("Remember to pause here.")
        #expect(try deck.slides[0].hasNotes)

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.slides[0].hasNotes)
        #expect(try reopened.slides[0].notesText == "Remember to pause here.")
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
        #expect(try reopened.slides[0].notesText == "first")
        #expect(try reopened.slides[1].notesText == "second")
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
        #expect(try reopened.slides[0].notesText == "v2")
        // Still exactly one notes part.
        #expect(reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/notesSlides/") }.count == 1)
    }

    @Test func duplicatedSlidesHaveIndependentRichNotesAndBacklinks() throws {
        let deck = try Presentation()
        let original = try deck.slides[0]
        let frame = try original.notesTextFrame()
        let run = frame.addParagraph().addRun("Rich note")
        run.bold = true
        run.fontSize = 24
        let notes = try original.part.related(by: RelType.notesSlide, in: deck.package)
        let dom = try notes.dom()
        dom.appendElement(XML.Element("foreign:payload", attributes: [
            ("xmlns:foreign", "urn:unknown-notes"), ("token", "preserve-me"),
        ], children: [.comment("inside notes"), .processingInstruction(target: "opaque", data: "value")]))
        notes.markDirty()
        notes.flushIfDirty()
        let originalXML = notes.blob

        let copy = try deck.slides.duplicate(at: 0)
        let copiedNotes = try copy.part.related(by: RelType.notesSlide, in: deck.package)
        #expect(notes.uri != copiedNotes.uri)
        #expect(copiedNotes.blob == originalXML)
        #expect(try notes.related(by: RelType.slide, in: deck.package).uri == original.part.uri)
        #expect(try copiedNotes.related(by: RelType.slide, in: deck.package).uri == copy.part.uri)
        #expect(try notes.related(by: RelType.notesMaster, in: deck.package).uri
            == copiedNotes.related(by: RelType.notesMaster, in: deck.package).uri)
        #expect(try copy.notesTextFrame().paragraphs.last?.runs[0].bold == true)
        #expect(try copy.notesTextFrame().paragraphs.last?.runs[0].fontSize == 24)

        try original.appendNote("original only")
        try copy.appendNote("copy only")
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.slides[0].notesParagraphs == ["", "Rich note", "original only"])
        #expect(try reopened.slides[1].notesParagraphs == ["", "Rich note", "copy only"])
        for slide in reopened.slides {
            let part = try slide.part.related(by: RelType.notesSlide, in: reopened.package)
            #expect(try part.related(by: RelType.slide, in: reopened.package).uri == slide.part.uri)
            #expect(try part.dom().firstChild(named: "foreign:payload")?.serialized()
                == dom.firstChild(named: "foreign:payload")?.serialized())
        }
    }

    @Test(arguments: [0, 1]) func deletingEitherDuplicatePreservesOtherNotes(index: Int) throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes("talk track")
        try deck.slides.duplicate(at: 0)
        let removed = try deck.slides[index].part.related(by: RelType.notesSlide, in: deck.package).uri
        let survivor = try deck.slides[1 - index].part.uri
        try deck.slides.remove(at: index)
        #expect(deck.package.parts[removed] == nil)
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.slides[0].part.uri == survivor)
        #expect(try reopened.slides[0].notesText == "talk track")
        let notes = try reopened.slides[0].part.related(by: RelType.notesSlide, in: reopened.package)
        #expect(try notes.related(by: RelType.slide, in: reopened.package).uri == survivor)
        #expect(try reopened.validate().isEmpty)
    }

    @Test func deletingOwnerOfPreviouslySharedNotesRetargetsBacklink() throws {
        let deck = try Presentation()
        let original = try deck.slides[0]
        try original.setNotes("shared old deck")
        let notes = try original.part.related(by: RelType.notesSlide, in: deck.package)
        let second = try deck.slides.add()
        second.part.rels.add(type: RelType.notesSlide, target: second.part.uri.relativeReference(to: notes.uri))
        try deck.slides.remove(at: 0)
        #expect(second.notesText == "shared old deck")
        #expect(try notes.related(by: RelType.slide, in: deck.package).uri == second.part.uri)
        #expect(try deck.validate().isEmpty)
    }

    @Test func failedAnnotationDuplicateLeavesPackageUnchanged() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes("valid notes")
        let slide = try deck.slides[0]
        let broken = deck.package.addPart(uri: PackURI("/ppt/comments/broken.xml"),
            contentType: ModernComments.commentsContentType, blob: Data("<broken>".utf8))
        slide.part.rels.add(type: ModernComments.commentsRelType, target: "../comments/broken.xml")
        let before = try deck.serializedData()
        #expect(throws: (any Error).self) { try deck.slides.duplicate(at: 0) }
        #expect(try deck.serializedData() == before)
        broken.replaceBlob(Data("<p188:cmLst xmlns:p188=\"\(ModernComments.ns)\"/>".utf8))
        slide.part.rels.add(type: RelType.notesSlide, target: "../notesSlides/missing.xml")
        let beforeMissing = try deck.serializedData()
        #expect(throws: (any Error).self) { try deck.slides.duplicate(at: 0) }
        #expect(try deck.serializedData() == beforeMissing)
    }

    @Test func multiParagraphNotesRoundTrip() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes(["First line of the talk track.", "Second beat.", "Land the point."])
        try deck.slides[0].appendNote("And a closing aside.")
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.slides[0].notesParagraphs == ["First line of the talk track.", "Second beat.", "Land the point.", "And a closing aside."])
    }

    @Test func emptyNotesArrayIsValid() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes([String]())
        #expect(try deck.validate().isEmpty)
        _ = try Presentation(data: try deck.serializedData())
    }

}
