import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct TemplateRichTextTests {
    private func fixture(width: Double = 300, height: Double = 80, properties: String = "", run: String = "", body: String = "vertOverflow=\"clip\"", autofit: String = "<a:noAutofit/>") throws -> (Presentation, SlideLayout, Shape) {
        let deck = try Presentation()
        try registerFonts(in: deck)
        deck.theme.majorFont = "DejaVu Sans"; deck.theme.minorFont = "DejaVu Sans"
        let layout = try #require(deck.layout(type: "obj"))
        let shape = try #require(ShapeCollection(part: layout.part, package: deck.package).all.first { $0.placeholder?.idx == 1 })
        shape.frame = Rect(x: .points(40), y: .points(160), width: .points(width), height: .points(height))
        let tx = try XML.parse(Data("""
        <p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0" \(body)>\(autofit)</a:bodyPr>
        <a:lstStyle><a:lvl1pPr marL="0" indent="0"><a:buNone/>\(properties)<a:defRPr sz="2400" \(run)><a:latin typeface="DejaVu Sans"/></a:defRPr></a:lvl1pPr></a:lstStyle><a:p/></p:txBody>
        """.utf8))
        shape.element.removeChildren(named: "p:txBody"); shape.element.appendElement(tx); layout.part.markDirty()
        return (deck, layout, shape)
    }

    private func registerFonts(in deck: Presentation) throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
        for name in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique"] {
            try deck.fonts.register(contentsOf: root.appendingPathComponent(name + ".ttf"))
        }
    }

    private func geometry(_ shape: Shape, slide: Slide, deck: Presentation) throws -> RichTextLayout {
        let frame = try #require(slide.effectiveFrame(of: shape))
        return RichTextLayout(textBody: try #require(shape.element.firstChild(named: "p:txBody")),
            width: frame.width.points, height: frame.height.points, fonts: deck.fonts,
            theme: slide.master?.theme, inheritedStyles: RichTextLayout.inheritedStyles(for: shape.element, owner: slide.part, package: deck.package), maxLines: 64)
    }

    @Test func suppressedOuterParagraphSpacingDoesNotRejectAFittingBody() throws {
        let (deck, layout, shape) = try fixture(height: 35, properties: "<a:spcBef><a:spcPts val=\"9000\"/></a:spcBef><a:spcAft><a:spcPts val=\"9000\"/></a:spcAft>")
        let before = try deck.serializedData()
        #expect(TemplateLayoutEngine(presentation: deck).fits([LayoutParagraph("Short")], in: shape.frame, layout: layout, slot: 1))
        #expect(try deck.serializedData() == before)
    }

    @Test func inheritedRightMarginParticipatesInFit() throws {
        let (deck, layout, shape) = try fixture(width: 100)
        let p = try #require(shape.element.firstChild(named: "p:txBody")?.firstChild(named: "a:lstStyle")?.firstChild(named: "a:lvl1pPr"))
        p[attribute: "marR"] = String(EMU.points(120).rawValue); layout.part.markDirty()
        #expect(!TemplateLayoutEngine(presentation: deck).fits([LayoutParagraph("Wide")], in: shape.frame, layout: layout, slot: 1))
    }

    @Test func noWrapUsesActualFaceAndTrackingEvenWithAHostAdapter() throws {
        let (deck, layout, shape) = try fixture(width: 75, height: 200, run: "b=\"1\" spc=\"1000\"", body: "wrap=\"none\" vertOverflow=\"clip\"")
        #expect(!TemplateLayoutEngine(presentation: deck, measure: { _ in 1 }).fits([LayoutParagraph("AAAA")], in: shape.frame, layout: layout, slot: 1))
    }

    @Test func noWrapHonorsInheritedTabStops() throws {
        let (deck, layout, shape) = try fixture(width: 100, properties: "<a:tabLst><a:tab pos=\"1905000\" algn=\"l\"/></a:tabLst>", body: "wrap=\"none\" vertOverflow=\"clip\"")
        #expect(!TemplateLayoutEngine(presentation: deck).fits([LayoutParagraph("A\tB")], in: shape.frame, layout: layout, slot: 1))
    }

    @Test(arguments: ["vert=\"vert\"", "numCol=\"2\""])
    func unsupportedTextGeometryCannotBeApproved(attribute: String) throws {
        let (deck, layout, shape) = try fixture(body: attribute)
        #expect(!TemplateLayoutEngine(presentation: deck).fits([LayoutParagraph("Short")], in: shape.frame, layout: layout, slot: 1))
    }

    @Test(arguments: [-1.0, Double.nan, Double.infinity])
    func invalidHostHeightsCannotApproveFit(height: Double) throws {
        let (deck, layout, shape) = try fixture()
        #expect(!TemplateLayoutEngine(presentation: deck, measure: { _ in height }).fits([LayoutParagraph("Short")], in: shape.frame, layout: layout, slot: 1))
    }

    @Test func autofitRetainsInheritedReductionAndUnknownData() throws {
        let (deck, layout, _) = try fixture(width: 250, height: 68, autofit: "<a:normAutofit lnSpcReduction=\"10000\" private=\"kept\"/>")
        let before = try layout.part.dom().serialized()
        let engine = TemplateLayoutEngine(presentation: deck)
        let columns = [[LayoutParagraph("Alpha beta\nGamma delta\nEpsilon zeta")]]
        let plan = try engine.plan(title: "Title", columns: columns, preferredTypes: ["obj"], layoutURI: layout.part.uri.value)
        #expect(try #require(plan.textFits[1]).fontScale < 1)
        let slide = try engine.compose(plan, title: "Title", columns: columns)
        let fitted = try #require(slide.placeholder(idx: 1))
        let fit = fitted.element.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit")
        #expect(fit?[attribute: "lnSpcReduction"] == "10000")
        #expect(fit?[attribute: "private"] == "kept")
        #expect(try geometry(fitted, slide: slide, deck: deck).fits)
        #expect(try layout.part.dom().serialized() == before)
    }

    @Test func explicitCaptionWeightMatchesTheMeasuredRoleAfterReopening() throws {
        let (deck, layout, _) = try fixture(run: "b=\"1\"")
        let engine = TemplateLayoutEngine(presentation: deck)
        let columns = [[LayoutParagraph("Caption", role: .caption)]]
        let plan = try engine.plan(title: "Title", columns: columns, preferredTypes: ["obj"], layoutURI: layout.part.uri.value)
        let slide = try engine.compose(plan, title: "Title", columns: columns)
        let shape = try #require(slide.placeholder(idx: 1))
        let actual = try geometry(shape, slide: slide, deck: deck)
        #expect(actual.lines.flatMap(\.spans).allSatisfy { !$0.run.bold })
        let reopened = try Presentation(data: deck.serializedData())
        let saved = try reopened.slides[reopened.slides.count - 1]
        #expect(try geometry(#require(saved.placeholder(idx: 1)), slide: saved, deck: reopened).lines.flatMap(\.spans).allSatisfy { !$0.run.bold })
    }

    @Test func changedContentCannotUseAStaleFitOrLeaveAPartialSlide() throws {
        let (deck, layout, _) = try fixture()
        let engine = TemplateLayoutEngine(presentation: deck)
        let plan = try engine.plan(title: "Title", columns: [[LayoutParagraph("Short")]], preferredTypes: ["obj"], layoutURI: layout.part.uri.value)
        let before = try deck.serializedData()
        #expect(throws: LayoutError.self) {
            _ = try engine.compose(plan, title: "Title", columns: [[LayoutParagraph(String(repeating: "More words ", count: 300))]])
        }
        #expect(try deck.serializedData() == before)
    }

    @Test func exactSpacingAndInheritedFacesSurvivePlanningAndReopening() throws {
        let (deck, layout, shape) = try fixture(height: 150, properties: "<a:lnSpc><a:spcPts val=\"4200\"/></a:lnSpc>", run: "i=\"1\"")
        let words = "Alpha beta\nGamma delta"
        let control = try deck.slides.add(clonedFrom: layout)
        try control.fillPlaceholder(index: 1, paragraphs: [(words, 0)])
        let reference = try geometry(#require(control.placeholder(idx: 1)), slide: control, deck: deck)
        try deck.slides.remove(at: deck.slides.count - 1)
        var frame = shape.frame; frame.height = .points(ceil(reference.contentHeight)); shape.frame = frame
        let before = try layout.part.dom().serialized()
        let engine = TemplateLayoutEngine(presentation: deck)
        let columns = [[LayoutParagraph(words)]]
        let plan = try engine.plan(title: "Title", columns: columns, preferredTypes: ["obj"], layoutURI: layout.part.uri.value)
        #expect(plan.textFits[1]?.frame == frame)
        #expect(plan.textFits[1]?.fontScale == 1)
        let slide = try engine.compose(plan, title: "Title", columns: columns)
        let actual = try geometry(#require(slide.placeholder(idx: 1)), slide: slide, deck: deck)
        #expect(actual.fits && actual.lines.flatMap(\.spans).allSatisfy { $0.run.italic })
        let reopened = try Presentation(data: deck.serializedData())
        try registerFonts(in: reopened)
        let saved = try reopened.slides[reopened.slides.count - 1]
        #expect(try geometry(#require(saved.placeholder(idx: 1)), slide: saved, deck: reopened).lines == actual.lines)
        #expect(saved.placeholder(idx: 1)?.textFrame?.text == words)
        #expect(try layout.part.dom().serialized() == before)
    }

    @Test func alreadyFittingStoredAutofitRemainsInherited() throws {
        let (deck, layout, _) = try fixture(height: 23, autofit: "<a:normAutofit fontScale=\"65000\"/>")
        let engine = TemplateLayoutEngine(presentation: deck)
        let columns = [[LayoutParagraph("Short")]]
        let plan = try engine.plan(title: "Title", columns: columns, preferredTypes: ["obj"], layoutURI: layout.part.uri.value)
        #expect(plan.textFits[1]?.fontScale == 0.65)
        let slide = try engine.compose(plan, title: "Title", columns: columns)
        let shape = try #require(slide.placeholder(idx: 1))
        #expect(shape.element.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit") == nil)
        #expect(try geometry(shape, slide: slide, deck: deck).fits)
    }

    @Test func editedInheritanceIsRecheckedBeforeAddingASlide() throws {
        let (deck, layout, shape) = try fixture()
        let engine = TemplateLayoutEngine(presentation: deck)
        let columns = [[LayoutParagraph("Short")]]
        let plan = try engine.plan(title: "Title", columns: columns, preferredTypes: ["obj"], layoutURI: layout.part.uri.value)
        let properties = try #require(shape.element.firstChild(named: "p:txBody")?.firstChild(named: "a:lstStyle")?.firstChild(named: "a:lvl1pPr")?.firstChild(named: "a:defRPr"))
        properties[attribute: "sz"] = "7200"; layout.part.markDirty()
        let before = try deck.serializedData()
        #expect(throws: LayoutError.self) { _ = try engine.compose(plan, title: "Title", columns: columns) }
        #expect(try deck.serializedData() == before)
    }

    @Test(arguments: [0, 2]) func columnCountMismatchCannotDropContent(count: Int) throws {
        let (deck, layout, _) = try fixture()
        let engine = TemplateLayoutEngine(presentation: deck)
        let plan = try engine.plan(title: "Title", columns: [[LayoutParagraph("Short")]], preferredTypes: ["obj"], layoutURI: layout.part.uri.value)
        let before = try deck.serializedData()
        #expect(throws: LayoutError.self) {
            _ = try engine.compose(plan, title: "Title", columns: Array(repeating: [LayoutParagraph("Content")], count: count))
        }
        #expect(try deck.serializedData() == before)
    }

    @Test func layoutsImportedAfterPlanningAreVisibleToTheSameEngine() throws {
        let (deck, _, _) = try fixture()
        let engine = TemplateLayoutEngine(presentation: deck)
        _ = try engine.plan(title: "First", columns: [[LayoutParagraph("Short")]], preferredTypes: ["obj"])
        let source = try Presentation()
        _ = try source.bulletSlide("Seed", ["Body"])
        try deck.slides.importAll(from: source)
        let master = try #require(deck.slideMasters.last)
        let plan = try engine.plan(title: "Second", columns: [[LayoutParagraph("Short")]], preferredTypes: ["obj"], masterURI: master.part.uri.value)
        #expect(plan.layout.master?.part.uri == master.part.uri)
    }

    @Test func styledBlockHeightAgreesWithWrittenGeometry() throws {
        let (deck, _, _) = try fixture()
        let engine = TemplateLayoutEngine(presentation: deck)
        let style = TextStyle(font: "DejaVu Sans", sizePt: 21.234, weight: 700, trackingPt: 1.255, lineHeight: 1.35, color: .black)
        let words = "Styled words\nSecond line"
        let height = engine.measuredHeight(words, style: style, width: 180)
        #expect(height.isFinite)
        let slide = try deck.slides[0]
        let shape = try slide.shapes.addTextBox(Rect(x: .points(20), y: .points(20), width: .points(180), height: .points(height)))
        let frame = try #require(shape.textFrame)
        frame.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        frame.text = words
        _ = frame.paragraphs.first?.apply(style)
        let actual = RichTextLayout(textBody: try #require(shape.element.firstChild(named: "p:txBody")), width: 180, height: height, fonts: deck.fonts, theme: deck.theme)
        #expect(actual.fits && height == ceil(actual.contentHeight))
        var invalid = style; invalid.sizePt = .nan
        #expect(engine.measuredHeight(words, style: invalid, width: 180) == .infinity)
    }

}
