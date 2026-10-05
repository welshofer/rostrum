import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct ListMarkerRecipeTests {
    @Test(arguments: [false, true])
    func allNativeMarkersAndBothPublicFitsSurviveSaving(alternative: Bool) throws {
        let draft = try PlatformLabRecipes.make(.listMarkers, options: .init(alternative: alternative))
        let reference = try PlatformLabRecipes.listMarkerReferences()
        #expect(draft.deck.slides.count == 5)
        #expect(draft.deck.slideSize.width == .points(720) && draft.deck.slideSize.height == .points(720))
        #expect(reference.cases.count == 24 && Set(reference.cases.map(\.id)).count == 24)
        #expect(reference.cases.reduce(0) { $0 + $1.glyphs.count } == 277)
        #expect(reference.cases.filter { !$0.omittedMarkers.isEmpty }.map(\.id) == ["inherited-percent75-serif", "local-follow-overrides-inherited", "ordinary-shape-master-only"])
        let pages = try (0..<4).map { try draft.deck.renderSVG(slideAt: $0) }
        for sample in reference.cases {
            #expect(PlatformLabRecipes.markerGlyphsMatch(svg: pages[sample.slide], sample: sample, aliases: PlatformLabRecipes.markerFaceAliases(svg: pages[sample.slide], fonts: draft.deck.fonts)), "\(sample.id)")
            let original = try PlatformLabRecipes.paragraphBody(draft.deck, named: sample.id, slideAt: sample.slide)
            let source = try XML.parse(Data(sample.textBodyXML.utf8))
            #expect(original.childElements.map { $0.serialized() } == source.childElements.map { $0.serialized() })
        }
        let hang18 = try #require(reference.cases.first { $0.id == "wide-number-hang18" })
        let hang6 = try #require(reference.cases.first { $0.id == "wide-number-hang6" })
        #expect(hang18.bodyLines.count == 3 && hang6.bodyLines.count == 4)
        #expect(hang6.bodyLines == ["BBB", "BBBBB", "BBBBBBBB", "Z"])
        let point = try #require(reference.cases.first { $0.id == "points14p5-scaled20x72p5" })
        #expect(point.glyphs.first?.rawPDFPaintScale == [15, 15])
        let regular = try #require(draft.deck.fonts.data(for: .init(family: "DejaVu Sans")))
        let bold = try #require(draft.deck.fonts.data(for: .init(family: "DejaVu Sans", bold: true)))
        let serif = try #require(draft.deck.fonts.data(for: .init(family: "DejaVu Serif")))
        #expect(regular != bold && regular != serif && bold != serif)
        var fitted: [RichTextLayout] = []
        for role in ["Shape.fitText", "TextFrame.fitText"] {
            let name = role + " marker copy"
            let layout = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: name, slideAt: 4)
            #expect(layout.fits && layout.diagnostics.isEmpty && layout.contentHeight <= 45)
            #expect(layout.lines.allSatisfy { $0.visibleWidth <= 130 })
            let body = try PlatformLabRecipes.paragraphBody(draft.deck, named: name, slideAt: 4)
            let norm = try #require(body.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit"))
            let scale = try #require(Double(norm[attribute: "fontScale"] ?? ""))
            #expect(scale > 0 && scale < 100_000)
            let paragraph = try #require(body.firstChild(named: "a:p")?.firstChild(named: "a:pPr"))
            #expect(paragraph[attribute: "indent"] == String(EMU.points(alternative ? -6 : -18).rawValue))
            #expect(paragraph.firstChild(named: "a:buAutoNum")?[attribute: "startAt"] == "12345")
            let source = try XML.parse(Data((alternative ? hang6 : hang18).textBodyXML.utf8))
            #expect(body.children(named: "a:p").map { $0.serialized() } == source.children(named: "a:p").map { $0.serialized() })
            fitted.append(layout)
        }
        #expect(fitted[0].lines == fitted[1].lines)
        let bytes = try draft.deck.serializedData()
        let reopened = try Presentation(data: bytes)
        for check in draft.checks + (try draft.verify(reopened)) { #expect(check.passed, "\(check.name): \(check.detail)") }
        #expect(try reopened.serializedData() == bytes)
        #expect(draft.extraFiles["native-marker-reference.json"] != nil)
        if let parent = ProcessInfo.processInfo.environment["LECTERN_MARKER_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: parent).appendingPathComponent("alternative-\(alternative)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: directory.appendingPathComponent("listMarkers.pptx"))
            for page in 0..<5 { try Data(draft.deck.renderSVG(slideAt: page).utf8).write(to: directory.appendingPathComponent("slide-\(page + 1).svg")) }
        }
    }

    @Test func nativeMarkerReferencesAndStrictSVGAuditRemainIndependent() throws {
        let reference = try PlatformLabRecipes.listMarkerReferences()
        #expect(Set(reference.cases.prefix(18).map(\.sourceSHA256)) == ["db317bc89840fc1dea1d4abf11fdd26e8c08c470dd86dee822ed8f01987a92d8"])
        #expect(Set(reference.cases.suffix(6).map(\.sourceSHA256)) == ["6baeaa1cb40ccd22f512aa6e9f14dcc9b21024139bde29cc14d96ed03095b1dd"])
        #expect(Set(reference.cases.prefix(18).map(\.nativePDFSHA256)) == ["4153ef4949c6aa554497ab16958f62016d8406d06d6cc88b1842e9d40920f1ea"])
        #expect(Set(reference.cases.suffix(6).map(\.nativePDFSHA256)) == ["745576408a02c63c21dca8c243847ef1cf89163758e948e3c3faec61ee59452c"])
        #expect(Set(reference.faces.map(\.sha256)) == ["7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954", "107244956e9962b9e96faccdc551825e0ae0898ae13737133e1b921a2fd35ffa", "b184b89e3c1075f22f6b71575b6fc20d4972b3cfd3b23322ca6fd596dcaef167"])
        let draft = try PlatformLabRecipes.make(.listMarkers, options: .init())
        let sample = try #require(reference.cases.first)
        let svg = try draft.deck.renderSVG(slideAt: 0)
        let aliases = PlatformLabRecipes.markerFaceAliases(svg: svg, fonts: draft.deck.fonts)
        #expect(PlatformLabRecipes.markerGlyphsMatch(svg: svg, sample: sample, aliases: aliases))
        #expect(!PlatformLabRecipes.markerGlyphsMatch(svg: svg.replacingOccurrences(of: "<tspan ", with: "<tspan textLength=\"1\" "), sample: sample, aliases: aliases))
        #expect(!PlatformLabRecipes.markerGlyphsMatch(svg: svg.replacingOccurrences(of: "•", with: ""), sample: sample, aliases: aliases))
        #expect(!PlatformLabRecipes.markerGlyphsMatch(svg: svg.replacingOccurrences(of: "font-size=\"16\"", with: "font-size=\"15\""), sample: sample, aliases: aliases))
    }
}
