import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct DocumentLabRecipesTests {
    private static let ids: [LibraryDemoID] = [.slides, .charts, .chartEditing, .smartArt, .notes, .comments, .sections, .slideImport]

    @Test func catalogIsCompleteAndUnique() {
        #expect(Set(DocumentLabRecipes.catalog.map(\.id)) == Set(Self.ids))
        #expect(DocumentLabRecipes.catalog.count == Self.ids.count)
        #expect(DocumentLabRecipes.catalog.allSatisfy { !$0.operations.isEmpty && !$0.inputs.isEmpty })
        #expect(DocumentLabRecipes.catalog.first { $0.id == .smartArt }?.limitations.isEmpty == false)
    }

    @Test(arguments: Self.ids, [false, true])
    func everyVariantSavesAndReopens(id: LibraryDemoID, alternative: Bool) throws {
        // Both bounds are exercised across every recipe; punctuation tests escaping.
        let options = LibraryLabOptions(text: "Lab & <review> 😀", accentHex: "A63869",
                                        sampleSize: alternative ? 12 : 2, alternative: alternative)
        let draft = try DocumentLabRecipes.make(id, options: options)
        for check in draft.checks { #expect(check.passed, "\(id.rawValue): \(check.name): \(check.detail)") }
        let data = try draft.deck.serializedData()
        #expect(try draft.deck.serializedData() == data)
        let reopened = try Presentation(data: data)
        let checks = try draft.verify(reopened)
        #expect(!checks.isEmpty)
        for check in checks { #expect(check.passed, "\(id.rawValue): \(check.name): \(check.detail)") }
        #expect(try reopened.validate().isEmpty)
        #expect(try reopened.serializedData() == data)
        let twice = try Presentation(data: reopened.serializedData())
        for check in try draft.verify(twice) { #expect(check.passed, "Second reopen: \(check.name)") }
        if let before = draft.before {
            #expect(before != data)
            #expect(try Presentation(data: before).validate().isEmpty)
        }
        for (name, extra) in draft.extraFiles where name.hasSuffix(".pptx") {
            #expect(try Presentation(data: extra).validate().isEmpty)
        }
    }

    @Test(arguments: Self.ids, [false, true])
    func everyRecipeAcceptsMultilineText(id: LibraryDemoID, alternative: Bool) throws {
        let input = "Line one\nLine two & <three> 😀"
        let draft = try DocumentLabRecipes.make(id, options: .init(text: input, sampleSize: 3, alternative: alternative))
        let saved = try draft.deck.serializedData()
        let reopened = try Presentation(data: saved)
        for check in draft.checks + (try draft.verify(reopened)) {
            #expect(check.passed, "Multiline \(id.rawValue): \(check.name): \(check.detail)")
        }
        #expect(try reopened.validate().isEmpty)
        #expect(try reopened.serializedData() == saved)
        if id == .comments {
            #expect(try reopened.slides[0].comments.first?.textParagraphs == ["Line one", "Line two & <three> 😀", "Edited thread"])
        } else if id == .charts {
            #expect(reopened.charts.first?.title == input)
            #expect(reopened.charts.first?.series.first?.name == input)
        }
    }

    @Test(arguments: [2, 12])
    func percentStackedUsesNativePercentageAxis(sampleSize: Int) throws {
        let draft = try DocumentLabRecipes.make(.charts, options: .init(sampleSize: sampleSize))
        let reopened = try Presentation(data: draft.deck.serializedData())
        let plotArea = try reopened.charts[2].part.dom().firstChild(named: "c:chart")?.firstChild(named: "c:plotArea")
        let axis = try #require(plotArea?.firstChild(named: "c:valAx"))
        #expect(plotArea?.firstChild(named: "c:barChart")?.firstChild(named: "c:grouping")?[attribute: "val"] == "percentStacked")
        #expect(axis.firstChild(named: "c:scaling")?.firstChild(named: "c:min")?[attribute: "val"] == "0")
        #expect(axis.firstChild(named: "c:scaling")?.firstChild(named: "c:max")?[attribute: "val"] == "1")
        #expect(axis.firstChild(named: "c:majorUnit")?[attribute: "val"] == "0.25")
        #expect(axis.firstChild(named: "c:numFmt")?[attribute: "formatCode"] == "0%")
        #expect(axis.firstChild(named: "c:title")?.textContent == "Share")
    }

    @Test func chartEditingHasIndependentExpectedDataAndAtomicRefusals() throws {
        let draft = try DocumentLabRecipes.make(.chartEditing,
                                               options: .init(text: "Revenue", sampleSize: 3))
        let reopened = try Presentation(data: draft.deck.serializedData())
        let chart = try #require(reopened.charts.first)
        #expect(chart.plotType == "barChart")
        #expect(chart.categories == ["Revised Sample 1", "Revised Sample 2", "Revised Sample 3"])
        #expect(chart.series.map(\.name) == ["Updated Revenue", "Added"])
        #expect(chart.series.map(\.values) == [[13, 16, 19], [7, 14, 21]])
        #expect(reopened.charts.count == 4)
        #expect(reopened.charts[1].plotTypes == ["barChart", "lineChart"])
        #expect(reopened.charts[1].series.map(\.values) == [[13, 16, 19], [14, 15, 16]])
        #expect(reopened.charts[2].series.map(\.values) == [[3, 6, 9]])
        #expect(reopened.charts[3].xySeries.first?.points == [.init(x: 1, y: 2), .init(x: 2, y: 4), .init(x: 3, y: 6)])
        let original = try Presentation(data: #require(draft.before))
        #expect(original.charts.first?.series.map(\.values) == [[3, 6, 9], [4, 5, 6]])
        #expect(draft.checks.filter { $0.name.contains("atomic") }.count == 9)
        #expect(draft.checks.allSatisfy { $0.passed })
    }

    @Test func galleryContainsEveryPlotFamilyAndTwoAxisCombo() throws {
        let draft = try DocumentLabRecipes.make(.charts, options: .init(sampleSize: 3))
        let reopened = try Presentation(data: draft.deck.serializedData())
        #expect(reopened.charts.count == 12)
        #expect(Set(reopened.charts.flatMap(\.plotTypes)) == Set(["barChart", "lineChart", "areaChart", "pieChart", "doughnutChart", "radarChart", "scatterChart", "bubbleChart"]))
        let combo = try #require(reopened.charts.last)
        let xml = try combo.part.dom().serialized()
        #expect(combo.isCombo)
        #expect(xml.contains("Secondary units"))
        #expect(combo.series.count == 2)
        #expect(reopened.charts[9].xySeries.first?.points == [.init(x: 1, y: 1), .init(x: 2, y: 4), .init(x: 3, y: 9)])
        #expect(reopened.charts[10].xySeries.first?.points.last?.size == 15)
    }

    @Test(arguments: [false, true])
    func smartArtGalleryIncludesEveryLayoutAndWarnsAboutPyramid(alternative: Bool) throws {
        let draft = try DocumentLabRecipes.make(.smartArt, options: .init(text: "Stage", sampleSize: 3, alternative: alternative))
        let reopened = try Presentation(data: draft.deck.serializedData())
        #expect(reopened.slides.count == 4)
        let expectedURNs = ["urn:rostrum/basicBlockList", "urn:rostrum/basicProcess", "urn:rostrum/basicCycle", "urn:rostrum/basicPyramid"]
        let baseLabels = ["Stage · Step 1", "Stage · Step 2", "Stage · Step 3"]
        let labels = alternative ? Array(baseLabels.reversed()) : baseLabels
        for (index, urn) in expectedURNs.enumerated() {
            let layout = try reopened.package.part(at: PackURI("/ppt/diagrams/layout\(index + 1).xml")).dom()
            #expect(layout[attribute: "uniqueId"] == urn)
            #expect(try reopened.slides[index].smartArtTexts == [labels])
        }
        #expect(Set(expectedURNs) == Set(SmartArt.Layout.allCases.map(\.urn)))
        let cycle = try reopened.package.part(at: PackURI("/ppt/diagrams/layout3.xml")).dom().serialized()
        #expect(cycle.contains("type=\"cycle\""))
        let pyramid = try reopened.package.part(at: PackURI("/ppt/diagrams/layout4.xml")).dom().serialized()
        #expect(pyramid.contains("type=\"pyra\""))
        let lastSlideText = try reopened.slides[3].shapes.all.compactMap { $0.textFrame?.text }.joined(separator: "\n")
        #expect(lastSlideText.contains("experimental"))
        #expect(lastSlideText.contains("block grid"))
        let recipe = try #require(DocumentLabRecipes.catalog.first { $0.id == .smartArt })
        #expect(recipe.limitations.contains { $0.contains("Pyramid is experimental") })
        #expect(draft.extraFiles["smartart-labels.txt"] == Data(labels.joined(separator: "\n").utf8))
    }

    @Test func notesImportsAndCopiesCannotMutateTheirSources() throws {
        let draft = try DocumentLabRecipes.make(.notes, options: .init(text: "Talk", sampleSize: 2))
        let reopened = try Presentation(data: draft.deck.serializedData())
        #expect(try reopened.slides[0].notesParagraphs == ["Talk · Cue 1", "Talk · Cue 2", "Original only"])
        #expect(try reopened.slides[1].notesParagraphs == ["Talk · Cue 1", "Talk · Cue 2", "Copy only"])
        #expect(try reopened.slides[2].notesParagraphs == ["Import source", "Talk", "Imported only"])
        let source = try Presentation(data: #require(draft.extraFiles["notes-source.pptx"]))
        #expect(try source.slides[0].notesParagraphs == ["Import source", "Talk"])
        #expect(try reopened.slides[0].notesTextFrame().paragraphs[0].runs[0].bold)
        #expect(try reopened.slides[1].notesTextFrame().paragraphs[0].runs[0].bold)
    }

    @Test func commentsPreserveUnicodeAnchorAndDeletedItemsStayDeleted() throws {
        let draft = try DocumentLabRecipes.make(.comments, options: .init(text: "Review", sampleSize: 2, alternative: true))
        let reopened = try Presentation(data: draft.deck.serializedData())
        let slide = try reopened.slides[0]
        #expect(slide.comments.count == 1)
        let thread = try #require(slide.comments.first)
        #expect(thread.text == "Review\nEdited thread")
        #expect(thread.replies.map(\.text) == ["Edited reply 1", "Edited reply 2"])
        #expect(thread.isResolved)
        #expect(thread.anchor == .text(slideID: 256, shapeID: try #require(slide.shapes.all.first?.shapeID), start: 7, length: 2))
        #expect(slide.legacyComments.map(\.text) == ["Review · Edited legacy"])
    }

    @Test func bulkImportRetainsOriginalDestinationAndUneditedSource() throws {
        let draft = try DocumentLabRecipes.make(.slideImport, options: .init(text: "Import", sampleSize: 2, alternative: true))
        let reopened = try Presentation(data: draft.deck.serializedData())
        #expect(reopened.slides.count == 4)
        #expect(try reopened.slides[1].shapes.all.first?.textFrame?.text == "Destination original")
        #expect(try reopened.slides[0].comments.first?.text == "Single import edited")
        #expect(try reopened.slides[2].comments.first?.text == "Review source 1")
        let source = try Presentation(data: #require(draft.extraFiles["import-source.pptx"]))
        #expect(source.slides.count == 2)
        #expect(try source.slides[0].comments.first?.text == "Review source 1")
        #expect(try source.slides[0].notesParagraphs == ["Speaker notes 1", "Import"])
        for index in [0, 2, 3] {
            let slide = try reopened.slides[index]
            let picture = try #require(slide.shapes.all.compactMap { $0 as? Picture }.first)
            #expect(picture.imageData == LibraryLabSupport.pixels)
            let tables = slide.shapes.all.compactMap { ($0 as? TableFrame)?.table }
            let table = try #require(tables.first)
            #expect(table.builtInStyle == .themedStyle1Accent1)
            #expect(try table.cell(1, 1).text == "Import")
        }
    }
}
