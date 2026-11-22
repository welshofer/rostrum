import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct MeasuredInsetConsistencyTests {
    private static func makeDeck() throws -> Presentation {
        let deck = try Presentation()
        let fontsDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
        for face in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique"] {
            try deck.fonts.register(contentsOf: fontsDir.appendingPathComponent(face + ".ttf"))
        }
        deck.theme.majorFont = "DejaVu Sans"
        deck.theme.minorFont = "DejaVu Sans"
        return deck
    }

    /// Deterministically pick a single-line string that fits at `width` (zero insets)
    /// and wraps to >= 2 lines at `width - 14.4` (default 7.2pt left/right margins).
    private static func borderlineSingleLine(
        engine: TemplateLayoutEngine,
        style: TextStyle,
        width: Double
    ) throws -> String {
        let oneLine = engine.measuredHeight("A i", style: style, width: width)
        var chosen: String?
        for count in 0...300 {
            let candidate = "A" + String(repeating: "i", count: count) + " i"
            let atFull = engine.measuredHeight(candidate, style: style, width: width)
            let atInset = engine.measuredHeight(candidate, style: style, width: width - 14.4)
            if atFull == oneLine, atInset.isFinite, atInset > oneLine {
                chosen = candidate
                break
            }
        }
        return try #require(chosen)
    }

    private static func assertAllTextShapesFit(on slide: Slide, in deck: Presentation) throws {
        for shape in slide.shapes.all {
            guard shape.textFrame?.text.isEmpty == false,
                  let txBody = shape.element.firstChild(named: "p:txBody"),
                  let frame = slide.effectiveFrame(of: shape) else { continue }
            let layout = RichTextLayout(
                textBody: txBody,
                width: frame.width.points,
                height: frame.height.points,
                fonts: deck.fonts,
                theme: deck.theme
            )
            #expect(layout.fits, "Expected shape '\(shape.textFrame?.text ?? "")' to fit its frame")
            #expect(!layout.truncated)
            for line in layout.lines {
                #expect(line.visibleWidth <= frame.width.points + 0.05)
            }
        }
    }

    @Test func panelAndStructuredCompositionsZeroMarginsPreserveStatRoleAndFitBorderlineText() throws {
        let deck = try Self.makeDeck()
        let engine = TemplateLayoutEngine(presentation: deck)
        var style = deck.style
        style.type = style.type
            .overriding(.heading) { $0.font = "DejaVu Sans" }
            .overriding(.body) { $0.font = "DejaVu Sans" }
            .overriding(.stat) { $0.font = "DejaVu Sans"; $0.color = Color("CC2200"); $0.trackingPt = -2.0 }
        let region = Rect(x: .points(40), y: .points(100), width: .points(640), height: .points(360))

        // 1. PanelLayout .cards with borderline heading & detail that wrap if 14.4pt horizontal margins remain.
        let cardFrames = try PanelLayout.frames(kind: .cards, count: 2, in: region, scale: engine.objectScale)
        let cardTextWidth = cardFrames[0].width.points - 24.0 * engine.objectScale
        var cardHeadingStyle = style.type(.heading)
        cardHeadingStyle.sizePt = 22 * engine.objectScale
        cardHeadingStyle.lineHeight = 1.1
        var cardBodyStyle = style.type(.body)
        cardBodyStyle.sizePt = 18 * engine.objectScale
        cardBodyStyle.lineHeight = 1.1

        let borderlineCardHead = try Self.borderlineSingleLine(engine: engine, style: cardHeadingStyle, width: cardTextWidth)
        let borderlineCardBody = try Self.borderlineSingleLine(engine: engine, style: cardBodyStyle, width: cardTextWidth)

        let panelSlide = try deck.slides.add()
        _ = try PanelLayout.compose(
            kind: .cards,
            items: [
                StructuredItem(borderlineCardHead, detail: borderlineCardBody),
                StructuredItem("Second Card", detail: "Supporting detail"),
            ],
            in: region,
            on: panelSlide,
            style: style,
            engine: engine
        )
        try Self.assertAllTextShapesFit(on: panelSlide, in: deck)

        // 2. StructuredLayout .metrics preserves .stat role (color + tracking) and fits borderline headings.
        let metricsCells = try StructuredLayout.frames(kind: .metrics, count: 2, in: region, scale: engine.objectScale)
        let metricsWidth = metricsCells[0].width.points - 24.0 * engine.objectScale
        var statStyle = style.type(.stat)
        statStyle.sizePt = 40 * engine.objectScale
        statStyle.lineHeight = 1.05
        let borderlineMetricHead = try Self.borderlineSingleLine(engine: engine, style: statStyle, width: metricsWidth)

        let metricsSlide = try deck.slides.add()
        _ = try StructuredLayout.compose(
            kind: .metrics,
            items: [
                StructuredItem(borderlineMetricHead, detail: "Year-over-year growth"),
                StructuredItem("99.95%", detail: "Availability SLA"),
            ],
            in: region,
            on: metricsSlide,
            style: style,
            engine: engine
        )
        try Self.assertAllTextShapesFit(on: metricsSlide, in: deck)

        let metricHeadShape = try #require(metricsSlide.shapes.all.first { $0.textFrame?.text == borderlineMetricHead })
        let metricRun = try #require(metricHeadShape.textFrame?.paragraphs.first?.runs.first)
        #expect(metricRun.color == Color("CC2200"))
        #expect(metricRun.letterSpacing == -2.0)

        // 3. StructuredLayout .process with borderline heading fits cleanly without margin wrap.
        let processCells = try StructuredLayout.frames(kind: .process, count: 2, in: region, scale: engine.objectScale)
        let processWidth = processCells[0].width.points - 24.0 * engine.objectScale
        var processHeadStyle = style.type(.heading)
        processHeadStyle.sizePt = 24 * engine.objectScale
        processHeadStyle.lineHeight = 1.05
        let borderlineProcessHead = try Self.borderlineSingleLine(engine: engine, style: processHeadStyle, width: processWidth)

        let processSlide = try deck.slides.add()
        _ = try StructuredLayout.compose(
            kind: .process,
            items: [
                StructuredItem(borderlineProcessHead, detail: "Validate"),
                StructuredItem("Deliver", detail: "Merge"),
            ],
            in: region,
            on: processSlide,
            style: style,
            engine: engine
        )
        try Self.assertAllTextShapesFit(on: processSlide, in: deck)

        // 4. StructuredLayout .cycle (including connector arrows and Repeat cycle label) fits cleanly.
        let cycleSlide = try deck.slides.add()
        _ = try StructuredLayout.compose(
            kind: .cycle,
            items: [
                StructuredItem("Plan", detail: "Scope"),
                StructuredItem("Build", detail: "Execute"),
                StructuredItem("Verify", detail: "Test"),
                StructuredItem("Ship", detail: "Release"),
            ],
            in: region,
            on: cycleSlide,
            style: style,
            engine: engine
        )
        try Self.assertAllTextShapesFit(on: cycleSlide, in: deck)
    }

    @Test func measuredHeightForwardsItalicAndPaginatedTableCaptionZeroesMargins() throws {
        let deck = try Self.makeDeck()
        var capturedRequests: [TextMeasureRequest] = []
        let engine = TemplateLayoutEngine(presentation: deck, measure: { req in
            capturedRequests.append(req)
            return req.size * 1.2
        })
        var style = deck.style.type(.body)
        style.font = "DejaVu Sans"
        style.sizePt = 18

        let regularH = engine.measuredHeight("Sample text", style: style, width: 240, italic: false)
        let italicH = engine.measuredHeight("Sample text", style: style, width: 240, italic: true)
        #expect(regularH.isFinite && italicH.isFinite)
        #expect(capturedRequests.count == 2)
        #expect(capturedRequests[0].italic == false)
        #expect(capturedRequests[1].italic == true)

        // Paginated table caption sized by zero-inset measuredHeight zeroes text-frame margins on composed pages.
        let tableEngine = TemplateLayoutEngine(presentation: deck)
        let objLayout = try #require(deck.layout(type: "obj"))
        let objSlot = try #require(objLayout.placeholders.first { $0.type == "obj" })
        let objFrame = try #require(objSlot.frame)
        let objStyle = tableEngine.objectStyle(layout: objLayout, slot: objSlot.index)
        let borderlineCaption = try Self.borderlineSingleLine(
            engine: tableEngine,
            style: objStyle.type(.caption),
            width: objFrame.width.points
        )

        let table = TemplateTableContent(
            rows: [["Col A", "Col B"], ["1", "Alpha"], ["2", "Beta"]],
            columnWeights: [1, 2]
        )
        let plan = try tableEngine.planTablePages(
            title: "Borderline Caption",
            table: table,
            caption: borderlineCaption,
            layoutURI: objLayout.part.uri.value
        )
        let pages = try tableEngine.composeTablePages(plan)
        #expect(pages.count == 1)
        let captionShape = try #require(pages[0].shapes.all.first { $0.textFrame?.text == borderlineCaption })
        let bodyPr = try #require(captionShape.element.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr"))
        #expect(bodyPr[attribute: "lIns"] == "0")
        #expect(bodyPr[attribute: "rIns"] == "0")
        #expect(bodyPr[attribute: "tIns"] == "0")
        #expect(bodyPr[attribute: "bIns"] == "0")
        let fitCheck = RichTextLayout(
            textBody: try #require(captionShape.element.firstChild(named: "p:txBody")),
            width: captionShape.frame.width.points,
            height: captionShape.frame.height.points,
            fonts: deck.fonts,
            theme: deck.theme
        )
        #expect(fitCheck.fits)
        #expect(fitCheck.lines.count == 1)
    }
}
