import Foundation
import Testing
import Rostrum
@testable import LecternCore

/// File-backed library → inspector/previews → exporter → reopen integration.
/// These exercise the UI-free pipeline, not native app or Office interactions.
@Suite struct FeaturePipelineTests {
    private func scratch() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lectern-features-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func files(in directory: URL) throws -> [String: Data] {
        let entries = try #require(FileManager.default.enumerator(at: directory,
            includingPropertiesForKeys: [.isRegularFileKey]))
        var result: [String: Data] = [:]
        for case let url as URL in entries where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            result[String(url.path.dropFirst(directory.path.count + 1))] = try Data(contentsOf: url)
        }
        return result
    }

    private func table(on slide: Slide) throws -> Table {
        let tables = slide.shapes.all.compactMap { ($0 as? TableFrame)?.table }
        return try #require(tables.first)
    }

    @Test func authoredFeaturesSurviveInspectionExtractionAndReopen() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let deck = try FeaturePipelineFixture.make()
        let original = try deck.serializedData()
        #expect(try FeaturePipelineFixture.make().serializedData() == original)
        let pinned = try #require(Bundle.module.url(forResource: "authored-features", withExtension: "pptx", subdirectory: "Fixtures/FeaturePipeline"))
        #expect(try Data(contentsOf: pinned) == original)
        let file = directory.appendingPathComponent("FeaturePipeline.pptx")
        try deck.save(to: file)
        var events: [DeckInspector.Event] = []
        let inspection = try DeckInspector.inspect(deckAt: file) { events.append($0) }
        #expect(inspection.slideCount == 4)
        #expect(inspection.schemaIssues.isEmpty && inspection.readWarnings.isEmpty && inspection.outlineWarnings.isEmpty)
        #expect(inspection.previewSlideNumbers == [1, 2, 3, 4])
        #expect(inspection.previews.count == 4)
        #expect(inspection.previewDiagnostics.allSatisfy { $0.failure == nil })
        #expect(events.first == .opening && events.last == .finished)
        #expect(events.filter { if case .rendering = $0 { return true }; return false }.count == 5)
        #expect(inspection.sections.map(\.name) == ["Tables", "Evidence and copies", "Imported"])
        #expect(inspection.sections.map(\.slideIndices) == [[0], [1, 2], [3]])
        #expect(inspection.slides.map(\.tableCount) == [1, 0, 0, 1])
        #expect(inspection.slides[0].tables[0].rows[0] == ["Quarter", "Plan", "Actual"])
        #expect(inspection.slides[0].tables[0].rows[2] == ["Total", "27", ""])
        #expect(inspection.slides[3].tables[0].rows == [["Imported style", "Preserved graph"]])
        #expect(inspection.previews[3].contains("#DCF4E6"))
        #expect(inspection.slides[0].notes == ["Explain the quarterly table.\nThe merged total is intentional."])
        for index in [1, 2] {
            let digest = inspection.slides[index]
            #expect(digest.bullets.contains("Revenue grew 25%"))
            #expect(digest.assetNames.count == 1)
            let modern = try #require(digest.comments.first { $0.kind == "modern" })
            let legacy = try #require(digest.comments.first { $0.kind == "legacy" })
            #expect(Set(digest.comments.map(\.id)).count == 2)
            #expect(modern.author == "Ada Lovelace" && modern.text == "Check the revenue source.")
            #expect(modern.resolved && modern.replyCount == 1)
            #expect(modern.replies.map(\.text) == ["Source verified against the ledger."])
            #expect(modern.replies.map(\.author) == ["Grace Hopper"])
            #expect(legacy.author == "Legacy Reviewer" && legacy.text == "Keep the original image bytes.")
            #expect(legacy.replyCount == 0 && !legacy.resolved)
            #expect(inspection.previews[index].contains("font-weight=\"bold\""))
            #expect(inspection.previews[index].contains("font-style=\"italic\""))
            #expect(inspection.previews[index].contains("clipPath"))
        }
        #expect(try Data(contentsOf: file) == original)
        let again = try DeckInspector.inspect(deckAt: file)
        #expect(again.previews == inspection.previews)
        #expect(again.previewDiagnostics.flatMap(\.issues) == inspection.previewDiagnostics.flatMap(\.issues))

        let outcome = try DeckExporter.export(deckAt: file, into: directory)
        #expect(outcome.slideCount == 4 && outcome.assetsWritten == 2 && outcome.chartsWritten == 0)
        #expect(outcome.warnings.isEmpty)
        let markdown = try String(contentsOf: outcome.markdownFile, encoding: .utf8)
        for text in ["Quarter", "Actual", "27", "Revenue grew 25%", "Explain the quarterly table.",
                     "Check the revenue source.", "Source verified against the ledger.", "Keep the original image bytes.",
                     "Evidence and copies", "Imported style", "Preserved graph"] {
            #expect(markdown.contains(text))
        }
        let extracted = try files(in: outcome.directory)
        #expect(extracted.filter { $0.key.hasSuffix(".png") }.count == 2)
        #expect(extracted.filter { $0.key.hasSuffix(".png") }.values.allSatisfy { $0 == FeaturePipelineFixture.pixels })
        _ = try DeckExporter.export(deckAt: file, into: directory)
        #expect(try files(in: outcome.directory) == extracted)
        #expect(try Data(contentsOf: file) == original)

        let reopened = try Presentation(contentsOf: file)
        let first = try table(on: reopened.slides[0])
        #expect(try first.mergedRegions == [TableMergeRegion(row: 2, column: 1, rowSpan: 1, columnSpan: 2)])
        #expect(try first.cell(0, 0).border(.bottom)?.compoundStyle == "dbl")
        #expect(try first.cell(1, 0).border(.bottom)?.dashStyle == "dash")
        for index in [1, 2] {
            let slide = try reopened.slides[index]
            let picture = try #require(slide.shapes.all.compactMap { $0 as? Picture }.first)
            #expect(picture.crop == PictureCrop(left: 0.5, bottom: 0.25))
            #expect(picture.imageData == FeaturePipelineFixture.pixels)
            #expect(slide.comments.first?.replies.first?.text == "Source verified against the ledger.")
            #expect(slide.legacyComments.first?.text == "Keep the original image bytes.")
        }
        #expect(try table(on: reopened.slides[3]).styleID == FeaturePipelineFixture.importedStyle)
        let saved = directory.appendingPathComponent("Reopened.pptx")
        try reopened.save(to: saved)
        #expect(try Data(contentsOf: saved) == original)
    }

    @Test func independentOfficeTableImportKeepsMergeNotesAndSourceBytes() throws {
        let fixture = try #require(Bundle.module.url(forResource: "office-tables-v3", withExtension: "pptx", subdirectory: "Fixtures/FeaturePipeline"))
        let sourceBytes = try Data(contentsOf: fixture)
        let source = try Presentation(data: sourceBytes)
        // Foreign ZIP container metadata may normalize on serialization; compare
        // the source model before/after import and keep the original file exact.
        let sourceBeforeImport = try source.serializedData()
        let destination = try Presentation()
        _ = try destination.slides.import(from: source, at: 0)
        _ = try destination.slides.duplicate(at: 1)
        try destination.setSections([("Opening", 0), ("Independent table and copy", 1)])
        #expect(try source.serializedData() == sourceBeforeImport)
        #expect(try Data(contentsOf: fixture) == sourceBytes)
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("OfficeImport.pptx")
        try destination.save(to: file)
        let saved = try Data(contentsOf: file)
        let inspection = try DeckInspector.inspect(deckAt: file)
        #expect(inspection.previewSlideNumbers == [1, 2, 3])
        for index in [1, 2] {
            #expect(inspection.slides[index].tables[0].rows[0] == ["Merged origin", "", "R0 C2", "R0 C3"])
            #expect(inspection.slides[index].tables[0].rows[2][1] == "Mixed bold text")
            #expect(inspection.slides[index].notes == ["Independent table fixture notes."])
            #expect(inspection.previews[index].contains("Merged origin"))
            #expect(try table(on: destination.slides[index]).mergedRegions == [TableMergeRegion(row: 0, column: 0, rowSpan: 2, columnSpan: 2)])
        }
        let outcome = try DeckExporter.export(deckAt: file, into: directory)
        let markdown = try String(contentsOf: outcome.markdownFile, encoding: .utf8)
        #expect(markdown.components(separatedBy: "Merged origin").count - 1 == 2)
        #expect(markdown.components(separatedBy: "Independent table fixture notes.").count - 1 == 2)
        #expect(markdown.contains("Independent table and copy"))
        #expect(outcome.warnings.isEmpty)
        #expect(try Data(contentsOf: file) == saved)
        #expect(try Presentation(contentsOf: file).serializedData() == saved)
    }

    @Test(arguments: [nil, "0", "1200"] as [String?])
    func tableShadowAndKerningSurviveFileBackedPreviewAndExport(threshold: String?) throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let authoredTable = try slide.shapes.addTable(rows: 1, columns: 2,
            frame: Rect(x: .points(40), y: .points(40), width: .points(400), height: .points(80)))
        let styleID = "{73295817-8F61-41B6-8476-55A03F993E02}"
        try authoredTable.setStyleDefinition(XML.parse(Data("""
        <a:tblStyle xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" styleId="\(styleID)" styleName="Pipeline shadow">
        <a:tblBg><a:fill><a:solidFill><a:srgbClr val="EEEEEE"/></a:solidFill></a:fill>
        <a:effect><a:effectLst><a:outerShdw blurRad="50800" dist="25400" dir="5400000"><a:srgbClr val="123456"><a:alpha val="25000"/></a:srgbClr></a:outerShdw></a:effectLst></a:effect></a:tblBg>
        <a:wholeTbl><a:tcStyle><a:tcBdr/><a:fill><a:noFill/></a:fill></a:tcStyle></a:wholeTbl>
        </a:tblStyle>
        """.utf8)))
        for (column, text) in ["AV office", "AV retained"].enumerated() {
            let cell = try authoredTable.cell(0, column)
            cell.text = text
            cell.textFrame.paragraphs[0].runs[0].fontSize = 12
        }
        // Author the DrawingML attribute through the public package DOM; the
        // saved file is what the inspector and exporter independently reopen.
        func cells(in slide: Slide) throws -> [XML.Element] {
            let row = try #require(slide.part.dom().firstChild(named: "p:cSld")?
                .firstChild(named: "p:spTree")?.firstChild(named: "p:graphicFrame")?
                .firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?
                .firstChild(named: "a:tbl")?.firstChild(named: "a:tr"))
            return row.children(named: "a:tc")
        }
        let authoredCells = try cells(in: slide)
        #expect(authoredCells.count == 2)
        // Native PowerPoint distinguishes explicit zero (off) from omission
        // and a positive threshold reached by the rendered 12 pt run.
        for (cell, threshold) in zip(authoredCells, [Optional("2400"), threshold]) {
            let properties = try #require(cell.firstChild(named: "a:txBody")?
                .firstChild(named: "a:p")?.firstChild(named: "a:r")?.firstChild(named: "a:rPr"))
            properties[attribute: "kern"] = threshold
        }
        slide.part.markDirty()
        try slide.setNotes("The table shadow is a preview approximation; retain the original formatting.")

        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("ShadowAndKerning.pptx")
        try deck.save(to: file)
        let sourceBytes = try Data(contentsOf: file)
        let inspection = try DeckInspector.inspect(deckAt: file)
        #expect(inspection.slideCount == 1 && inspection.previewSlideNumbers == [1])
        #expect(inspection.slides[0].tables[0].rows == [["AV office", "AV retained"]])
        let preview = try #require(inspection.previews.first)
        let previewRoot = try XML.parse(Data(preview.utf8))
        let filter = try #require(previewRoot.firstChild(named: "defs")?.firstChild(named: "filter"))
        #expect(filter.firstChild(named: "feGaussianBlur") != nil)
        let spans = previewRoot.children(named: "text").flatMap { $0.children(named: "tspan") }
        let disabled = try #require(spans.first { $0.textContent == "AV office" })
        let comparison = try #require(spans.first { $0.textContent == "AV retained" })
        #expect(disabled[attribute: "kerning"] == "0")
        #expect(comparison[attribute: "kerning"] == (threshold == "0" ? "0" : nil))
        let diagnostic = try #require(inspection.previewDiagnostics.first { $0.slideNumber == 1 })
        let shadowIssue = try #require(diagnostic.issues.first {
            $0.code == "omittedEffect" && $0.impact == "approximation" && $0.path.contains("/a:tblBg[")
        })
        #expect(shadowIssue.partURI == "/ppt/tableStyles.xml")
        #expect(diagnostic.messages.contains(shadowIssue.message))
        #expect(diagnostic.failure == nil && inspection.hasFindings)
        #expect(try Data(contentsOf: file) == sourceBytes)

        let outcome = try DeckExporter.export(deckAt: file, into: directory)
        #expect(outcome.slideCount == 1 && outcome.warnings.isEmpty)
        let markdown = try String(contentsOf: outcome.markdownFile, encoding: .utf8)
        for text in ["AV office", "AV retained", "retain the original formatting."] {
            #expect(markdown.contains(text))
        }
        #expect(try Data(contentsOf: file) == sourceBytes)
        let reopened = try Presentation(contentsOf: file)
        #expect(try table(on: reopened.slides[0]).styleID == styleID)
        let retainedCells = try cells(in: reopened.slides[0])
        #expect(retainedCells.map { $0.firstChild(named: "a:txBody")?.firstChild(named: "a:p")?
            .firstChild(named: "a:r")?.firstChild(named: "a:rPr")?[attribute: "kern"] } == [Optional("2400"), threshold])
        let retainedStyle = try reopened.package.part(at: PackURI("/ppt/tableStyles.xml")).dom()
            .children(named: "a:tblStyle").first { $0[attribute: "styleId"] == styleID }
        #expect(retainedStyle?.firstChild(named: "a:tblBg")?.firstChild(named: "a:effect")?
            .firstChild(named: "a:effectLst")?.firstChild(named: "a:outerShdw")?[attribute: "blurRad"] == "50800")
        #expect(try reopened.serializedData() == sourceBytes)
    }

    @Test func unsupportedPreviewFormattingRemainsDiagnosedWithoutLosingExportedContent() throws {
        let deck = try FeaturePipelineFixture.make()
        let first = try table(on: deck.slides[0])
        try first.cell(0, 0).setBorder(.bottom, line: Line(color: Color("336699"), width: .points(4), compound: .triple))
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("UnsupportedBorder.pptx")
        try deck.save(to: file)
        let saved = try Data(contentsOf: file)
        let inspection = try DeckInspector.inspect(deckAt: file)
        let diagnostic = try #require(inspection.previewDiagnostics.first { $0.slideNumber == 1 })
        #expect(diagnostic.issues.contains { $0.code == "unsupportedBorder" && $0.partURI.hasPrefix("/ppt/slides/") && !$0.path.isEmpty })
        #expect(diagnostic.failure == nil && inspection.previewSlideNumbers == [1, 2, 3, 4])
        #expect(inspection.hasFindings)
        let outcome = try DeckExporter.export(deckAt: file, into: directory)
        #expect(try String(contentsOf: outcome.markdownFile, encoding: .utf8).contains("Quarter"))
        #expect(try Data(contentsOf: file) == saved)
        let reopened = try Presentation(contentsOf: file)
        #expect(try table(on: reopened.slides[0]).cell(0, 0).border(.bottom)?.compoundStyle == "tri")
    }
}
