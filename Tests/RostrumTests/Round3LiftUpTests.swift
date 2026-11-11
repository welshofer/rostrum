import Foundation
import Testing
@testable import Rostrum

@Suite struct Round3LiftUpTests {
    private static let onePixelPNG = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )!

    private func realFontData() throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf"))
    }

    // MARK: - Track 1: Write-Side Connectors, Group Shapes, & Freeform Paths

    @Test func connectorAuthoringRoundTripsFlipsArrowheadsAndAttachments() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let boxA = try slide.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(5), y: .inches(3), width: .inches(1.5), height: .inches(1)),
            fill: .solid(Color("225588"))
        )
        let boxB = try slide.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(1.5), height: .inches(1)),
            fill: .solid(Color("884422"))
        )
        let idA = try #require(boxA.shapeID)
        let idB = try #require(boxB.shapeID)

        // End < Start in both X and Y exercises flipH="1" + flipV="1".
        let arrowLine = Line(
            color: Color("112233"),
            width: .points(2),
            dash: .systemDashDot,
            headEnd: Arrowhead(.oval, width: .small, length: .small),
            tailEnd: Arrowhead(.stealth, width: .large, length: .large)
        )
        let straight = try slide.shapes.addConnector(
            .straight,
            from: (x: .inches(5), y: .inches(3.5)),
            to: (x: .inches(2.5), y: .inches(1.5)),
            line: arrowLine,
            startConnection: (shapeID: idA, index: 1),
            endConnection: (shapeID: idB, index: 3)
        )
        let elbow = try slide.shapes.addConnector(
            .elbow,
            from: (x: .inches(2.5), y: .inches(2)),
            to: (x: .inches(5), y: .inches(4)),
            line: Line(color: Color("AA3300"), width: .points(1.5), tailEnd: .triangle)
        )

        #expect(straight.connectorGeometry == .straight)
        #expect(straight.startPoint.x == .inches(5) && straight.startPoint.y == .inches(3.5))
        #expect(straight.endPoint.x == .inches(2.5) && straight.endPoint.y == .inches(1.5))
        #expect(elbow.connectorGeometry == .elbow)
        #expect(try deck.validate().isEmpty)

        let strict = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(strict.problems.isEmpty)
        #expect(strict.svg.contains("marker-start=\"url(#arrow"))
        #expect(strict.svg.contains("marker-end=\"url(#arrow"))
        #expect(strict.svg.contains("L3 5 Z")) // stealth marker

        let saved = try deck.serializedData()
        #expect(try deck.serializedData() == saved)
        let reopened = try Presentation(data: saved)
        let connectors = try reopened.slides[0].shapes.all.compactMap { $0 as? Connector }
        #expect(connectors.count == 2)
        #expect(connectors[0].startPoint.x == .inches(5) && connectors[0].startPoint.y == .inches(3.5))
        #expect(connectors[0].endPoint.x == .inches(2.5) && connectors[0].endPoint.y == .inches(1.5))
        #expect(connectors[0].startConnection?.shapeID == idA && connectors[0].startConnection?.index == 1)
        #expect(connectors[0].endConnection?.shapeID == idB && connectors[0].endConnection?.index == 3)
        #expect(connectors[0].line?.headEnd == Arrowhead(.oval, width: .small, length: .small))
        #expect(connectors[0].line?.tailEnd == Arrowhead(.stealth, width: .large, length: .large))
        #expect(connectors[0].line?.dashStyle == "sysDashDot")
    }

    @Test func groupShapeAuthoringNestedContentsPicturesAndOutline() throws {
        let deck = try Presentation()
        try deck.fonts.register(realFontData(), aliases: ["GroupFont"])
        let slide = try deck.slides[0]

        let group = try slide.shapes.addGroup(
            Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(2)),
            childSpace: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)),
            name: "Diagram Cluster"
        )
        let label = try group.contents.addShape(
            .roundedRectangle,
            frame: Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(0.5)),
            fill: .solid(Color("336699"))
        )
        label.textFrame?.text = "Grouped"
        label.textFrame?.paragraphs[0].runs[0].fontName = "GroupFont"
        label.textFrame?.paragraphs[0].runs[0].fontSize = 10

        let pic = try group.contents.addPicture(
            Self.onePixelPNG,
            frame: Rect(x: .inches(1.1), y: .zero, width: .inches(0.4), height: .inches(0.4))
        )
        #expect(pic.imageData == Self.onePixelPNG)

        let inner = try group.contents.addGroup(
            Rect(x: .inches(1), y: .inches(0.5), width: .inches(1), height: .inches(0.5))
        )
        let poly = try inner.contents.addFreeform(
            Rect(x: .inches(1), y: .inches(0.5), width: .inches(0.8), height: .inches(0.4)),
            path: .polygon([(x: .zero, y: .inches(0.4)), (x: .inches(0.4), y: .zero), (x: .inches(0.8), y: .inches(0.4))]),
            fill: .solid(Color("CC8800")),
            line: nil
        )
        #expect(poly.isCustomGeometry)

        // Child space is 2x1 mapped onto 4x2 at (1in, 1in): (1in, 0.5in) -> (3in, 2in).
        let mapped = group.convertToParentSpace(Rect(x: .inches(1), y: .inches(0.5), width: .inches(0.5), height: .inches(0.25)))
        #expect(mapped == Rect(x: .inches(3), y: .inches(2), width: .inches(1), height: .inches(0.5)))

        #expect(try deck.validate().isEmpty)
        let outline = deck.outline()
        #expect(outline.slides[0].body.contains { block in
            block.paragraphs.map(\.text) == ["Grouped"]
        })
        #expect(outline.slides[0].assets.count == 1)

        let strict = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(strict.problems.isEmpty)
        #expect(strict.svg.contains("Grouped"))

        let saved = try deck.serializedData()
        let reopened = try Presentation(data: saved)
        let reopenedGroup = try #require(reopened.slides[0].shapes.all.first as? GroupShape)
        #expect(reopenedGroup.name == "Diagram Cluster")
        #expect(reopenedGroup.shapes.count == 3)
        let nestedGroup = try #require(reopenedGroup.shapes[2] as? GroupShape)
        #expect(nestedGroup.shapes.count == 1)
        #expect(nestedGroup.shapes[0].isCustomGeometry)
    }

    @Test func freeformPathAuthoringCurvesArcsOpenAndClosed() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]

        #expect(throws: RostrumError.self) {
            _ = try slide.shapes.addFreeform(
                Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1)),
                path: FreeformPath()
            )
        }

        var closed = FreeformPath(coordinateSize: (width: EMU(1000), height: EMU(1000)))
        closed.move(to: (x: EMU(0), y: EMU(500)))
        closed.addQuadCurve(to: (x: EMU(500), y: EMU(0)), control: (x: EMU(0), y: EMU(0)))
        closed.addCubicCurve(
            to: (x: EMU(1000), y: EMU(500)),
            control1: (x: EMU(750), y: EMU(0)),
            control2: (x: EMU(1000), y: EMU(250))
        )
        closed.addArc(radiusX: EMU(500), radiusY: EMU(500), startAngleDegrees: 0, sweepAngleDegrees: 90)
        closed.addLine(to: (x: EMU(0), y: EMU(1000)))
        closed.closeSubpath()

        let closedShape = try slide.shapes.addFreeform(
            Rect(x: .inches(0.5), y: .inches(0.5), width: .inches(2), height: .inches(2)),
            path: closed,
            fill: .solid(Color("44AA88")),
            line: Line(color: Color("113322"), width: .points(2))
        )
        #expect(closedShape.isCustomGeometry)
        #expect(closedShape.element.firstChild(named: "p:spPr")?.firstChild(named: "a:prstGeom") == nil)

        var openWave = FreeformPath(coordinateSize: (width: EMU(1000), height: EMU(500)))
        openWave.move(to: (x: EMU(0), y: EMU(250)))
        openWave.addCubicCurve(
            to: (x: EMU(1000), y: EMU(250)),
            control1: (x: EMU(333), y: EMU(0)),
            control2: (x: EMU(667), y: EMU(500))
        )
        _ = try slide.shapes.addFreeform(
            Rect(x: .inches(3), y: .inches(1), width: .inches(2.5), height: .inches(1)),
            path: openWave,
            fill: .none,
            line: Line(
                color: Color("224488"),
                width: .points(2),
                dash: .dash,
                headEnd: .oval,
                tailEnd: .stealth
            )
        )

        #expect(try deck.validate().isEmpty)
        let strict = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(strict.problems.isEmpty)
        #expect(strict.svg.contains("Q") && strict.svg.contains("C") && strict.svg.contains("A"))
    }

    // MARK: - Track 2: Typed Slide Transitions & p:transition / p:timing Round-Trip

    @Test func slideTransitionTypedAuthoringPreservesSndAcExtLstAndSchemaOrder() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        #expect(slide.transition == nil)

        // Append p:timing and p:extLst first to verify p:transition inserts before both.
        let sld = try slide.part.dom()
        sld.appendElement(try XML.parse(Data("<p:timing><p:tnLst><p:par><p:cTn id=\"1\" dur=\"indefinite\" nodeType=\"tmRoot\"/></p:par></p:tnLst></p:timing>".utf8)))
        sld.appendElement(XML.Element("p:extLst"))
        slide.part.markDirty()

        slide.transition = SlideTransition(
            .push(.up),
            speed: .fast,
            advanceOnClick: false,
            advanceAfterMilliseconds: 3500
        )
        #expect(try deck.validate().isEmpty)
        #expect(sld.childElements.map(\.name) == ["p:cSld", "p:clrMapOvr", "p:transition", "p:timing", "p:extLst"])

        // Attach p:sndAc and p:extLst inside p:transition and verify effect updates preserve them.
        let transEl = try #require(sld.firstChild(named: "p:transition"))
        transEl.appendElement(try XML.parse(Data("<p:sndAc><p:endSnd/></p:sndAc>".utf8)))
        transEl.appendElement(try XML.parse(Data("<p:extLst><p:ext uri=\"{12345678-1234-1234-1234-123456789ABC}\"/></p:extLst>".utf8)))
        slide.part.markDirty()

        slide.transition = SlideTransition(.wheel(spokes: 8), speed: .slow, advanceOnClick: true, advanceAfterMilliseconds: nil)
        #expect(try deck.validate().isEmpty)
        #expect(transEl.childElements.map(\.name) == ["p:wheel", "p:sndAc", "p:extLst"])

        let saved = try deck.serializedData()
        let reopened = try Presentation(data: saved)
        let readBack = try #require(reopened.slides[0].transition)
        #expect(readBack == SlideTransition(.wheel(spokes: 8), speed: .slow, advanceOnClick: true, advanceAfterMilliseconds: nil))

        let reopenedSlide0 = try reopened.slides[0]
        reopenedSlide0.transition = nil
        #expect(reopenedSlide0.transition == nil)
        #expect(try reopened.slides[0].part.dom().firstChild(named: "p:transition") == nil)
        #expect(try reopened.slides[0].part.dom().firstChild(named: "p:timing") != nil)
        #expect(try reopened.validate().isEmpty)
    }

    @Test func foreignTransitionAndTimingSurviveEditsAndSlideDuplication() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let shape = try slide.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(3), height: .inches(1)),
            fill: .solid(Color("335577"))
        )
        let spid = try #require(shape.shapeID)
        let sld = try slide.part.dom()
        let transitionXML = "<p:transition spd=\"med\" advTm=\"4000\"><p:split orient=\"vert\" dir=\"in\"/></p:transition>"
        let timingXML = """
        <p:timing><p:tnLst><p:par><p:cTn id="1" dur="indefinite" restart="never" nodeType="tmRoot"><p:childTnLst><p:seq concurrent="1" nextAc="seek"><p:cTn id="2" dur="indefinite" nodeType="mainSeq"><p:childTnLst><p:par><p:cTn id="3" fill="hold"><p:stCondLst><p:cond delay="indefinite"/></p:stCondLst><p:childTnLst><p:par><p:cTn id="4" presetID="10" presetClass="entr" presetSubtype="0" fill="hold" nodeType="clickEffect"><p:childTnLst><p:set><p:cBhvr><p:cTn id="5" dur="1" fill="hold"/><p:tgtEl><p:spTgt spid="\(spid)"/></p:tgtEl><p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst></p:cBhvr><p:to><p:strVal val="visible"/></p:to></p:set></p:childTnLst></p:cTn></p:par></p:childTnLst></p:cTn></p:par></p:childTnLst></p:cTn></p:seq></p:childTnLst></p:cTn></p:par></p:tnLst></p:timing>
        """
        sld.appendElement(try XML.parse(Data(transitionXML.utf8)))
        sld.appendElement(try XML.parse(Data(timingXML.utf8)))
        slide.part.markDirty()

        // Mutate slide content so the pristine blob cannot carry it passively; DOM round-trip must preserve both.
        _ = try slide.shapes.addShape(
            .ellipse,
            frame: Rect(x: .inches(5), y: .inches(1), width: .inches(1), height: .inches(1)),
            fill: .solid(Color("CC4422"))
        )
        _ = try deck.slides.duplicate(at: 0)

        let reopened = try Presentation(data: deck.serializedData())
        #expect(try reopened.validate().isEmpty)
        #expect(reopened.slides.count == 2)
        for idx in 0..<2 {
            let s = try reopened.slides[idx]
            #expect(s.transition == SlideTransition(.split(orientation: .vertical, direction: .inward), speed: .medium, advanceOnClick: true, advanceAfterMilliseconds: 4000))
            let timing = try #require(s.part.dom().firstChild(named: "p:timing"))
            #expect(timing.serialized().contains("presetClass=\"entr\""))
            #expect(timing.serialized().contains("spid=\"\(spid)\""))
        }
    }

    // MARK: - Track 3: Parenthesized Chart Workbook Formulas & Non-Mutating Export

    @Test func parenthesizedExcelChartFormulasAndCachelessDeckExportStayClean() throws {
        let pRange = try #require(ChartWorkbookReader.Range("(Sheet1!$A$2:$A$5)"))
        #expect(pRange.sheet == "Sheet1" && pRange.count == 4)
        let quotedRange = try #require(ChartWorkbookReader.Range("('Sales (Q1)'!$B$2:$D$2)"))
        #expect(quotedRange.sheet == "Sales (Q1)" && quotedRange.count == 3)
        #expect(ChartWorkbookReader.Range("(Sheet1!A1)+(Sheet1!B1)") == nil)
        #expect(ChartWorkbookReader.Range("(SUM(Sheet1!A1))") == nil)

        // Build a chart deck, strip XML caches, wrap formulas in parentheses, and save pristine bytes.
        let builder = try Presentation()
        _ = try builder.slides[0].shapes.addChart(
            .barClustered,
            data: ChartData(
                categories: ["North", "South", "West"],
                series: [ChartData.Series(name: "Revenue", values: [120, 180, 95])]
            ),
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(4)),
            options: ChartOptions(title: "Regional Revenue")
        )
        let chartPart = try #require(builder.charts.first?.part)
        let chartDOM = try chartPart.dom()
        func stripCachesAndParenthesize(_ node: XML.Element) {
            node.removeChildren(named: "c:strCache")
            node.removeChildren(named: "c:numCache")
            for child in node.childElements {
                if child.name == "c:f" {
                    let existing = child.textContent
                    child.children = [.text("(\(existing))")]
                } else {
                    stripCachesAndParenthesize(child)
                }
            }
        }
        stripCachesAndParenthesize(chartDOM)
        chartPart.markDirty()
        let cachelessBytes = try builder.serializedData()

        let cleanDeck = try Presentation(data: cachelessBytes)
        let reopenedChartPart = try #require(cleanDeck.charts.first?.part)
        let workbookPart = try #require(cleanDeck.package.parts.values.first { $0.uri.value.hasPrefix("/ppt/embeddings/") })
        #expect(!reopenedChartPart.isDirty && !workbookPart.isDirty)

        let outline = cleanDeck.outline()
        #expect(outline.slides[0].charts.count == 1)
        #expect(outline.slides[0].charts[0].grid == [
            ["Category", "Revenue"],
            ["North", "120"],
            ["South", "180"],
            ["West", "95"],
        ])

        let exportDir = FileManager.default.temporaryDirectory.appendingPathComponent("rostrum-r3-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: exportDir) }
        let summary = try DeckExport.write(cleanDeck, to: exportDir)
        #expect(summary.chartsWritten == 1 && summary.warnings.isEmpty)
        let csvURL = exportDir
            .appendingPathComponent(outline.slides[0].folderName)
            .appendingPathComponent(outline.slides[0].charts[0].filename)
        let csv = try String(contentsOf: csvURL, encoding: .utf8)
        #expect(csv.contains("Category,Revenue") && csv.contains("North,120") && csv.contains("South,180"))
        #expect(!reopenedChartPart.isDirty && !workbookPart.isDirty)
        #expect(try cleanDeck.serializedData() == cachelessBytes)
    }

    // MARK: - Track 4: Complete DrawingML Color Models & Transforms

    @Test func allSixDrawingMLColorModelsResolveAcrossShapesTextTablesAndBackgrounds() throws {
        let deck = try Presentation()
        try deck.fonts.register(realFontData(), aliases: ["ColorFont"])
        let slide = try deck.slides[0]

        // Slide background using a:hslClr (hue=120 deg -> 7200000, pure green #00FF00)
        let cSld = try #require(slide.part.dom().firstChild(named: "p:cSld"))
        cSld.insertChild(
            try XML.parse(Data("<p:bg><p:bgPr><a:solidFill><a:hslClr hue=\"7200000\" sat=\"100000\" lum=\"50000\"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>".utf8)),
            beforeAnyOf: ["p:spTree"]
        )
        slide.part.markDirty()
        #expect(slide.effectiveBackground == .solid(Color("00FF00")))

        // Corrupt sysClr@lastClr still resolves to nil rather than masking corruption.
        let corruptSys = try XML.parse(Data("<a:solidFill><a:sysClr val=\"windowText\" lastClr=\"NOTHEX\"/></a:solidFill>".utf8))
        #expect(DrawingColor.resolve(in: corruptSys, theme: deck.theme) == nil)

        // Valid sysClr without lastClr uses ST_SystemColorVal fallback.
        let fallbackSys = try XML.parse(Data("<a:solidFill><a:sysClr val=\"hotLight\"/></a:solidFill>".utf8))
        #expect(DrawingColor.resolve(in: fallbackSys, theme: deck.theme)?.color == Color("0066CC"))

        // Percentage-formatted scrgbClr ("100%", "0%", "0%").
        let pctScRGB = try XML.parse(Data("<a:solidFill><a:scrgbClr r=\"100%\" g=\"0%\" b=\"0%\"/></a:solidFill>".utf8))
        #expect(DrawingColor.resolve(in: pctScRGB, theme: deck.theme)?.color == Color("FF0000"))

        // Text run using a:prstClr val="medPurple" + a:hueOff, inside a table cell with a:prstClr val="ltSteelBlue".
        let table = try slide.shapes.addTable(
            rows: 1, columns: 1,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(3), height: .inches(1))
        )
        table.clearBuiltInStyle()
        let cell = try table.cell(0, 0)
        cell.text = "Spectrum"
        cell.textFrame.paragraphs[0].runs[0].fontName = "ColorFont"
        let rPr = try #require(cell.textFrame.paragraphs[0].runs[0].r.firstChild(named: "a:rPr"))
        rPr.removeChildren(named: "a:solidFill")
        rPr.appendElement(try XML.parse(Data("<a:solidFill><a:prstClr val=\"medPurple\"/></a:solidFill>".utf8)))
        cell.tcPr.appendElement(try XML.parse(Data("<a:solidFill><a:prstClr val=\"ltSteelBlue\"/></a:solidFill>".utf8)))
        slide.part.markDirty()

        let result = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(result.problems.isEmpty)
        let lowerSVG = result.svg.lowercased()
        #expect(lowerSVG.contains("#9370db")) // medPurple
        #expect(lowerSVG.contains("#b0c4de")) // ltSteelBlue
        #expect(lowerSVG.contains("#00ff00")) // hslClr background
    }

    // MARK: - Track 5: TrueType Collection (.ttc) Single-Face Extraction

    private static func makeTwoFaceTTC(from baseTTF: Data, restrictSecondFace: Bool = false) throws -> Data {
        func patchTTF(_ source: Data, familyASCII: String, restrict: Bool) throws -> [UInt8] {
            var bytes = [UInt8](source)
            let reader = SFNTReader(bytes: bytes)
            let numTables = try reader.u16(4)
            for i in 0..<numTables {
                let rec = 12 + 16 * i
                let tag = try reader.tag(rec)
                let offset = try reader.u32(rec + 8)
                let length = try reader.u32(rec + 12)
                if tag == "OS/2", restrict, length >= 10 {
                    bytes[offset + 8] = 0x00
                    bytes[offset + 9] = 0x02
                }
            }
            // Build a clean minimal name table for the synthetic family name and replace 'name' at end.
            let utf16 = Array(familyASCII.utf16).flatMap { [UInt8(($0 >> 8) & 0xFF), UInt8($0 & 0xFF)] }
            var nameTable: [UInt8] = [
                0, 0, // format 0
                0, 1, // count 1
                0, 18, // stringOffset 18
                0, 3, 0, 1, 0x04, 0x09, // platform 3, encoding 1, lang 0x0409
                0, 1, // nameID 1
                UInt8((utf16.count >> 8) & 0xFF), UInt8(utf16.count & 0xFF),
                0, 0, // offset 0
            ] + utf16
            while nameTable.count % 4 != 0 { nameTable.append(0) }
            while bytes.count % 4 != 0 { bytes.append(0) }
            let newNameOffset = bytes.count
            bytes.append(contentsOf: nameTable)
            for i in 0..<numTables {
                let rec = 12 + 16 * i
                if try reader.tag(rec) == "name" {
                    let off = UInt32(newNameOffset)
                    let len = UInt32(nameTable.count)
                    bytes[rec + 8] = UInt8((off >> 24) & 0xFF)
                    bytes[rec + 9] = UInt8((off >> 16) & 0xFF)
                    bytes[rec + 10] = UInt8((off >> 8) & 0xFF)
                    bytes[rec + 11] = UInt8(off & 0xFF)
                    bytes[rec + 12] = UInt8((len >> 24) & 0xFF)
                    bytes[rec + 13] = UInt8((len >> 16) & 0xFF)
                    bytes[rec + 14] = UInt8((len >> 8) & 0xFF)
                    bytes[rec + 15] = UInt8(len & 0xFF)
                }
            }
            return bytes
        }

        let face0 = try patchTTF(baseTTF, familyASCII: "TTCAlpha", restrict: false)
        let face1 = try patchTTF(baseTTF, familyASCII: "TTCBeta", restrict: restrictSecondFace)

        func u32Bytes(_ v: UInt32) -> [UInt8] {
            [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
        }
        // TTC header: 'ttcf' + v1.0 + count=2 + [offset0, offset1] = 20 bytes.
        let headerSize = 20
        let face0Start = headerSize
        let face1Start = face0Start + face0.count

        func relocateDirectory(_ fontBytes: [UInt8], delta: Int) throws -> [UInt8] {
            var shifted = fontBytes
            let r = SFNTReader(bytes: shifted)
            let n = try r.u16(4)
            for i in 0..<n {
                let rec = 12 + 16 * i
                let oldOff = try r.u32(rec + 8)
                let newOff = UInt32(oldOff + delta)
                shifted[rec + 8] = UInt8((newOff >> 24) & 0xFF)
                shifted[rec + 9] = UInt8((newOff >> 16) & 0xFF)
                shifted[rec + 10] = UInt8((newOff >> 8) & 0xFF)
                shifted[rec + 11] = UInt8(newOff & 0xFF)
            }
            return shifted
        }

        let relocated0 = try relocateDirectory(face0, delta: face0Start)
        let relocated1 = try relocateDirectory(face1, delta: face1Start)
        let header = Array("ttcf".utf8)
            + u32Bytes(0x0001_0000)
            + u32Bytes(2)
            + u32Bytes(UInt32(face0Start))
            + u32Bytes(UInt32(face1Start))
        return Data(header + relocated0 + relocated1)
    }

    @Test func trueTypeCollectionExtractsSelectedFaceForStrictSVGAndHonorsOS2Restrictions() throws {
        let baseTTF = try realFontData()
        let ttc = try Self.makeTwoFaceTTC(from: baseTTF, restrictSecondFace: false)

        // Verify standalone SFNT extraction and checksum integrity.
        let standalone1 = try FontMetrics.extractStandaloneSFNT(from: ttc, fontIndex: 1)
        #expect(Array(standalone1.prefix(4)) == [0x00, 0x01, 0x00, 0x00])
        let parsed1 = try FontMetrics(data: standalone1)
        #expect(parsed1.familyNames == ["TTCBeta"])
        var totalSum: UInt32 = 0
        let rawBytes = [UInt8](standalone1)
        for idx in stride(from: 0, to: rawBytes.count, by: 4) {
            let b0 = UInt32(rawBytes[idx])
            let b1 = idx + 1 < rawBytes.count ? UInt32(rawBytes[idx + 1]) : 0
            let b2 = idx + 2 < rawBytes.count ? UInt32(rawBytes[idx + 2]) : 0
            let b3 = idx + 3 < rawBytes.count ? UInt32(rawBytes[idx + 3]) : 0
            totalSum &+= (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
        }
        #expect(totalSum == 0xB1B0_AFBA)

        let deck = try Presentation()
        #expect(try deck.fonts.register(ttc, fontIndex: 0) == "TTCAlpha")
        #expect(try deck.fonts.register(ttc, fontIndex: 1) == "TTCBeta")
        // Original source data remains the complete TTC collection.
        #expect(deck.fonts.data(for: FontFaceKey(family: "TTCAlpha")) == ttc)
        #expect(deck.fonts.data(for: FontFaceKey(family: "TTCBeta")) == ttc)

        let box = try deck.slides[0].shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(1))
        )
        box.textFrame!.text = "Alpha "
        box.textFrame!.paragraphs[0].runs[0].fontName = "TTCAlpha"
        let run2 = box.textFrame!.paragraphs[0].addRun("Beta")
        run2.fontName = "TTCBeta"

        let result = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(result.problems.isEmpty)
        #expect(result.svg.components(separatedBy: "@font-face").count - 1 == 2)
        #expect(result.svg.contains(standalone1.base64EncodedString()))

        // Restricted TTC face must still be refused by OS/2 fsType check.
        let restrictedTTC = try Self.makeTwoFaceTTC(from: baseTTF, restrictSecondFace: true)
        let restrictedDeck = try Presentation()
        try restrictedDeck.fonts.register(restrictedTTC, fontIndex: 1)
        let restrictedBox = try restrictedDeck.slides[0].shapes.addTextBox(
            Rect(x: .zero, y: .zero, width: .inches(3), height: .inches(1))
        )
        restrictedBox.textFrame!.text = "NoEmbed"
        restrictedBox.textFrame!.paragraphs[0].runs[0].fontName = "TTCBeta"
        let restrictedReport = try restrictedDeck.renderSVGReportingProblems(slideAt: 0)
        #expect(restrictedReport.problems.fidelityIssues.contains { $0.code == .fontEmbeddingRestricted })
        #expect(throws: StrictRenderingError.self) {
            _ = try restrictedDeck.renderSVG(slideAt: 0, strictRendering: true)
        }
    }

    // MARK: - Track 6: Autoshape Line/Arc, Custom Dashes, Double Lines, & Open Arrowheads

    @Test func autoshapeLineArcCustomDashesDoubleLinesAndArrowheadsPassStrictMode() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]

        // 1. Autoshape .line with stealth/oval arrowheads + systemDashDotDot (must NOT render <rect>!).
        _ = try slide.shapes.addShape(
            .line,
            frame: Rect(x: .inches(0.5), y: .inches(0.5), width: .inches(3), height: .inches(0.5)),
            fill: .none,
            line: Line(
                color: Color("224466"),
                width: .points(2),
                dash: .systemDashDotDot,
                headEnd: .oval,
                tailEnd: .stealth
            )
        )

        // 2. Autoshape .arc with fill and arrowhead on its curved arc.
        _ = try slide.shapes.addShape(
            .arc,
            frame: Rect(x: .inches(4), y: .inches(0.5), width: .inches(2), height: .inches(2)),
            fill: .solid(Color("DDEEFF")),
            line: Line(color: Color("113355"), width: .points(2), tailEnd: .triangle)
        )

        // 3. Compound double-line (.double) on both .line and .rectangle.
        _ = try slide.shapes.addShape(
            .line,
            frame: Rect(x: .inches(0.5), y: .inches(2), width: .inches(3), height: .zero),
            fill: .none,
            line: Line(color: Color("882222"), width: .points(6), compound: .double)
        )
        let doubleRect = try slide.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(0.5), y: .inches(3), width: .inches(2), height: .inches(1)),
            fill: .solid(Color("FFF8EE")),
            line: Line(color: Color("882222"), width: .points(6), compound: .double)
        )

        // 4. Custom dash (<a:custDash><a:ds .../></a:custDash>) on an ellipse.
        let customDashed = try slide.shapes.addShape(
            .ellipse,
            frame: Rect(x: .inches(3.5), y: .inches(3), width: .inches(2), height: .inches(1)),
            fill: .none,
            line: Line(color: Color("226622"), width: .points(2))
        )
        let ln = try #require(customDashed.element.firstChild(named: "p:spPr")?.firstChild(named: "a:ln"))
        ln.removeChildren(named: "a:prstDash")
        ln.appendElement(try XML.parse(Data("<a:custDash><a:ds d=\"300000\" sp=\"150000\"/></a:custDash>".utf8)))
        slide.part.markDirty()

        #expect(try deck.validate().isEmpty)
        let strict = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(strict.problems.isEmpty)
        #expect(strict.svg.contains("<line x1=\"457200\" y1=\"457200\""))
        #expect(strict.svg.contains("stroke-dasharray=\"76200 38100\"")) // 3x and 1.5x 2pt (25400 EMU)
        _ = try XML.parse(Data(strict.svg.utf8))

        // Closed shape with arrowhead must still diagnose .unsupportedBorder and fail --strict.
        doubleRect.setLine(Line(color: .black, width: .points(2), tailEnd: .triangle))
        let closedArrowReport = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(closedArrowReport.problems.fidelityIssues.contains { $0.code == .unsupportedBorder })
        #expect(throws: StrictRenderingError.self) {
            _ = try deck.renderSVG(slideAt: 0, strictRendering: true)
        }
    }
}
