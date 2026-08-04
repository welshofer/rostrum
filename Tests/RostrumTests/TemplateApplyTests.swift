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

    /// The corporate `.potx` the cross-producer evidence came from.
    ///
    /// Not in the repository, and deliberately: it is someone's real corporate
    /// template and this repository is public. The tests that need it are
    /// gated on its presence rather than on a copy of it living here — the
    /// same bargain `RealDeckCorpusTests` strikes with `ROSTRUM_REAL_DECKS`.
    /// Everything about the *mechanism* is covered below by a synthetic
    /// template, which runs everywhere.
    static var corporateTemplate: URL? {
        Bundle.module.url(forResource: "Template.potx", withExtension: nil,
                          subdirectory: "Fixtures/RealDecks")
    }
    static var hasCorporateTemplate: Bool { corporateTemplate != nil }

    private func template() throws -> Presentation {
        try Presentation(contentsOf: try #require(Self.corporateTemplate))
    }

    /// A template that is definitely not the deck it will be applied to:
    /// same layout shapes, different brand. Enough to prove adoption,
    /// re-laying and reporting without needing a file we cannot ship.
    private func syntheticTemplate() throws -> Presentation {
        let template = try Presentation()
        template.theme.majorFont = "Papyrus"
        template.theme.minorFont = "Courier New"
        return template
    }

    // MARK: - Mechanism (no corpus needed)

    @Test func adoptingASyntheticTemplateTakesItsThemeAndRelaysSlides() throws {
        let deck = try Presentation()
        try deck.titleSlide("Before", subtitle: "unbranded")
        let before = deck.theme.majorFont

        let report = try deck.applyTemplate(from: try syntheticTemplate())

        #expect(report.mastersAdopted == 1)
        #expect(deck.theme.majorFont == "Papyrus", "the template's theme did not become primary")
        #expect(deck.theme.majorFont != before)
        // Same layout vocabulary on both sides, so every slide re-lays, and by
        // the signature rather than by a name that happens to coincide.
        #expect(report.kept.isEmpty)
        #expect(!report.relaid.isEmpty)
        #expect(report.relaid.allSatisfy { $0.by == .signature })
        #expect(report.changed)
    }

    /// A real designer template names its variants ("Section Header 1"), omits
    /// `@type`, and offers a title-only section layout where the source deck
    /// had title+body — so signature, type and name all miss. Without the
    /// nearest-match fallback the slide keeps its old layout and adopts none of
    /// the brand, which is what made a Fabrikam rebrand come back looking like
    /// the original deck in a slightly different blue.
    @Test func aSectionSlideFindsTheTemplatesSectionVariant() throws {
        let template = try syntheticTemplate()
        // Reshape the template's section layout the way a designer's does:
        // renamed with a numeric suffix, no body placeholder, no @type.
        let section = template.layouts.first { $0.type == "secHead" }!
        let dom = try section.part.dom()
        dom[attribute: "type"] = nil
        dom.firstChild(named: "p:cSld")![attribute: "name"] = "Section Header 1"
        let tree = try Slide.spTree(of: section.part)
        for sp in tree.children(named: "p:sp")
        where Placeholders.phElement(of: sp)?[attribute: "type"] == "body" {
            tree.removeChild(sp)
        }
        section.part.markDirty()

        let deck = try Presentation()
        try deck.sectionSlide("The Puzzle", subtitle: "visible danger", number: 1)
        let report = try deck.applyTemplate(from: template)

        let relaid = report.relaid.first { $0.from == "Section Header" }
        #expect(relaid?.to == "Section Header 1")
        #expect(relaid?.by == .nearest)
        #expect(report.kept.isEmpty, "a section slide adopted nothing")
    }

    @Test func applyingATemplateLeavesSlideCountAndTextAlone() throws {
        let deck = try Presentation()
        try deck.titleSlide("Keep me", subtitle: "and me")
        try deck.bulletSlide("Bullets", ["one", "two", "three"])
        let text = (0..<deck.slides.count).map { index in
            ((try? deck.slides.slide(at: index))?.shapes.all
                .compactMap { $0.textFrame?.text }.joined(separator: "|")) ?? ""
        }

        let count = deck.slides.count
        _ = try deck.applyTemplate(from: try syntheticTemplate())

        #expect(deck.slides.count == count)
        let after = (0..<deck.slides.count).map { index in
            ((try? deck.slides.slide(at: index))?.shapes.all
                .compactMap { $0.textFrame?.text }.joined(separator: "|")) ?? ""
        }
        #expect(after == text, "a rebrand rewrote slide text")
    }

    /// A rebranded deck must still open. This is the cheap continuous version
    /// of the PowerPoint gate.
    @Test func aRebrandedDeckRoundTripsAndKeepsEveryLayoutResolvable() throws {
        let deck = try Presentation()
        try deck.titleSlide("T", subtitle: "s")
        try deck.bulletSlide("B", ["a", "b"])
        let count = deck.slides.count
        _ = try deck.applyTemplate(from: try syntheticTemplate())

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slides.count == count)
        for index in 0..<reopened.slides.count {
            #expect(try reopened.slides.slide(at: index).layout != nil)
        }
        #expect(try reopened.validate().isEmpty)
    }

    // MARK: - Cross-producer evidence (needs the corporate template)

    @Test(.enabled(if: TemplateApplyTests.hasCorporateTemplate)) func adoptingATemplateMakesItsThemePrimary() throws {
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
    @Test(.enabled(if: TemplateApplyTests.hasCorporateTemplate)) func theDecksOwnMastersSurvive() throws {
        let deck = try Presentation(contentsOf: try fixture("SimplePowerPoint.pptx"))
        let before = deck.slideMasters.count
        let report = try deck.applyTemplate(from: try template())
        #expect(report.mastersKept == before)
        #expect(deck.slideMasters.count == before + report.mastersAdopted)
    }

    /// Slide content is not the template's business: a rebrand changes which
    /// layout a slide sits on, never what it says.
    @Test(.enabled(if: TemplateApplyTests.hasCorporateTemplate)) func slidesKeepTheirContentAndOrder() throws {
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
    @Test(.enabled(if: TemplateApplyTests.hasCorporateTemplate)) func everySlideStillResolvesALayoutAfterARebrand() throws {
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
    /// Measured on this corpus, name and type together match **nothing** — a
    /// designer template leaves `@type` off, Keynote and Google Slides use
    /// their own naming — while the placeholder vocabulary carries all of it,
    /// exactly (`.signature`) or by nearest role coverage (`.nearest`). If a
    /// match ever comes from the raw name or type the feature is dead and this
    /// is how we find out.
    @Test(.enabled(if: TemplateApplyTests.hasCorporateTemplate)) func layoutsMatchByPlaceholderSignatureNotByName() throws {
        let deck = try Presentation(contentsOf: try fixture("FromKeynote.pptx"))
        let report = try deck.applyTemplate(from: try template())

        #expect(!report.relaid.isEmpty, "nothing matched at all")
        #expect(!report.relaid.contains { $0.by == .name || $0.by == .type },
                "a match came from a name or @type these producers do not share")
        #expect(report.relaid.contains { $0.by == .signature },
                "the exact placeholder signature carried none of it")
        // Names really are unrelated — this is why signature matching is the
        // only thing that works.
        #expect(report.relaid.allSatisfy { $0.from != $0.to })
    }

    /// Every slide is accounted for exactly once, and a slide reported as kept
    /// really was left where it was.
    @Test(.enabled(if: TemplateApplyTests.hasCorporateTemplate)) func everySlideIsRelaidOrKeptExactlyOnce() throws {
        let deck = try Presentation(contentsOf: try fixture("FromKeynote.pptx"))
        let before = (0..<deck.slides.count).compactMap { try? deck.slides.slide(at: $0).layout?.name }
        let report = try deck.applyTemplate(from: try template())

        for kept in report.kept {
            let now = try deck.slides.slide(at: kept.slide).layout?.name
            #expect(now == before[kept.slide], "a 'kept' slide was moved anyway")
            #expect(now == kept.layout)
        }
        let touched = Set(report.relaid.map(\.slide)).union(report.kept.map(\.slide))
        #expect(touched.count == deck.slides.count)
    }

    /// A slide whose layout asks for something the template has no answer to is
    /// left alone rather than dropped onto whatever is generic — nearest-match
    /// needs at least one shared placeholder role before it will move anything.
    @Test func aSlideTheTemplateCannotServeIsKeptNotForced() throws {
        let deck = try Presentation()
        // Reshape the deck's blank layout into something the template has no
        // answer to: a picture wall, with no @type and a name of its own, so
        // signature, type and name all miss and only nearest-match is left.
        let blank = deck.layouts.first { $0.type == "blank" }!
        let dom = try blank.part.dom()
        dom[attribute: "type"] = nil
        dom.firstChild(named: "p:cSld")![attribute: "name"] = "Photo Wall"
        let sp = XML.Element("p:sp")
        let nvSpPr = XML.Element("p:nvSpPr")
        nvSpPr.appendElement(XML.Element("p:cNvPr", attributes: [("id", "9"), ("name", "Pic 9")]))
        nvSpPr.appendElement(XML.Element("p:cNvSpPr"))
        let nvPr = XML.Element("p:nvPr")
        nvPr.appendElement(XML.Element("p:ph", attributes: [("type", "pic"), ("idx", "1")]))
        nvSpPr.appendElement(nvPr)
        sp.appendElement(nvSpPr)
        sp.appendElement(XML.Element("p:spPr"))
        try Slide.spTree(of: blank.part).appendElement(sp)
        blank.part.markDirty()

        // A fresh deck's first slide sits on that layout.
        let before = try deck.slides.slide(at: 0).layout?.name
        #expect(before == "Photo Wall")
        let report = try deck.applyTemplate(from: try syntheticTemplate())

        #expect(report.kept.contains { $0.slide == 0 },
                "a slide asking for a picture wall was forced onto a text layout")
        #expect(try deck.slides.slide(at: 0).layout?.name == before, "a kept slide was moved")
    }

    /// A deck assembled from freeform text boxes — no placeholders anywhere,
    /// every slide on the Blank layout — carries its structure only in its
    /// geometry and type sizes. Matching on the layout alone puts all of it on
    /// the template's Blank: the theme is adopted and none of the design is,
    /// which is exactly what a real 29-slide deck did against a 45-layout
    /// corporate template.
    @Test func aDeckOfFreeformTextBoxesIsRelaidFromItsContent() throws {
        let deck = try Presentation()
        let slide = try deck.slides.add()
        #expect(slide.placeholders.isEmpty, "this test needs a slide with no placeholders")
        try slide.addText("A Headline", in: Rect(x: .inches(1), y: .inches(0.5),
                                                 width: .inches(8), height: .inches(1.2)),
                          role: .title, style: deck.style.with(.title) { $0.sizePt = 44 })
        try slide.addText(String(repeating: "prose that is clearly a body. ", count: 3),
                          in: Rect(x: .inches(1), y: .inches(2),
                                   width: .inches(8), height: .inches(3)),
                          role: .body, style: deck.style)

        let report = try deck.applyTemplate(from: try syntheticTemplate())

        let relaid = try #require(report.relaid.first { $0.slide == deck.slides.count - 1 })
        #expect(relaid.by == .content)
        #expect(relaid.from == "Blank")
        #expect(relaid.to != "Blank", "a freeform slide was left on Blank")
    }

    /// `ctrTitle` is the schema's word for the deck's cover. Flattening it into
    /// "a title" makes a cover layout and a content layout indistinguishable —
    /// and then either the cover lands on "Agenda" or all 29 content slides
    /// land on "Title 1". Both happened before this was put back.
    @Test func onlyTheFirstSlideIsTreatedAsTheCover() throws {
        let deck = try Presentation()
        for index in 0..<2 {
            let slide = index == 0 ? try deck.slides.slide(at: 0) : try deck.slides.add()
            try slide.addText("Headline \(index)", in: Rect(x: .inches(1), y: .inches(0.5),
                                                            width: .inches(8), height: .inches(1.2)),
                              role: .title, style: deck.style.with(.title) { $0.sizePt = 44 })
            try slide.addText(String(repeating: "supporting words here. ", count: 3),
                              in: Rect(x: .inches(1), y: .inches(2),
                                       width: .inches(8), height: .inches(3)),
                              role: .body, style: deck.style)
        }

        let report = try deck.applyTemplate(from: try syntheticTemplate())

        let cover = try #require(report.relaid.first { $0.slide == 0 })
        let second = try #require(report.relaid.first { $0.slide == 1 })
        #expect(cover.to == "Title Slide", "the cover did not find the ctrTitle layout")
        #expect(second.to != "Title Slide", "a content slide landed on the cover layout")
    }

    /// The difference between a rebrand you can see and one you cannot. Every
    /// builder paints its slide a flat colour, which sits on top of whatever
    /// the adopted layout puts behind it — so a template whose section layout
    /// is a solid orange field showed none of it until the slide gave its own
    /// fill up.
    @Test func aSlideGivesUpItsFlatBackgroundSoTheTemplatesShows() throws {
        let template = try syntheticTemplate()
        let titleLayout = template.layouts.first { $0.type == "title" }!
        let cSld = try #require(try titleLayout.part.dom().firstChild(named: "p:cSld"))
        let bg = XML.Element("p:bg")
        let bgPr = XML.Element("p:bgPr")
        let fill = XML.Element("a:solidFill")
        fill.appendElement(XML.Element("a:srgbClr", attributes: [("val", "FF6700")]))
        bgPr.appendElement(fill)
        bgPr.appendElement(XML.Element("a:effectLst"))
        bg.appendElement(bgPr)
        cSld.insertChild(bg, beforeAnyOf: ["p:spTree"])
        titleLayout.part.markDirty()

        let deck = try Presentation()
        let slide = try deck.titleSlide("Headline", subtitle: "sub")
        #expect(try slide.part.dom().firstChild(named: "p:cSld")?
            .firstChild(named: "p:bg") != nil, "the builder stopped painting a background")

        let report = try deck.applyTemplate(from: template)

        #expect(report.backgroundsAdopted >= 1)
        #expect(try slide.part.dom().firstChild(named: "p:cSld")?
            .firstChild(named: "p:bg") == nil,
                "the slide kept painting over the template's background")
    }

    /// Only when there is something to show underneath: a layout with no
    /// background of its own would drop the slide through to a master
    /// background never designed for it.
    @Test func aSlideKeepsItsBackgroundWhenTheLayoutOffersNone() throws {
        let deck = try Presentation()
        let slide = try deck.titleSlide("Headline", subtitle: "sub")
        let report = try deck.applyTemplate(from: try syntheticTemplate())

        #expect(report.backgroundsAdopted == 0)
        #expect(try slide.part.dom().firstChild(named: "p:cSld")?
            .firstChild(named: "p:bg") != nil, "a slide lost its background for nothing")
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
    @Test(.enabled(if: TemplateApplyTests.hasCorporateTemplate)) func theRealDeckCorpusLintsClean() throws {
        for name in ["Template.potx", "FromGoogleSlides.pptx", "SimplePowerPoint.pptx"] {
            let deck = try Presentation(contentsOf: try fixture(name))
            let issues = try deck.validate()
            #expect(issues.isEmpty, "\(name): \(issues.count) issues, e.g. \(issues.first?.description ?? "")")
        }
    }
}
