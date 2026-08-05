import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct DeckWorkbenchTests {
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

    @Test func opensAndDescribesARealPresentation() async throws {
        let source = URL(fileURLWithPath: "/tmp/quarterly-review.pptx")
        let data = try deckData()
        let workbench = try DeckWorkbench(data: data, sourceURL: source)

        let inspection = try await workbench.inspect()

        #expect(inspection.fileName == "quarterly-review.pptx")
        #expect(inspection.byteCount == data.count)
        #expect(inspection.documentKind == "Presentation (.pptx)")
        #expect(inspection.properties.title == "Quarterly Review")
        #expect(inspection.properties.author == "Finance")
        #expect(inspection.properties.company == "Northwind")
        #expect(inspection.slideCount == 4)
        #expect(inspection.slides.count == 4)
        #expect(inspection.slides[2].notes.contains("Say this out loud"))
        #expect(inspection.slides[2].comments.first?.author == "Ada")
        #expect(inspection.charts.count == 1)
        #expect(inspection.charts[0].plotTypes == ["lineChart"])
        #expect(inspection.charts[0].series.first?.values == [12, 18])
        #expect(inspection.sections.map(\.name) == ["Opening", "Results"])
        #expect(inspection.masters.count == 1)
        #expect(inspection.validationIssues.isEmpty)
    }

    @Test func rendersOnlyTheRequestedSlide() async throws {
        let workbench = try DeckWorkbench(
            data: try deckData(),
            sourceURL: URL(fileURLWithPath: "/tmp/deck.pptx"))

        let svg = try await workbench.renderSlide(at: 1, pixelWidth: 480)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("Q3 Review"))
        #expect(svg.contains("width=\"480\""))
    }

    @Test func rejectsEmptyAndNonPowerPointData() async {
        #expect(throws: DeckWorkbenchError.self) {
            _ = try DeckWorkbench(data: Data(), sourceURL: URL(fileURLWithPath: "/tmp/empty.pptx"))
        }
        #expect(throws: DeckWorkbenchError.self) {
            _ = try DeckWorkbench(
                data: Data("not a zip".utf8),
                sourceURL: URL(fileURLWithPath: "/tmp/not-a-deck.pptx"))
        }
    }

    @Test func enforcesTheUntrustedFileReadBudget() throws {
        let data = try deckData()

        #expect(throws: DeckWorkbenchError.self) {
            _ = try DeckWorkbench(
                data: data,
                sourceURL: URL(fileURLWithPath: "/tmp/deck.pptx"),
                limits: .init(totalUncompressedBytes: 0))
        }
    }

    @Test func oneBrokenSlideDoesNotHideTheRestOfTheDeck() async throws {
        let deck = try Presentation()
        try deck.titleSlide("Still readable")
        let main = try deck.package.mainDocumentPart()
        let broken = try #require(main.rels.all(ofType: RelType.slide).last)
        main.rels.remove(rId: broken.rId)

        let workbench = try DeckWorkbench(
            data: try deck.serializedData(),
            sourceURL: URL(fileURLWithPath: "/tmp/damaged.pptx"))
        let inspection = try await workbench.inspect()

        #expect(inspection.slideCount == 2)
        #expect(inspection.slides.count == 1)
        #expect(inspection.validationIssues.contains { $0.contains("slide 2 cannot be resolved") })
        await #expect(throws: DeckWorkbenchError.self) {
            _ = try await workbench.renderSlide(at: 1)
        }
    }

    @Test func reportsTemplateAndSlideShowKinds() async throws {
        for kind in [DocumentKind.template, .slideShow] {
            let deck = try Presentation()
            deck.documentKind = kind
            let workbench = try DeckWorkbench(
                data: try deck.serializedData(),
                sourceURL: URL(fileURLWithPath: "/tmp/document"))

            let inspection = try await workbench.inspect()

            #expect(inspection.documentKind.contains(kind == .template ? ".potx" : ".ppsx"))
        }
    }
}
