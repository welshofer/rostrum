import Foundation
import Testing
@testable import Rostrum
import RostrumLayout

@Suite struct AuthoredLayoutEngineTests {
    private func specimen(_ content: String, width: Double = 300, height: Double,
                          body: String = "", registered: Bool = true) throws -> (Presentation, Slide, Shape) {
        let deck = try Presentation()
        if registered {
            let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent("RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
            for name in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique", "DejaVuSerif"] {
                try deck.fonts.register(contentsOf: fixtures.appendingPathComponent(name + ".ttf"))
            }
        }
        deck.theme.minorFont = "DejaVu Sans"
        let slide = try deck.slides[0]
        let shape = try slide.shapes.addTextBox(Rect(x: .points(20), y: .points(20), width: .points(width), height: .points(height)))
        let text = try XML.parse(Data("""
        <p:txBody><a:bodyPr lIns="0" tIns="0" rIns="0" bIns="0" \(body)/><a:lstStyle/>\(content)</p:txBody>
        """.utf8))
        shape.element.removeChildren(named: "p:txBody")
        shape.element.appendElement(text)
        slide.part.markDirty()
        return (deck, slide, shape)
    }

    private func run(_ value: String, size: Int, extra: String = "") -> String {
        "<a:r><a:rPr sz=\"\(size * 100)\" \(extra)><a:latin typeface=\"DejaVu Sans\"/></a:rPr><a:t>\(value)</a:t></a:r>"
    }

    private func layout(_ shape: Shape, deck: Presentation) throws -> RichTextLayout {
        RichTextLayout(textBody: try #require(shape.element.firstChild(named: "p:txBody")),
            width: shape.frame.width.points, height: shape.frame.height.points,
            fonts: deck.fonts, theme: deck.theme, maxLines: 64)
    }

    @Test func laterLargerRunCannotHideOverflowAtReadableFloor() throws {
        let (deck, slide, shape) = try specimen("<a:p>" + run("Small ", size: 17) + run("LARGE", size: 48) + "</a:p>", height: 30)
        #expect(try !layout(shape, deck: deck).fits)
        let before = try deck.serializedData()
        #expect(throws: LayoutError.self) { try AuthoredLayoutEngine(presentation: deck).fitText(in: slide) }
        #expect(try deck.serializedData() == before)
    }

    @Test func mixedSizesShrinkUntilSavedRichTextActuallyFits() throws {
        let content = "<a:p>" + run("Small ", size: 24) + run("LARGE", size: 48, extra: "b=\"1\" i=\"1\"") + "</a:p>"
        let (deck, slide, shape) = try specimen(content, height: 45)
        #expect(try !layout(shape, deck: deck).fits)
        try AuthoredLayoutEngine(presentation: deck).fitText(in: slide)
        #expect(try layout(shape, deck: deck).fits)
        #expect(shape.textFrame?.text == "Small LARGE")
        let saved = try deck.serializedData()
        let reopened = try Presentation(data: saved)
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/Typography/DejaVuSans.ttf")
        try reopened.fonts.register(contentsOf: font)
        #expect(try layout(reopened.slides[0].shapes.all[0], deck: reopened).fits)
        try AuthoredLayoutEngine(presentation: deck).fitText(in: slide)
        #expect(try deck.serializedData() == saved, "A second fit must be a no-op")
    }

    @Test func explicitBreaksAndFieldsParticipateInFit() throws {
        for content in [
            "<a:p>" + run("A", size: 17) + "<a:br/>" + run("B", size: 17) + "</a:p>",
            "<a:p><a:fld id=\"{00000000-0000-0000-0000-000000000001}\" type=\"datetime\"><a:rPr sz=\"4800\"/><a:t>Field</a:t></a:fld></a:p>"
        ] {
            let (deck, slide, shape) = try specimen(content, height: 20)
            #expect(try !layout(shape, deck: deck).fits)
            let before = try deck.serializedData()
            #expect(throws: LayoutError.self) { try AuthoredLayoutEngine(presentation: deck).fitText(in: slide) }
            #expect(try deck.serializedData() == before)
        }
    }

    @Test func noWrapOverflowIsNotMistakenForOneFittingLine() throws {
        let (deck, slide, shape) = try specimen("<a:p>" + run("A long line that must not wrap", size: 17) + "</a:p>", width: 40, height: 300, body: "wrap=\"none\"")
        #expect(try !layout(shape, deck: deck).fits)
        #expect(throws: LayoutError.self) { try AuthoredLayoutEngine(presentation: deck).fitText(in: slide) }
    }

    @Test func exactSpacingIsMeasuredWithoutReplacingItWithPercentageSpacing() throws {
        let content = "<a:p><a:pPr><a:lnSpc><a:spcPts val=\"1800\"/></a:lnSpc></a:pPr>" + run("A", size: 17) + "<a:br/>" + run("B", size: 17) + "</a:p>"
        let (deck, slide, shape) = try specimen(content, height: 60)
        #expect(try layout(shape, deck: deck).fits)
        let before = try deck.serializedData()
        try AuthoredLayoutEngine(presentation: deck).fitText(in: slide)
        #expect(try deck.serializedData() == before)
    }

    @Test func hostHeightCannotApproveAnOverflowingMixedParagraph() throws {
        let (deck, slide, _) = try specimen("<a:p>" + run("Small ", size: 17) + run("LARGE", size: 48) + "</a:p>", height: 30)
        #expect(throws: LayoutError.self) {
            try AuthoredLayoutEngine(presentation: deck, measure: { _ in 1 }).fitText(in: slide)
        }
    }

    @Test func selectedShapesLeaveOtherTextUntouched() throws {
        let (deck, slide, shape) = try specimen("<a:p>" + run("Small ", size: 17) + run("LARGE", size: 48) + "</a:p>", height: 30)
        let before = try deck.serializedData()
        try AuthoredLayoutEngine(presentation: deck).fitText(in: slide, only: [(shape.shapeID ?? 0) + 1])
        #expect(try deck.serializedData() == before)
    }

    @Test func inheritedSizeIsUsedWithoutEditingTheLayout() throws {
        let (deck, _, _) = try specimen("<a:p/>", height: 28)
        let source = try #require(deck.layout(type: "obj"))
        let slide = try deck.slides.add(clonedFrom: source)
        let shape = try #require(slide.placeholder(idx: 1))
        shape.frame = Rect(x: .points(20), y: .points(20), width: .points(300), height: .points(28))
        let frame = try #require(shape.textFrame)
        frame.text = "Inherited"
        frame.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        let placeholder = try #require(ShapeCollection(part: source.part, package: deck.package).all.first { $0.placeholder?.idx == 1 })
        let sourceText = try #require(placeholder.element.firstChild(named: "p:txBody"))
        sourceText.getOrAddChild("a:lstStyle", beforeAnyOf: ["a:p"]).getOrAddChild("a:lvl1pPr")
            .getOrAddChild("a:defRPr")[attribute: "sz"] = "4800"
        source.part.markDirty()
        let inherited = RichTextLayout.inheritedStyles(for: shape.element, owner: slide.part, package: deck.package)
        let beforeLayout = RichTextLayout(textBody: try #require(shape.element.firstChild(named: "p:txBody")),
            width: 300, height: 28, fonts: deck.fonts, theme: deck.theme, inheritedStyles: inherited)
        #expect(!beforeLayout.fits)
        let layoutBytes = source.part.blob
        try AuthoredLayoutEngine(presentation: deck).fitText(in: slide, only: [try #require(shape.shapeID)])
        let actual = RichTextLayout(textBody: try #require(shape.element.firstChild(named: "p:txBody")),
            width: 300, height: 28, fonts: deck.fonts, theme: deck.theme, inheritedStyles: inherited)
        #expect(actual.fits)
        #expect(actual.lines.flatMap(\.spans).allSatisfy { $0.run.fontSize >= 17 })
        #expect(shape.textFrame?.paragraphs.first?.runs.first?.fontSize == nil)
        #expect(source.part.blob == layoutBytes)
    }

    @Test func fittingPreservesRunFacadesAndUnknownMarkup() throws {
        let (deck, slide, shape) = try specimen("<a:p>" + run("Small ", size: 24) + run("LARGE", size: 48) + "<a:extLst><private:kept xmlns:private=\"urn:rostrum:test:private\" value=\"original\"/></a:extLst></a:p>", height: 45)
        let frame = try #require(shape.textFrame)
        let retained = try #require(frame.paragraphs.first?.runs.last)
        try AuthoredLayoutEngine(presentation: deck).fitText(in: slide)
        #expect(frame.paragraphs.first?.runs.map(\.fontSize) == [24, 48])
        retained.text = "EDITED"
        #expect(shape.textFrame?.text == "Small EDITED")
        #expect(try String(decoding: XML.document(slide.part.dom()), as: UTF8.self).contains("private:kept"))
    }

    @Test func fieldsKeepIdentityAndTextWhenTheyCanShrink() throws {
        let (deck, slide, shape) = try specimen("<a:p><a:fld id=\"field-id\" type=\"datetime\"><a:rPr sz=\"4800\"/><a:t>Field</a:t></a:fld></a:p>", height: 35)
        try AuthoredLayoutEngine(presentation: deck).fitText(in: slide)
        #expect(try layout(shape, deck: deck).fits)
        let field = try #require(shape.element.firstChild(named: "p:txBody")?.firstChild(named: "a:p")?.firstChild(named: "a:fld"))
        #expect(field[attribute: "id"] == "field-id")
        #expect(field[attribute: "type"] == "datetime")
        #expect(field.firstChild(named: "a:t")?.textContent == "Field")
        #expect(field.firstChild(named: "a:rPr")?[attribute: "sz"] == "4800")
    }

    @Test func invalidHostMeasurementsFailWithoutMutatingTheBody() throws {
        for height in [Double.nan, .infinity, -1] {
            let (deck, slide, _) = try specimen("<a:p>" + run("A", size: 17) + "</a:p>", height: 50)
            let before = try deck.serializedData()
            #expect(throws: LayoutError.self) {
                try AuthoredLayoutEngine(presentation: deck, measure: { _ in height }).fitText(in: slide)
            }
            #expect(try deck.serializedData() == before)
        }
    }

    @Test func unverifiedVerticalAndColumnGeometryCannotReportSuccess() throws {
        for body in ["vert=\"vert\"", "numCol=\"2\""] {
            let (deck, slide, shape) = try specimen("<a:p>" + run("A", size: 17) + "</a:p>", height: 100, body: body)
            let before = try deck.serializedData()
            let report = try AuthoredLayoutEngine(presentation: deck).fitText(in: slide)
            #expect(report.fitted.isEmpty)
            #expect(report.skipped.map(\.shapeID) == [try #require(shape.shapeID)])
            #expect(try deck.serializedData() == before)
        }
    }

    @Test(arguments: ["vert=\"vert270\"", "numCol=\"2\""])
    func unsupportedSidebarDoesNotBlockFittingTheRestOfTheSlide(body: String) throws {
        // An overflowing ordinary body plus a decorative vertical/multi-column one.
        let content = "<a:p>" + run("Small ", size: 24) + run("LARGE", size: 48) + "</a:p>"
        let (deck, slide, ordinary) = try specimen(content, height: 45)
        let sidebar = try slide.shapes.addTextBox(Rect(x: .points(400), y: .points(20), width: .points(40), height: .points(300)))
        sidebar.element.removeChildren(named: "p:txBody")
        sidebar.element.appendElement(try XML.parse(Data("""
        <p:txBody><a:bodyPr lIns="0" tIns="0" rIns="0" bIns="0" \(body)/><a:lstStyle/><a:p>\(run("SIDEBAR LABEL THAT OVERFLOWS", size: 48))</a:p></p:txBody>
        """.utf8)))
        slide.part.markDirty()
        #expect(try !layout(ordinary, deck: deck).fits)
        let sidebarBefore = XML.document(sidebar.element)

        let report = try AuthoredLayoutEngine(presentation: deck).fitText(in: slide)

        let scale = ordinary.element.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr")?
            .firstChild(named: "a:normAutofit")?[attribute: "fontScale"]
        #expect(scale != nil)
        #expect(try layout(ordinary, deck: deck).fits)
        #expect(XML.document(sidebar.element) == sidebarBefore)
        #expect(report.fitted == [try #require(ordinary.shapeID)])
        #expect(report.skipped == [AuthoredFitReport.Skipped(shapeID: try #require(sidebar.shapeID),
            reason: "uses vertical or multi-column text that authored fitting does not support.")])
    }

    @Test func repeatedBodiesKeepIndependentSourceNodes() throws {
        let (deck, slide, shape) = try specimen("<a:p>" + run("Small ", size: 24) + run("LARGE", size: 48) + "</a:p>", height: 45)
        let copy = try slide.shapes.addTextBox(shape.frame)
        copy.element.removeChildren(named: "p:txBody")
        copy.element.appendElement(try #require(shape.element.firstChild(named: "p:txBody")).deepCopy())
        slide.part.markDirty()
        try AuthoredLayoutEngine(presentation: deck).fitText(in: slide)
        #expect(try layout(shape, deck: deck).fits)
        #expect(try layout(copy, deck: deck).lines == layout(shape, deck: deck).lines)
        shape.textFrame?.paragraphs.first?.runs.last?.text = "EDITED"
        #expect(copy.textFrame?.text == "Small LARGE")
    }

    @Test func laterEditsCannotReuseAnEarlierFitDecision() throws {
        let (deck, slide, shape) = try specimen("<a:p>" + run("A", size: 17) + "</a:p>", height: 30)
        let engine = AuthoredLayoutEngine(presentation: deck)
        try engine.fitText(in: slide)
        shape.textFrame?.paragraphs.first?.addRun("LARGE").fontSize = 48
        let edited = try deck.serializedData()
        #expect(throws: LayoutError.self) { try engine.fitText(in: slide) }
        #expect(try deck.serializedData() == edited)
    }

    @Test func slideNumberFieldsFitTheirDeclaredPositionInsteadOfCachedText() throws {
        let (deck, _, shape) = try specimen("<a:p><a:fld id=\"slide-number\" type=\"slidenum\"><a:rPr sz=\"1700\"/><a:t>1</a:t></a:fld></a:p>", width: 15, height: 100, body: "wrap=\"none\"")
        for _ in 0..<9 { _ = try deck.slides.add() }
        try deck.slides.move(from: 0, to: 9)
        let slide = try deck.slides[9]
        let body = try #require(shape.element.firstChild(named: "p:txBody"))
        #expect(RichTextLayout(textBody: body, width: 15, height: 100, fonts: deck.fonts, theme: deck.theme, slideNumber: 1).fits)
        #expect(!RichTextLayout(textBody: body, width: 15, height: 100, fonts: deck.fonts, theme: deck.theme, slideNumber: 10).fits)
        let before = try deck.serializedData()
        #expect(throws: LayoutError.self) { try AuthoredLayoutEngine(presentation: deck).fitText(in: slide) }
        #expect(try deck.serializedData() == before)
    }

    @Test func irrelevantAutofitAttributesCannotLowerTheReadableFloor() throws {
        let (deck, slide, shape) = try specimen("<a:p>" + run("A", size: 24) + "</a:p>", height: 20)
        let body = try #require(shape.element.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr"))
        body.appendElement(XML.Element("a:noAutofit", attributes: [("fontScale", "80000")]))
        slide.part.markDirty()
        #expect(try !layout(shape, deck: deck).fits)
        let before = try deck.serializedData()
        #expect(throws: LayoutError.self) { try AuthoredLayoutEngine(presentation: deck).fitText(in: slide) }
        #expect(try deck.serializedData() == before)
    }

    @Test(arguments: [0.0, 20.0]) func hostMeasurementUsesAvailableWidthRatherThanTightGlyphAdvance(inset: Double) throws {
        let (deck, slide, shape) = try specimen("<a:p>" + run("Short", size: 17) + "</a:p>", width: 300, height: 40)
        shape.textFrame?.setMargins(left: .points(inset), top: .zero, right: .points(inset), bottom: .zero)
        let before = try deck.serializedData()
        var requests: [TextMeasureRequest] = []
        try AuthoredLayoutEngine(presentation: deck, measure: { request in
            requests.append(request)
            // A host can legitimately wrap in the glyph advance computed by a
            // different shaping policy, even though the actual box is roomy.
            return request.width < 100 ? 100 : 20
        }).fitText(in: slide)
        #expect(!requests.isEmpty)
        #expect(requests.allSatisfy { $0.width == 300 - 2 * inset })
        #expect(try deck.serializedData() == before)
    }

    /// The host callback runs once per positioned span of each accepted shared
    /// layout, so a one-span body turns callback count into layout count.
    @Test(arguments: [17.5, 18.5, 21.0, 31.0]) func autofitBisectsToTheLinearStepWithBoundedLayouts(threshold: Double) throws {
        let (deck, slide, shape) = try specimen("<a:p>" + run("A", size: 48) + "</a:p>", height: 200)
        var sizes: [Double] = []
        try AuthoredLayoutEngine(presentation: deck, measure: { request in
            sizes.append(request.size)
            return request.size > threshold ? 10_000 : 0
        }).fitText(in: slide)
        // Independent reference: the old 2500-unit descent from 100% to the
        // 17pt body floor keeps the first (largest) scale whose size fits.
        let minimumScale = Int(ceil(100_000.0 * 17 / 48))
        let ladder = Array(stride(from: 100_000, to: minimumScale, by: -2500)) + [minimumScale]
        let expected = try #require(ladder.first { 48 * Double($0) / 100_000 <= threshold })
        let saved = shape.element.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr")?
            .firstChild(named: "a:normAutofit")?[attribute: "fontScale"]
        #expect(saved == String(expected))
        #expect(ladder.firstIndex(of: expected)! > 5, "The fixture must need a large reduction")
        // One callback rejects the original body; the rest are autofit probes.
        #expect(sizes.count - 1 <= 7, "Probes: \(sizes.count - 1) for a ladder of \(ladder.count)")
        #expect(sizes.allSatisfy { $0 <= 48 })
    }

    @Test func fittingBodyPerformsExactlyOneLayout() throws {
        let (deck, slide, _) = try specimen("<a:p>" + run("A", size: 48) + "</a:p>", height: 200)
        let before = try deck.serializedData()
        var calls = 0
        try AuthoredLayoutEngine(presentation: deck, measure: { _ in calls += 1; return 0 }).fitText(in: slide)
        #expect(calls == 1)
        #expect(try deck.serializedData() == before)
    }

    @Test func unreadableBodyFailsAfterProbingOnlyCurrentAndFloorScales() throws {
        let (deck, slide, _) = try specimen("<a:p>" + run("A", size: 48) + "</a:p>", height: 200)
        let before = try deck.serializedData()
        var sizes: [Double] = []
        #expect(throws: LayoutError.self) {
            try AuthoredLayoutEngine(presentation: deck, measure: { request in
                sizes.append(request.size)
                return request.size > 10 ? 10_000 : 0
            }).fitText(in: slide)
        }
        #expect(sizes.count == 3)
        #expect(abs((sizes.last ?? 0) - 17) < 0.01)
        #expect(try deck.serializedData() == before)
    }
}
