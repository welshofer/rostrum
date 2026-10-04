import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct PreviewDiagnosticsTests {
    private func temporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lectern-preview-diagnostics-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func healthyBlankPreviewStaysQuietAndKeepsTheSameSVG() throws {
        let deck = try Presentation()
        var previews = DeckPreviews()
        previews.append(slideAt: 0, from: deck)

        #expect(previews.svgs == [try deck.renderSVG(slideAt: 0, pixelWidth: 640)])
        #expect(previews.slideNumbers == [1])
        #expect(previews.titles == [""])
        #expect(previews.diagnostics.isEmpty)
    }

    @Test func fidelityFindingsKeepTheirSourceLocationsWithoutBlockingPreviews() throws {
        let deck = try Presentation()
        let slide = try deck.slides.add()
        for x in [0, 3] {
            let shape = try slide.shapes.addTextBox(
                Rect(x: .inches(Double(x)), y: .zero, width: .inches(2), height: .inches(1)))
            shape.textFrame?.text = "Missing face"
            shape.textFrame?.paragraphs[0].runs[0].fontName = "Not Registered QZX"
        }
        let report = try deck.renderSVGReportingProblems(slideAt: 1, pixelWidth: 640)
        let before = try deck.serializedData()
        var previews = DeckPreviews()
        previews.append(slideAt: 1, from: deck)

        #expect(previews.svgs == [report.svg])
        let diagnostics = try #require(previews.diagnostics.first)
        #expect(diagnostics.slideNumber == 2)
        #expect(diagnostics.failure == nil)
        #expect(diagnostics.issues.count == report.problems.fidelityIssues.count)
        for (actual, original) in zip(diagnostics.issues, report.problems.fidelityIssues) {
            #expect(actual.code == original.code.rawValue)
            #expect(actual.impact == original.impact.rawValue)
            #expect(actual.message == original.message)
            #expect(actual.partURI == original.location.partURI)
            #expect(actual.shapeID == original.location.shapeID)
            #expect(actual.path == original.location.path)
            #expect(original.location.slideIndex + 1 == diagnostics.slideNumber)
        }
        let missing = diagnostics.issues.filter { $0.code == "missingFont" }
        #expect(missing.count == 2)
        #expect(Set(missing.compactMap(\.shapeID)).count == 2)
        #expect(diagnostics.messages.count < diagnostics.issues.count)
        #expect(Set(diagnostics.messages).count == diagnostics.messages.count)
        #expect(try deck.serializedData() == before)
    }

    @Test func missingInheritanceKeepsSpecificFlagsAndAUsablePreview() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let relationship = try #require(slide.part.rels.first(ofType: RelType.slideLayout))
        slide.part.rels.remove(rId: relationship.rId)
        var previews = DeckPreviews()
        previews.append(slideAt: 0, from: deck)

        #expect(previews.svgs.count == 1)
        let diagnostics = try #require(previews.diagnostics.first)
        #expect(diagnostics.layoutUnresolved)
        #expect(!diagnostics.masterUnresolved)
        #expect(diagnostics.issues.contains { $0.code == "unresolvedInheritance" })
        #expect(diagnostics.messages == ["The slide layout could not be loaded; its content is missing from this preview."])
    }

    @Test func inspectionReportsAFailedPreviewWithoutRenumberingLaterSlides() throws {
        let deck = try Presentation()
        try deck.titleSlide("Second slide")
        try deck.titleSlide("Third slide")
        let main = try deck.package.mainDocumentPart()
        let first = try #require(main.rels.all(ofType: RelType.slide).first)
        main.rels.remove(rId: first.rId)
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("partial.pptx")
        try deck.serializedData().write(to: url)

        let inspection = try DeckInspector.inspect(deckAt: url)
        #expect(inspection.slideCount == 3)
        #expect(inspection.previewSlideNumbers == [1, 2, 3])
        #expect(inspection.previewTitles == ["", "Second slide", "Third slide"])
        #expect(inspection.previews.count == 3)
        #expect(inspection.previewRecords[0].svg == nil)
        #expect(inspection.previews[0].contains("Preview unavailable"))
        let failure = try #require(inspection.previewDiagnostics.first { $0.failure != nil })
        #expect(failure.slideNumber == 1)
        #expect(failure.messages == ["Preview could not be rendered."])
        #expect(inspection.hasFindings)
    }

    @Test func inspectionSurfacesFidelitySeparatelyAndSkippingPreviewsDoesNotClaimACheck() throws {
        let deck = try Presentation()
        try deck.chartSlide("Revenue", .line,
                            ChartData(categories: ["Q1", "Q2"], series: [.init(name: "ARR", values: [12, 18])]))
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("chart.pptx")
        try deck.serializedData().write(to: url)

        let inspection = try DeckInspector.inspect(deckAt: url)
        #expect(inspection.previews.count == inspection.slideCount)
        #expect(inspection.previewDiagnostics.contains {
            $0.slideNumber == 2 && $0.issues.contains { $0.code == "chartApproximation" }
        })
        #expect(inspection.schemaIssues.isEmpty)
        #expect(inspection.readWarnings.isEmpty)
        #expect(inspection.outlineWarnings.isEmpty)
        #expect(inspection.hasFindings)

        let skipped = try DeckInspector.inspect(deckAt: url, renderPreviews: false)
        #expect(skipped.previews.isEmpty)
        #expect(skipped.previewSlideNumbers.isEmpty)
        #expect(skipped.previewDiagnostics.isEmpty)
        #expect(!skipped.hasFindings)
    }

    @Test func generatedDeckRetainsChartDiagnosticsAndExistingWarningCategories() async throws {
        let deck = DeckIR(meta: Meta(title: "Quarterly review"), slides: [
            IRSlide(id: "title", layout: "title", title: "Quarterly review"),
            IRSlide(id: "chart", layout: "chart", title: "Revenue",
                    body: Body(chart: IRChart(kind: "line", categories: ["Q1", "Q2"],
                                             series: [IRSeries(name: "ARR", values: [12, 18])]))),
        ])
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try await DeckRenderer().render(deck, designURL: nil, notesEnabled: false,
                                                      into: directory, warnings: ["Existing plan warning"])

        #expect(FileManager.default.fileExists(atPath: result.url.path))
        #expect(result.previews.count == result.slideCount)
        #expect(result.previewSlideNumbers == [1, 2])
        #expect(result.previewDiagnostics.contains {
            $0.slideNumber == 2 && $0.issues.contains { $0.code == "chartApproximation" }
        })
        #expect(result.warnings == ["Existing plan warning"])
        #expect(result.schemaIssues.isEmpty)
        #expect(result.droppedContent.isEmpty)
    }
}
