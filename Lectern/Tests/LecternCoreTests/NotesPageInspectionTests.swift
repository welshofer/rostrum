import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct NotesPageInspectionTests {
    private func fixture() throws -> URL {
        try #require(Bundle.module.url(forResource: "notes-geometry", withExtension: "pptx",
                                       subdirectory: "Fixtures/NotesPage"))
    }

    @Test func fileBackedNotesPreviewMatchesLibraryAndDoesNotChangeSource() throws {
        let url = try fixture()
        let before = try Data(contentsOf: url)
        let inspection = try DeckInspector.inspect(deckAt: url, renderPreviews: false)
        #expect(inspection.previews.isEmpty)
        #expect(inspection.slides[0].hasNotesPage)
        let preview = try DeckInspector.inspectNotesPage(deckAt: url, slideNumber: 1)
        let deck = try Presentation(data: before)
        _ = deck.registerEmbeddedFonts()
        let explicit = DeckDetailExtractor.declaredFonts(in: try deck.slides[0].part.dom())
        _ = InstalledFonts.register(in: deck, families: try InspectionFonts.families(in: deck, explicit: explicit, includeNotes: true))
        let reference = try deck.renderNotesSVGReportingProblems(slideAt: 0, pixelWidth: 960)
        #expect(preview.fileURL == url && preview.slideNumber == 1)
        #expect(preview.svg == reference.svg)
        #expect(preview.svg.contains("Geometry-preserving import"))
        #expect(preview.svg.contains("data:image/svg+xml;base64,"))
        #expect(preview.diagnostics == SlidePreviewDiagnostics(slideNumber: 1, problems: reference.problems))
        #expect(try DeckInspector.inspectNotesPage(deckAt: url, slideNumber: 1).svg == preview.svg)
        #expect(try Data(contentsOf: url) == before)
    }

    @Test func notesUseInspectionReadLimitAndRejectInvalidSlideNumbers() throws {
        let url = try fixture()
        #expect(throws: DeckInspectionError.self) {
            _ = try DeckInspector.inspectNotesPage(deckAt: url, slideNumber: 1,
                                                   limits: .init(totalUncompressedBytes: 0))
        }
        for number in [Int.min, 0, 2, Int.max] {
            #expect(throws: DeckInspectionError.self) {
                _ = try DeckInspector.inspectNotesPage(deckAt: url, slideNumber: number)
            }
        }
    }

    @Test func emptyNotesRemainDiscoverableAndMissingNotesAreNotCreated() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("notes.pptx")
        let deck = try Presentation()
        try deck.save(to: url)
        let before = try Data(contentsOf: url)
        #expect(try !DeckInspector.inspect(deckAt: url, renderPreviews: false).slides[0].hasNotesPage)
        #expect(throws: RostrumError.self) {
            _ = try DeckInspector.inspectNotesPage(deckAt: url, slideNumber: 1)
        }
        #expect(try Data(contentsOf: url) == before)
        try deck.slides[0].setNotes("")
        try deck.save(to: url)
        #expect(try DeckInspector.inspect(deckAt: url, renderPreviews: false).slides[0].hasNotesPage)
        #expect(try DeckInspector.inspectNotesPage(deckAt: url, slideNumber: 1).svg.contains("<svg"))
    }

    @Test func fontDiscoveryIncludesNotesAndTheirMaster() throws {
        let deck = try Presentation(contentsOf: fixture())
        let page = try #require(deck.package.parts.values.first { $0.contentType == ContentType.notesSlide })
        let master = try #require(deck.package.parts.values.first { $0.contentType == ContentType.notesMaster })
        for (part, family) in [(page, "Notes Only"), (master, "Notes Master Only")] {
            let root = try part.dom()
            root.appendElement(XML.Element("a:latin", attributes: [("typeface", family)]))
        }
        let families = try InspectionFonts.families(in: deck, explicit: [], includeNotes: true)
        #expect(families.contains("Notes Only") && families.contains("Notes Master Only"))
        let slideFamilies = try InspectionFonts.families(in: deck, explicit: [])
        #expect(!slideFamilies.contains("Notes Only") && !slideFamilies.contains("Notes Master Only"))
    }

    @Test func alreadyCancelledRequestDoesNotOpenTheFile() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try DeckInspector.inspectNotesPage(deckAt: URL(fileURLWithPath: "/missing-notes.pptx"), slideNumber: 1)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
