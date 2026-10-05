import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct MixedFaceSpacingRecipeTests {
    @Test(arguments: [false, true])
    func nativeFacesAndPublicFitsSurviveSaving(alternative: Bool) throws {
        let draft = try PlatformLabRecipes.make(.mixedFaceSpacing, options: .init(alternative: alternative))
        let reference = try PlatformLabRecipes.mixedSpacingReferences()
        #expect(draft.deck.slides.count == 3)
        #expect(draft.deck.slideSize.width == .points(720) && draft.deck.slideSize.height == .points(720))
        #expect(reference.cases.count == 12 && Set(reference.cases.map(\.id)).count == 12)
        #expect(reference.cases.reduce(0) { $0 + $1.expectedVisibleScalars } == 96)
        let pages = try (0..<2).map { try MixedFaceSpacingSVGPage(svg: draft.deck.renderSVG(slideAt: $0), fonts: draft.deck.fonts) }
        for sample in reference.cases { #expect(pages[sample.slide].matches(sample), "\(sample.id)") }
        // Compare against each separate native input before slide import, not
        // only against the already-composed recipe's own snapshot.
        for source in reference.sources {
            let original = try Presentation(data: PlatformLabRecipes.resource(String(source.source.dropLast(5)), "pptx"))
            for sample in reference.cases where sample.sourceGroup == source.group {
                let tree = try #require(original.slides[0].part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
                let originalNode = try #require(tree.children(named: "p:sp").first {
                    $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == sample.id
                })
                #expect(try PlatformLabRecipes.mixedSpacingSpecimen(draft.deck, sample: sample).serialized() == originalNode.serialized())
            }
        }
        let sans = try #require(draft.deck.fonts.data(for: .init(family: "DejaVu Sans")))
        let serif = try #require(draft.deck.fonts.data(for: .init(family: "DejaVu Serif")))
        #expect(sans != serif)
        #expect(PlatformLabRecipes.mixedSpacingSignature(sans) == PlatformLabRecipes.mixedSpacingSignature(serif))
        #expect(PlatformLabRecipes.mixedSpacingSignature(sans) == [0.7973993288590604, 1.1640625])
        #expect(PlatformLabRecipes.mixedSpacingSignature(Data()) == nil)
        let originalBody = try PlatformLabRecipes.paragraphBody(draft.deck, named: "exact18-sans12-serif24", slideAt: 0)
        var layouts: [RichTextLayout] = []
        for role in ["Shape.fitText", "TextFrame.fitText"] {
            let body = try PlatformLabRecipes.paragraphBody(draft.deck, named: role + " mixed spacing copy", slideAt: 2)
            #expect(body.children(named: "a:p").map { $0.serialized() } == originalBody.children(named: "a:p").map { $0.serialized() })
            let properties = try #require(body.firstChild(named: "a:bodyPr"))
            #expect(properties[attribute: "anchor"] == (alternative ? "b" : "t"))
            let fit = try #require(properties.firstChild(named: "a:normAutofit"))
            // The public fitter writes 100%/0% using the schema defaults:
            // a present normAutofit with both default attributes omitted.
            #expect(fit.attributes.isEmpty && fit.children.isEmpty)
            let layout = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: role + " mixed spacing copy", slideAt: 2)
            #expect(layout.fits && layout.diagnostics.isEmpty)
            #expect(abs(layout.contentHeight - 37.33489932885906) < 1e-9)
            let offset = alternative ? 40 - layout.contentHeight : 0
            #expect(zip(layout.lines.map(\.baseline), [14 + offset, 32 + offset]).allSatisfy { abs($0 - $1) < 1e-9 })
            #expect(layout.lines.flatMap(\.spans).map(\.run.fontSize) == [12, 24, 12, 24])
            layouts.append(layout)
        }
        #expect(layouts[0].lines == layouts[1].lines)
        let bytes = try draft.deck.serializedData()
        let reopened = try Presentation(data: bytes)
        for check in draft.checks + (try draft.verify(reopened)) { #expect(check.passed, "\(check.name): \(check.detail)") }
        #expect(try reopened.serializedData() == bytes)
        #expect(draft.extraFiles["native-mixed-spacing-reference.json"] != nil)
        if let parent = ProcessInfo.processInfo.environment["LECTERN_MIXED_SPACING_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: parent).appendingPathComponent("alternative-\(alternative)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: directory.appendingPathComponent("mixedFaceSpacing.pptx"))
            for page in 0..<3 { try Data(draft.deck.renderSVG(slideAt: page).utf8).write(to: directory.appendingPathComponent("slide-\(page + 1).svg")) }
        }
    }

    @Test func perGlyphFacesAndNativeResourcePinsAreStrict() throws {
        let reference = try PlatformLabRecipes.mixedSpacingReferences()
        #expect(reference.sources.map(\.sourceSHA256) == ["4e12a5e02468873d34fadb0ea415836ee50fa92245d9e096721faee33013c014", "ade8628fe0ca6c69691ad0790e9678bf92aaa7d2cd3178b5723dcb5c2adc9ea0"])
        #expect(reference.sources.map(\.nativePDFSHA256) == ["9d8c125d036eb15b0b0c3f2cf84e6a2b47f0f79812ca003a056814d74ca7268b", "49ec14886c2dbee1701b25039f362c221569957742a20d82ea0b18dd84af1c64"])
        let draft = try PlatformLabRecipes.make(.mixedFaceSpacing, options: .init())
        let sample = try #require(reference.cases.first { $0.id == "exact18-sans12-serif24" })
        #expect(sample.lines.flatMap(\.glyphs).map(\.sourceFace) == ["regular", "regular", "serif", "serif", "regular", "regular", "serif", "serif"])
        let svg = try draft.deck.renderSVG(slideAt: 0)
        let page = try MixedFaceSpacingSVGPage(svg: svg, fonts: draft.deck.fonts)
        let serifAlias = try #require(page.aliases.first { $0.value == "serif" }?.key)
        let sansAlias = try #require(page.aliases.first { $0.value == "regular" }?.key)
        #expect(page.matches(sample))
        #expect(try !MixedFaceSpacingSVGPage(svg: svg.replacingOccurrences(of: "font-family=\"" + serifAlias + ",", with: "font-family=\"" + sansAlias + ","), fonts: draft.deck.fonts).matches(sample))
        #expect(try !MixedFaceSpacingSVGPage(svg: svg.replacingOccurrences(of: "<tspan ", with: "<tspan textLength=\"1\" "), fonts: draft.deck.fonts).matches(sample))
        #expect(try !MixedFaceSpacingSVGPage(svg: svg.replacingOccurrences(of: "font-size=\"24\"", with: "font-size=\"23\""), fonts: draft.deck.fonts).matches(sample))
    }
}
