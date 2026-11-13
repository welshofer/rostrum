import Foundation
import Testing
@testable import Rostrum

@Suite struct Round4LiftUpTests {
    private static let minimalPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!

    // MARK: - Track 1: Preset Geometry & Adjustment Engine

    @Test func presetGeometryCatalogAdjustmentsInsetTextFrameAndCurvedConnectors() throws {
        #expect(SVGPresetGeometry.supported.count >= 75)
        #expect(SVGPresetGeometry.supported.contains("star5"))
        for preset in [
            "star4", "star6", "star7", "star8", "star10", "star12", "star16", "star24", "star32",
            "rightArrow", "leftArrow", "upArrow", "downArrow", "leftRightArrow", "upDownArrow",
            "quadArrow", "leftUpArrow", "leftRightUpArrow", "bentArrow", "bentUpArrow",
            "notchedRightArrow", "stripedRightArrow", "uturnArrow",
            "chevron", "homePlate", "pentagon", "hexagon", "heptagon", "octagon", "decagon", "dodecagon",
            "donut", "noSmoking", "heart", "lightningBolt",
            "plus", "frame", "halfFrame", "corner", "diagStripe", "chord", "pie", "pieWedge", "blockArc",
            "flowChartProcess", "flowChartDecision", "flowChartInputOutput", "flowChartTerminator",
            "flowChartDocument", "flowChartPredefinedProcess", "flowChartConnector",
            "wedgeRectCallout", "wedgeRoundRectCallout", "wedgeEllipseCallout",
            "can", "cube", "bevel", "foldedCorner", "plaque", "teardrop", "snip1Rect", "snip2SameRect",
            "round1Rect", "round2SameRect", "mathPlus", "mathMinus", "mathMultiply",
            "mathDivide", "mathEqual", "mathNotEqual",
        ] {
            #expect(SVGPresetGeometry.supported.contains(preset), "Expected \(preset) in SVGPresetGeometry.supported")
        }

        let deck = try Presentation()
        let slide = try deck.slides[0]
        let arrow = try slide.shapes.addShape(
            .rightArrow,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(2)),
            fill: .solid(Color("2563EB"))
        )
        #expect(arrow.adjustments.isEmpty)
        arrow.setAdjustment("adj1", value: 25000)
        arrow.setAdjustment("adj2", value: 30000)
        #expect(arrow.adjustment("adj1") == 25000)
        #expect(arrow.adjustment("adj2") == 30000)
        #expect(arrow.adjustments["adj1"] == 25000)

        let defaultTextRect = SVGPresetGeometry.textFrame("donut", adjustments: nil, frame: (0, 0, 1000, 1000))
        let adjXML = try XML.parse(Data("<a:avLst><a:gd name=\"adj\" fmla=\"val 40000\"/></a:avLst>".utf8))
        let thickerDonutTextRect = SVGPresetGeometry.textFrame("donut", adjustments: adjXML, frame: (0, 0, 1000, 1000))
        #expect(thickerDonutTextRect.2 < defaultTextRect.2)

        for (idx, geom) in [ConnectorGeometry.curved2, .curved, .curved4, .curved5].enumerated() {
            _ = try slide.shapes.addConnector(
                geom,
                from: (x: .inches(1), y: .inches(Double(idx + 1))),
                to: (x: .inches(5), y: .inches(Double(idx + 2))),
                line: Line(color: Color("111827"), width: .points(2))
            )
        }

        let report = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(report.problems.isEmpty)
        #expect(report.svg.contains(" C"))
    }

    // MARK: - Track 2: SmartArt End-to-End Fidelity

    @Test func smartArtHierarchyTreePyramidConstraintsAndCachedDrawingRender() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]

        let root = SmartArt.Node("CEO", children: [
            SmartArt.Node("VP Engineering", children: [
                SmartArt.Node("Platform"),
                SmartArt.Node("Product"),
            ]),
            SmartArt.Node("VP Sales", children: [
                SmartArt.Node("Enterprise"),
            ]),
        ])
        _ = try slide.shapes.addSmartArt(
            nodes: [root],
            frame: Rect(x: .inches(0.5), y: .inches(0.5), width: .inches(5.5), height: .inches(4.0)),
            includeDrawing: true
        )
        #expect(slide.smartArtTexts.first == ["CEO", "VP Engineering", "Platform", "Product", "VP Sales", "Enterprise"])
        let trees = slide.smartArtTrees
        #expect(trees.count == 1)
        #expect(trees[0] == [root])

        _ = try slide.shapes.addSmartArt(
            items: ["Foundation", "Core", "Peak"],
            frame: Rect(x: .inches(6.5), y: .inches(0.5), width: .inches(5.5), height: .inches(4.0)),
            layout: .pyramid,
            includeDrawing: true
        )
        #expect(slide.smartArtTexts.count == 2)
        #expect(slide.smartArtTexts[1] == ["Foundation", "Core", "Peak"])

        let roundTripped = try Presentation(data: deck.serializedData())
        let rtTrees = try roundTripped.slides[0].smartArtTrees
        #expect(rtTrees.count == 2)
        #expect(rtTrees[0] == [root])

        let svg = try roundTripped.renderSVG(slideAt: 0)
        #expect(svg.contains("CEO"))
        #expect(svg.contains("VP Engineering"))
        #expect(svg.contains("Foundation"))
        #expect(svg.contains("<line ") || svg.contains("<path "))
    }

    // MARK: - Track 3: Pattern Fills, Group Fills, Path Gradients, & Blip Effects

    @Test func patternFillsGroupFillsFocalRadialGradientsAndBlipEffects() throws {
        #expect(PatternFillPreset.allCases.count == 54)

        let deck = try Presentation()
        let slide = try deck.slides[0]

        // 1. Pattern fill shape
        let pattShape = try slide.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(0.5), y: .inches(0.5), width: .inches(2), height: .inches(1.5)),
            fill: .pattern(PatternFill(preset: .diagBrick, foreground: Color("DC2626"), background: Color("FEF2F2")))
        )
        #expect(pattShape.fill == .pattern)
        let pf = try #require(pattShape.patternFill)
        #expect(pf.preset == .diagBrick)
        #expect(pf.foreground == Color("DC2626"))
        #expect(pf.background == Color("FEF2F2"))

        // 2. Group fill inheritance
        let group = try slide.shapes.addGroup(Rect(x: .inches(3.0), y: .inches(0.5), width: .inches(2), height: .inches(1.5)))
        try group.setFill(.solid(Color("16A34A")))
        let child = try group.contents.addShape(
            .rectangle,
            frame: Rect(x: .inches(3.2), y: .inches(0.7), width: .inches(1.6), height: .inches(1.1)),
            fill: .group
        )
        #expect(child.fill == .unmodeled(elementName: "a:grpFill"))

        // 3. Radial gradient with focal center
        let radial = GradientFill.radial(
            stops: [
                GradientStop(position: 0, color: Color("FFFFFF")),
                GradientStop(position: 1, color: Color("1D4ED8")),
            ],
            focalX: 0.25,
            focalY: 0.75
        )
        let gradShape = try slide.shapes.addShape(
            .ellipse,
            frame: Rect(x: .inches(5.5), y: .inches(0.5), width: .inches(2), height: .inches(1.5)),
            fill: .gradient(radial)
        )
        let readGrad = try #require(gradShape.gradientFill)
        #expect(readGrad.isRadial)
        #expect(abs((readGrad.focalCenterX ?? 0) - 0.25) < 0.001)
        #expect(abs((readGrad.focalCenterY ?? 0) - 0.75) < 0.001)

        // 4. Picture blip effects
        let pic = try slide.shapes.addPicture(
            Self.minimalPNG,
            frame: Rect(x: .inches(8.0), y: .inches(0.5), width: .inches(2), height: .inches(1.5))
        )
        pic.setOpacity(0.8)
        pic.setGrayscale(true)
        pic.setBrightnessContrast(brightness: 0.1, contrast: 0.2)
        pic.setBiLevel(threshold: 0.5)
        pic.setDuotone(shadow: Color("1E293B"), highlight: Color("F8FAFC"))
        #expect(abs((pic.opacity ?? 0) - 0.8) < 0.001)
        #expect(pic.isGrayscale)
        #expect(abs((pic.luminanceEffect?.brightness ?? 0) - 0.1) < 0.001)
        #expect(abs((pic.luminanceEffect?.contrast ?? 0) - 0.2) < 0.001)
        #expect(abs((pic.biLevelThreshold ?? 0) - 0.5) < 0.001)

        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(!report.problems.fidelityIssues.contains { $0.code == .unsupportedFill || $0.code == .omittedEffect })
        #expect(report.svg.contains("<pattern id=\"pat"))
        #expect(report.svg.contains("#16A34A"))
        #expect(report.svg.contains("fx=\"0.2500\""))
        #expect(report.svg.contains("<feColorMatrix"))
    }

    // MARK: - Track 4: Text-Body & Run Typography Parity

    @Test func verticalTextMultiColumnCapsDoubleStrikePictureBulletsAndShapeAutoFit() throws {
        let deck = try Presentation()
        let fontBytes = try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf"))
        try deck.fonts.register(fontBytes, aliases: ["Calibri", "Arial"])
        let slide = try deck.slides[0]

        // 1. Vertical text shape
        let vertBox = try slide.shapes.addTextBox(Rect(x: .inches(0.5), y: .inches(0.5), width: .inches(1.5), height: .inches(3.0)))
        let vertTF = try #require(vertBox.textFrame)
        vertTF.textDirection = .vertical
        vertTF.text = "Vertical Label"
        #expect(vertTF.textDirection == .vertical)

        // 2. Multi-column text + small-caps + all-caps + double strikethrough + picture bullet
        let colBox = try slide.shapes.addTextBox(Rect(x: .inches(2.5), y: .inches(0.5), width: .inches(5.0), height: .inches(3.0)))
        let colTF = try #require(colBox.textFrame)
        colTF.columnCount = 2
        colTF.columnSpacing = .points(18)
        #expect(colTF.columnCount == 2)
        #expect(colTF.columnSpacing == .points(18))

        let p1 = colTF.paragraphs[0]
        try p1.setPictureBullet(Self.minimalPNG)
        #expect(p1.hasPictureBullet)
        let r1 = p1.addRun("Small Caps Heading")
        r1.caps = .small
        r1.strikethroughStyle = .double
        #expect(r1.caps == .small)
        #expect(r1.strikethroughStyle == .double)

        let p2 = colTF.addParagraph()
        let r2 = p2.addRun("second column item")
        r2.caps = .all
        #expect(r2.caps == .all)

        // 3. spAutoFit + fitShapeToText
        let autoBox = try slide.shapes.addTextBox(Rect(x: .inches(8.0), y: .inches(0.5), width: .inches(2.0), height: .inches(0.2)))
        let autoTF = try #require(autoBox.textFrame)
        autoTF.text = "Line one\nLine two\nLine three\nLine four"
        autoTF.fitShapeToText(fonts: deck.fonts)
        #expect(autoTF.shapeAutoFit)
        #expect(autoBox.frame.height > .inches(0.2))

        let report = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(report.problems.isEmpty, "Problems: \(report.problems.messages)")
        #expect(report.svg.contains("font-variant=\"small-caps\""))
        #expect(report.svg.contains("SECOND COLUMN"))
        #expect(report.svg.contains(">ITEM<"))
    }

    // MARK: - Track 5: Modern ChartEx & Classic 3D / Trendline / Error-Bar / Date-Axis Charts

    @Test func extendedChartsAndClassic3DTrendlineErrorBarDateAxisChartsRender() throws {
        let deck = try Presentation()
        let fontBytes = try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf"))
        try deck.fonts.register(fontBytes, aliases: ["Calibri", "Arial"])
        let slide = try deck.slides[0]

        for (idx, kind) in [ExtendedChartKind.waterfall, .funnel, .treemap, .sunburst, .boxWhisker, .histogram].enumerated() {
            let col = Double(idx % 3) * 4.0 + 0.5
            let row = Double(idx / 3) * 3.2 + 0.4
            let gf = try slide.shapes.addExtendedChart(
                kind,
                data: ChartData(categories: ["Q1", "Q2", "Q3", "Q4"], name: "Net", values: [120, 45, -30, 135]),
                frame: Rect(x: .inches(col), y: .inches(row), width: .inches(3.6), height: .inches(2.8)),
                title: "\(kind.rawValue) Demo"
            )
            let chart = try #require(gf.extendedChart)
            #expect(chart.kind == kind)
            #expect(chart.series.first?.values == [120, 45, -30, 135])
        }
        #expect(slide.extendedCharts.count == 6)
        #expect(deck.extendedCharts.count == 6)

        let outline = deck.outline()
        #expect(outline.slides[0].charts.count == 6)
        #expect(outline.slides[0].charts[0].title == "waterfall Demo")
        #expect(outline.slides[0].charts[0].grid.contains(["Q1", "120"]))

        // Second slide with classic chart carrying trendline, error bars, and custom data label text
        let slide2 = try deck.slides.add()
        _ = try slide2.shapes.addChart(
            .barClustered,
            data: ChartData(
                categories: ["2023-01", "2023-02", "2023-03"],
                series: [ChartData.Series(name: "Revenue", values: [100, 150, 210])]
            ),
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(4.5)),
            options: ChartOptions(title: "Classic With Overlays", dataLabels: DataLabelOptions(showValue: true))
        )
        let chartPart = slide2.charts[0].part
        let chartRoot = try chartPart.dom()
        let plotArea = try #require(chartRoot.firstChild(named: "c:chart")?.firstChild(named: "c:plotArea"))
        // Switch to c:bar3DChart and c:dateAx and inject c:trendline, c:errBars, and custom c:dLbl
        if let barChart = plotArea.firstChild(named: "c:barChart") {
            barChart.name = "c:bar3DChart"
            if let ser = barChart.firstChild(named: "c:ser") {
                ser.appendElement(try XML.parse(Data("<c:trendline><c:trendlineType val=\"linear\"/></c:trendline>".utf8)))
                ser.appendElement(try XML.parse(Data("<c:errBars><c:errValType val=\"percentage\"/><c:val val=\"10\"/></c:errBars>".utf8)))
                ser.appendElement(try XML.parse(Data("<c:dLbls><c:dLbl><c:idx val=\"0\"/><c:tx><c:rich><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>CustomPeak</a:t></a:r></a:p></c:rich></c:tx></c:dLbl></c:dLbls>".utf8)))
            }
        }
        if let catAx = plotArea.firstChild(named: "c:catAx") {
            catAx.name = "c:dateAx"
        }
        chartPart.markDirty()

        let svg0 = try deck.renderSVG(slideAt: 0)
        #expect(svg0.contains("data-rostrum-chart=\"extended\""))
        #expect(svg0.contains("data-rostrum-chart-kind=\"waterfall\""))
        #expect(svg0.contains("data-rostrum-chart-kind=\"funnel\""))
        #expect(svg0.contains("data-rostrum-chart-kind=\"treemap\""))
        #expect(svg0.contains("data-rostrum-chart-kind=\"sunburst\""))

        let svg1 = try deck.renderSVG(slideAt: 1)
        #expect(svg1.contains("data-rostrum-chart-role=\"trendline\""))
        #expect(svg1.contains("data-rostrum-chart-role=\"error-bar\""))
        #expect(svg1.contains("CustomPeak"))
    }

    // MARK: - Track 6: Vector SVG Pictures, WebP/TIFF/BMP Sniffing, & Hyperlinks

    @Test func svgBlipPicturesWebPTIFFBMPSniffingAndHyperlinks() throws {
        // 1. BMP, TIFF, WebP sniffing
        var bmp = Data([0x42, 0x4D, 0, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0])
        bmp.append(contentsOf: [64, 0, 0, 0]) // width = 64
        bmp.append(contentsOf: [32, 0, 0, 0]) // height = 32
        bmp.append(contentsOf: [1, 0, 24, 0])
        let sniffedBMP = try #require(ImageSniffer.sniff(bmp))
        #expect(sniffedBMP.format == .bmp && sniffedBMP.pixelWidth == 64 && sniffedBMP.pixelHeight == 32)

        // Little-endian TIFF with 2 IFD entries: ImageWidth (256) = 80, ImageLength (257) = 40
        let tiff = Data([
            0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00,
            0x02, 0x00,
            0x00, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 80, 0, 0, 0,
            0x01, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 40, 0, 0, 0,
            0x00, 0x00, 0x00, 0x00,
        ])
        let sniffedTIFF = try #require(ImageSniffer.sniff(tiff))
        #expect(sniffedTIFF.format == .tiff && sniffedTIFF.pixelWidth == 80 && sniffedTIFF.pixelHeight == 40)

        // WebP VP8X: 120 x 90 (stored as width-1 = 119, height-1 = 89)
        let webp = Data([
            0x52, 0x49, 0x46, 0x46, 30, 0, 0, 0, 0x57, 0x45, 0x42, 0x50,
            0x56, 0x50, 0x38, 0x58, 10, 0, 0, 0, 0, 0, 0, 0,
            119, 0, 0, 89, 0, 0,
        ])
        let sniffedWebP = try #require(ImageSniffer.sniff(webp))
        #expect(sniffedWebP.format == .webp && sniffedWebP.pixelWidth == 120 && sniffedWebP.pixelHeight == 90)

        // 2. Vector SVG picture (`asvg:svgBlip`) + Hyperlinks
        let deck = try Presentation()
        let slide1 = try deck.slides[0]
        let slide2 = try deck.slides.add()

        let vectorSVG = Data("""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 60">
          <defs><linearGradient id="g1"><stop offset="0%" stop-color="#2563EB"/><stop offset="100%" stop-color="#1D4ED8"/></linearGradient></defs>
          <style>.box { fill: url(#g1); }</style>
          <rect class="box" width="120" height="60" rx="8"/>
        </svg>
        """.utf8)
        let svgPic = try slide1.shapes.addSVGPicture(
            vectorSVG,
            fallbackPNG: Self.minimalPNG,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(3), height: .inches(1.5))
        )
        #expect(svgPic.svgData == vectorSVG)
        svgPic.setHyperlink("https://example.com/vector")
        #expect(svgPic.hyperlink == "https://example.com/vector")

        let jumpShape = try slide1.shapes.addShape(
            .roundedRectangle,
            frame: Rect(x: .inches(5), y: .inches(1), width: .inches(2), height: .inches(1)),
            fill: .solid(Color("059669"))
        )
        jumpShape.setSlideLink(to: slide2)
        #expect(jumpShape.hyperlink == "slide2.xml")

        let actionBox = try slide1.shapes.addTextBox(Rect(x: .inches(1), y: .inches(3), width: .inches(4), height: .inches(1)))
        actionBox.setActionLink(.nextSlide)
        let fontBytes = try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf"))
        try deck.fonts.register(fontBytes, aliases: ["Calibri"])
        let run = actionBox.textFrame!.paragraphs[0].addRun("Next Slide")
        run.setActionLink(.nextSlide)
        #expect(run.hyperlink == SlideAction.nextSlide.rawValue)

        let report = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(report.problems.isEmpty)
        #expect(report.svg.contains("data:image/svg+xml;base64,"))
        #expect(report.svg.contains("<a href=\"https://example.com/vector\">"))
        #expect(report.svg.contains("<a href=\"#slide-2\">"))
        #expect(report.svg.contains("<a href=\"ppaction://hlinkshowjump?jump=nextslide\">"))
    }

    // MARK: - Track 7: GPOS Mark Positioning & rotWithShape="0" Image Fill Transforms

    @Test func rotWithShapeZeroCounterRotatesImageFillAndGPOSMarkOffsetsRender() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]

        let shape = try slide.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(3), height: .inches(2)),
            fill: .image(Self.minimalPNG)
        )
        shape.rotation = 45
        let blipFill = try #require(shape.element.firstChild(named: "p:spPr")?.firstChild(named: "a:blipFill"))
        blipFill[attribute: "rotWithShape"] = "0"

        let report = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(report.problems.isEmpty)
        #expect(report.svg.contains("patternTransform=\"rotate(-45"))
    }
}
