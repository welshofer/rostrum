import Foundation
import Testing
@testable import Rostrum

/// Applying a template — the rebrand path — against the real-deck corpus,
/// which is the only place the cross-producer cases exist.
@Suite struct TemplateApplyTests {
    private func fixture(_ name: String) throws -> URL {
        let url = try #require(Bundle.module.url(
            forResource: name, withExtension: nil, subdirectory: "Fixtures/RealDecks"))
        return url
    }

    private func template() throws -> Presentation {
        try Presentation(contentsOf: try fixture("Template.potx"))
    }

    @Test func adoptingATemplateMakesItsThemePrimary() throws {
        let deck = try Presentation(contentsOf: try fixture("SimplePowerPoint.pptx"))
        let before = deck.theme.majorFont
        let report = try deck.applyTemplate(from: try template())

        #expect(report.mastersAdopted == 1)
        #expect(deck.theme.majorFont != before, "the deck kept its own theme")
        #expect(deck.theme.majorFont == (try template()).theme.majorFont)
        // The adopted master has to be *first*: `theme` and `layouts` both
        // resolve through the first slideMaster relationship, so a master
        // merely appended changes nothing the caller can see.
        #expect(deck.slideMasters.first?.theme?.majorFont == deck.theme.majorFont)
    }

    /// The deck's own masters stay. Any slide that found no counterpart still
    /// needs its layout, and part removal would leave a stale content-type
    /// Override behind.
    @Test func theDecksOwnMastersSurvive() throws {
        let deck = try Presentation(contentsOf: try fixture("SimplePowerPoint.pptx"))
        let before = deck.slideMasters.count
        let report = try deck.applyTemplate(from: try template())
        #expect(report.mastersKept == before)
        #expect(deck.slideMasters.count == before + report.mastersAdopted)
    }

    /// Slide content is not the template's business: a rebrand changes which
    /// layout a slide sits on, never what it says.
    @Test func slidesKeepTheirContentAndOrder() throws {
        let deck = try Presentation(contentsOf: try fixture("FromKeynote.pptx"))
        let before = (0..<deck.slides.count).map { index in
            (try? deck.slides.slide(at: index))?.shapes.all.count ?? -1
        }
        _ = try deck.applyTemplate(from: try template())
        let after = (0..<deck.slides.count).map { index in
            (try? deck.slides.slide(at: index))?.shapes.all.count ?? -1
        }
        #expect(before == after, "shape counts moved, so content was rewritten")
    }

    /// Every slide must still resolve a layout afterwards. One that cannot is
    /// a deck PowerPoint offers to repair, which is the outcome this project
    /// refuses to ship.
    @Test func everySlideStillResolvesALayoutAfterARebrand() throws {
        for name in ["SimplePowerPoint.pptx", "FromKeynote.pptx", "FromGoogleSlides.pptx"] {
            let deck = try Presentation(contentsOf: try fixture(name))
            _ = try deck.applyTemplate(from: try template())
            let reopened = try Presentation(data: try deck.serializedData())
            for index in 0..<reopened.slides.count {
                let slide = try reopened.slides.slide(at: index)
                #expect(slide.layout != nil, "\(name) slide \(index) lost its layout")
            }
        }
    }

    /// The property the whole feature rests on: layouts match across producers
    /// by what placeholders they offer, not by name or `@type`.
    ///
    /// Measured on this corpus, name+type together match **nothing** — a
    /// designer template leaves `@type` off, Keynote and Google Slides use
    /// their own naming — while the placeholder signature matches most of it.
    /// If this ever regresses to a name/type match the feature is dead and
    /// this is how we find out.
    @Test func layoutsMatchByPlaceholderSignatureNotByName() throws {
        let deck = try Presentation(contentsOf: try fixture("FromKeynote.pptx"))
        let report = try deck.applyTemplate(from: try template())

        #expect(!report.relaid.isEmpty, "nothing matched at all")
        #expect(report.relaid.allSatisfy { $0.by == .signature },
                "a match came from somewhere other than the placeholder signature")
        // Names really are unrelated — this is why signature matching is the
        // only thing that works.
        #expect(report.relaid.allSatisfy { $0.from != $0.to })
    }

    /// A slide whose layout has no counterpart is left alone rather than
    /// dropped onto something generic, and is named in the report.
    @Test func unmatchedSlidesAreKeptAndReported() throws {
        let deck = try Presentation(contentsOf: try fixture("FromKeynote.pptx"))
        let before = (0..<deck.slides.count).compactMap { try? deck.slides.slide(at: $0).layout?.name }
        let report = try deck.applyTemplate(from: try template())

        #expect(!report.kept.isEmpty, "this corpus has layouts the template cannot serve")
        for kept in report.kept {
            let now = try deck.slides.slide(at: kept.slide).layout?.name
            #expect(now == before[kept.slide], "a 'kept' slide was moved anyway")
            #expect(now == kept.layout)
        }
        // Every slide is accounted for exactly once.
        let touched = Set(report.relaid.map(\.slide)).union(report.kept.map(\.slide))
        #expect(touched.count == deck.slides.count)
    }

    @Test func aTemplateWithNoMasterIsRefused() throws {
        let deck = try Presentation()
        let empty = try Presentation()
        // Strip the master list so the template has nothing to give.
        let dom = try empty.presentationPart.dom()
        if let list = dom.firstChild(named: "p:sldMasterIdLst") {
            list.replaceChildElements(with: [])
        }
        empty.presentationPart.markDirty()
        #expect(throws: RostrumError.self) { try deck.applyTemplate(from: empty) }
    }


    // MARK: - The lint bug this feature uncovered

    /// DrawingML uses `a:ext` for two unrelated types: the extent inside
    /// `a:xfrm` (CT_PositiveSize2D, `cx`/`cy` required) and the extension
    /// inside `a:extLst` (CT_OfficeArtExtension, keyed by `uri`, which has no
    /// `cx`/`cy` and never did).
    ///
    /// Treating them alike cost **1,582 false positives on one real corporate
    /// `.potx`** — 791 extensions times the two attributes, which was every
    /// issue the lint reported for that file, and none of them real. Found by
    /// rebranding a deck and asking why the result looked so much worse than
    /// what went in. A lint that cries wolf on valid PowerPoint output hides
    /// the defect it exists to catch.
    @Test func anExtensionIsNotAnExtent() throws {
        // A genuine malformed extent is still reported.
        let deck = try Presentation()
        let slide = try deck.slides.add()
        let xfrm = XML.Element("a:xfrm")
        xfrm.appendElement(XML.Element("a:ext"))
        try Slide.spTree(of: slide.part).appendElement(xfrm)
        slide.part.markDirty()
        #expect(try deck.validate().contains { $0.element == "a:ext" },
                "a genuinely malformed extent must still be reported")

        // An extension is not, because it is a different element.
        let other = try Presentation()
        let slide2 = try other.slides.add()
        let extLst = XML.Element("a:extLst")
        let ext = XML.Element("a:ext", attributes: [("uri", "{FF2B5EF4-FFF2-40B4-BE49-F238E27FC236}")])
        ext.appendElement(XML.Element("a16:creationId", attributes: [("id", "{00000000-0000-0000-0000-000000000000}")]))
        extLst.appendElement(ext)
        try Slide.spTree(of: slide2.part).appendElement(extLst)
        slide2.part.markDirty()
        #expect(try other.validate().isEmpty,
                "an a:extLst extension was mistaken for a missing extent")
    }

    /// The corpus is the evidence: these are real files from PowerPoint,
    /// Keynote and Google Slides, and none of them should trip the lint.
    @Test func theRealDeckCorpusLintsClean() throws {
        for name in ["Template.potx", "FromGoogleSlides.pptx", "SimplePowerPoint.pptx"] {
            let deck = try Presentation(contentsOf: try fixture(name))
            let issues = try deck.validate()
            #expect(issues.isEmpty, "\(name): \(issues.count) issues, e.g. \(issues.first?.description ?? "")")
        }
    }
}
