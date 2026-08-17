import Foundation
import Testing
import Rostrum
@testable import LecternCore

/// The deeper half of an inspection — properties, masters, sections, charts,
/// comments and the untrusted-file read budget.
///
/// `DeckInspectorTests` covers the counts and the text; this covers what the
/// deck is made of.
@Suite struct DeckInspectionDetailTests {
    private func deckData() throws -> Data {
        let deck = try Presentation()
        deck.documentProperties.title = "Quarterly Review"
        deck.documentProperties.author = "Finance"
        deck.documentProperties.company = "Northwind"
        try deck.titleSlide("Q3 Review", subtitle: "Northwind")
        let content = try deck.bulletSlide("Highlights", ["ARR up", "NPS up"])
        try content.setNotes("Say this out loud.")
        try content.addComment("Check the NPS source.", author: "Ada")
        try deck.chartSlide(
            "Revenue",
            .line,
            ChartData(
                categories: ["Q1", "Q2"],
                series: [.init(name: "ARR", values: [12, 18])]))
        try deck.setSections([("Opening", 0), ("Results", 2)])
        return try deck.serializedData()
    }

    /// Inspection reads from disk, so every case needs a real file.
    private func withDeckFile<T>(_ data: Data,
                                 named name: String = "quarterly-review.pptx",
                                 _ body: (URL) throws -> T) throws -> T {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return try body(url)
    }

    @Test func opensAndDescribesARealPresentation() throws {
        let data = try deckData()
        let inspection = try withDeckFile(data) {
            try DeckInspector.inspect(deckAt: $0, renderPreviews: false)
        }

        #expect(inspection.fileName == "quarterly-review.pptx")
        #expect(inspection.byteCount == data.count)
        #expect(inspection.documentKind == "Presentation (.pptx)")
        #expect(inspection.properties.title == "Quarterly Review")
        #expect(inspection.properties.author == "Finance")
        #expect(inspection.properties.company == "Northwind")
        #expect(!inspection.properties.isEmpty)
        #expect(inspection.slideCount == 4)
        #expect(inspection.slides.count == 4)
        #expect(inspection.slides[2].notes.joined().contains("Say this out loud"))
        #expect(inspection.slides[2].comments.first?.author == "Ada")
        #expect(inspection.slides[2].shapeCount > 0)
        #expect(!inspection.slides[2].layoutName.isEmpty)
        #expect(inspection.charts.count == 1)
        #expect(inspection.charts[0].plotTypes == ["lineChart"])
        #expect(inspection.charts[0].series.first?.values == [12, 18])
        #expect(inspection.charts[0].categories == ["Q1", "Q2"])
        #expect(inspection.sections.map(\.name) == ["Opening", "Results"])
        #expect(inspection.sections.first?.slideCount == 2)
        #expect(inspection.masters.count == 1)
        #expect(!inspection.masters[0].layoutNames.isEmpty)
        #expect(!inspection.hasFindings)
    }

    @Test func rendersPreviewsWhenAsked() throws {
        let inspection = try withDeckFile(try deckData()) {
            try DeckInspector.inspect(deckAt: $0)
        }

        #expect(inspection.previews.count == inspection.slideCount)
        #expect(inspection.previews.allSatisfy { $0.contains("<svg") })
        #expect(inspection.previews.contains { $0.contains("Q3 Review") })
    }

    @Test func skippingPreviewsCostsNothingElse() throws {
        let inspection = try withDeckFile(try deckData()) {
            try DeckInspector.inspect(deckAt: $0, renderPreviews: false)
        }

        #expect(inspection.previews.isEmpty)
        #expect(inspection.slides.count == 4)
    }

    @Test func reportsTheFontsADeckLeansOn() throws {
        let inspection = try withDeckFile(try deckData()) {
            try DeckInspector.inspect(deckAt: $0, renderPreviews: false)
        }

        #expect(!inspection.themeFonts.isEmpty)
    }

    @Test func rejectsEmptyAndNonPowerPointData() throws {
        try withDeckFile(Data(), named: "empty.pptx") { url in
            #expect(throws: DeckInspectionError.self) {
                _ = try DeckInspector.inspect(deckAt: url)
            }
        }
        try withDeckFile(Data("not a zip".utf8), named: "not-a-deck.pptx") { url in
            #expect(throws: DeckInspectionError.self) {
                _ = try DeckInspector.inspect(deckAt: url)
            }
        }
    }

    /// Inspection is the one path that opens a file from outside the app's
    /// container, so it must not inherit Rostrum's unlimited default.
    @Test func enforcesTheUntrustedFileReadBudget() throws {
        try withDeckFile(try deckData()) { url in
            #expect(throws: DeckInspectionError.self) {
                _ = try DeckInspector.inspect(deckAt: url,
                                              renderPreviews: false,
                                              limits: .init(totalUncompressedBytes: 0))
            }
        }
    }

    @Test func oneBrokenSlideDoesNotHideTheRestOfTheDeck() throws {
        let deck = try Presentation()
        try deck.titleSlide("Still readable")
        let main = try deck.package.mainDocumentPart()
        let broken = try #require(main.rels.all(ofType: RelType.slide).last)
        main.rels.remove(rId: broken.rId)

        let inspection = try withDeckFile(try deck.serializedData(), named: "damaged.pptx") {
            try DeckInspector.inspect(deckAt: $0, renderPreviews: false)
        }

        #expect(inspection.slideCount == 2)
        #expect(inspection.hasFindings)
        #expect(inspection.outlineWarnings.contains { $0.contains("slide 2 cannot be resolved") })
    }

    @Test func reportsTemplateAndSlideShowKinds() throws {
        for kind in [DocumentKind.template, .slideShow] {
            let deck = try Presentation()
            deck.documentKind = kind
            let inspection = try withDeckFile(try deck.serializedData(), named: "document.pptx") {
                try DeckInspector.inspect(deckAt: $0, renderPreviews: false)
            }

            #expect(inspection.documentKind.contains(kind == .template ? ".potx" : ".ppsx"))
        }
    }
}
