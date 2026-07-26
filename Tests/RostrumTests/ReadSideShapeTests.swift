import Foundation
import Testing
@testable import Rostrum

/// A slide whose shape tree carries one of everything, written the way
/// PowerPoint writes it — the fixture the real-deck corpus cannot provide
/// until authored decks land, and the only place a group's child coordinate
/// space and a connector's attachment sites are pinned.
private let foreignSlideXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" \
xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" \
xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree>\
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\
<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>\
<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>\
<p:sp><p:nvSpPr><p:cNvPr id="2" name="Title 1"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\
<p:spPr><a:xfrm><a:off x="100" y="200"/><a:ext cx="300" cy="400"/></a:xfrm></p:spPr>\
<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Hello</a:t></a:r></a:p></p:txBody></p:sp>\
<p:pic><p:nvPicPr><p:cNvPr id="3" name="Photo 2" descr="A cat"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>\
<p:blipFill><a:blip r:embed="rId99"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>\
<p:spPr><a:xfrm><a:off x="10" y="20"/><a:ext cx="30" cy="40"/></a:xfrm></p:spPr></p:pic>\
<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="4" name="Table 3"/><p:cNvGraphicFramePr/>\
<p:nvPr/></p:nvGraphicFramePr><p:xfrm><a:off x="1000" y="2000"/><a:ext cx="3000" cy="4000"/></p:xfrm>\
<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">\
<a:tbl><a:tblPr/><a:tblGrid><a:gridCol w="1500"/><a:gridCol w="1500"/></a:tblGrid>\
<a:tr h="370"><a:tc><a:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>R1C1</a:t></a:r></a:p></a:txBody></a:tc>\
<a:tc><a:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>R1C2</a:t></a:r></a:p></a:txBody></a:tc></a:tr>\
</a:tbl></a:graphicData></a:graphic></p:graphicFrame>\
<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="5" name="Diagram 4"/><p:cNvGraphicFramePr/>\
<p:nvPr/></p:nvGraphicFramePr><p:xfrm><a:off x="5" y="6"/><a:ext cx="7" cy="8"/></p:xfrm>\
<a:graphic><a:graphicData uri="http://schemas.microsoft.com/office/drawing/2014/chartex">\
<cx:chart xmlns:cx="http://schemas.microsoft.com/office/drawing/2014/chartex" r:id="rId7"/>\
</a:graphicData></a:graphic></p:graphicFrame>\
<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="6" name="Connector 5"/>\
<p:cNvCxnSpPr><a:stCxn id="2" idx="3"/><a:endCxn id="3" idx="1"/></p:cNvCxnSpPr><p:nvPr/></p:nvCxnSpPr>\
<p:spPr><a:xfrm><a:off x="11" y="12"/><a:ext cx="13" cy="14"/></a:xfrm></p:spPr></p:cxnSp>\
<p:grpSp><p:nvGrpSpPr><p:cNvPr id="7" name="Group 6"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\
<p:grpSpPr><a:xfrm><a:off x="1000" y="1000"/><a:ext cx="2000" cy="2000"/>\
<a:chOff x="0" y="0"/><a:chExt cx="1000" cy="1000"/></a:xfrm></p:grpSpPr>\
<p:sp><p:nvSpPr><p:cNvPr id="8" name="In group"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\
<p:spPr><a:xfrm><a:off x="500" y="500"/><a:ext cx="100" cy="100"/></a:xfrm></p:spPr>\
<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Nested</a:t></a:r></a:p></p:txBody></p:sp></p:grpSp>\
<p:extLst><p:ext uri="{X}"/></p:extLst>\
</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>
"""

/// Builds a deck whose first slide is `foreignSlideXML`, by replacing the
/// blob of the slide part Rostrum created.
private func deckWithForeignSlide() throws -> Presentation {
    let deck = try Presentation()
    let slide = try deck.slides[0]
    slide.part.replaceBlob(Data(foreignSlideXML.utf8))
    return deck
}

@Suite struct ReadSideShapeTests {
    @Test func everyShapeTreeChildIsEnumeratedInOrder() throws {
        let shapes = try deckWithForeignSlide().slides[0].shapes.all
        // The tree's own p:nvGrpSpPr / p:grpSpPr / p:extLst are not shapes.
        #expect(shapes.map(\.kind) == [
            .autoShape, .picture, .table,
            .graphicFrame(uri: "http://schemas.microsoft.com/office/drawing/2014/chartex"),
            .connector, .group,
        ])
        #expect(shapes.map(\.shapeID) == [2, 3, 4, 5, 6, 7])
        #expect(shapes.map(\.name) == ["Title 1", "Photo 2", "Table 3", "Diagram 4",
                                       "Connector 5", "Group 6"])
    }

    @Test func autoShapesKeepsTheOldNarrowView() throws {
        let shapes = try deckWithForeignSlide().slides[0].shapes
        #expect(shapes.autoShapes.count == 1)
        #expect(shapes.autoShapes[0].textFrame?.text == "Hello")
    }

    @Test func eachKindReadsItsOwnTransform() throws {
        let shapes = try deckWithForeignSlide().slides[0].shapes.all
        // p:sp and p:cxnSp keep it in p:spPr/a:xfrm, p:graphicFrame in p:xfrm,
        // p:grpSp in p:grpSpPr/a:xfrm — a single assumption would break three.
        #expect(shapes[0].frame == Rect(x: EMU(100), y: EMU(200), width: EMU(300), height: EMU(400)))
        #expect(shapes[1].frame == Rect(x: EMU(10), y: EMU(20), width: EMU(30), height: EMU(40)))
        #expect(shapes[2].frame == Rect(x: EMU(1000), y: EMU(2000), width: EMU(3000), height: EMU(4000)))
        #expect(shapes[4].frame == Rect(x: EMU(11), y: EMU(12), width: EMU(13), height: EMU(14)))
        #expect(shapes[5].frame == Rect(x: EMU(1000), y: EMU(1000), width: EMU(2000), height: EMU(2000)))
    }

    @Test func picturesExposeTheirImage() throws {
        let deck = try Presentation()
        func be32(_ v: Int) -> [UInt8] {
            [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)]
        }
        var bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        bytes += be32(13); bytes += Array("IHDR".utf8)
        bytes += be32(8); bytes += be32(8); bytes += [8, 6, 0, 0, 0]; bytes += be32(0)
        bytes += be32(0); bytes += Array("IEND".utf8); bytes += be32(0)
        let png = Data(bytes)
        let added = try deck.slides[0].shapes.addPicture(
            png, frame: Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1)))
        added.altText = "A friendly cat"

        let reopened = try Presentation(data: try deck.serializedData())
        let picture = try #require(reopened.slides[0].shapes.all.first as? Picture)
        #expect(picture.kind == .picture)
        #expect(picture.imageData == png)
        #expect(picture.imageFormat == "png")
        #expect(picture.altText == "A friendly cat")
    }

    @Test func tableFramesReadTheirCellsBack() throws {
        let shapes = try deckWithForeignSlide().slides[0].shapes.all
        let frame = try #require(shapes.first { $0.kind == .table } as? TableFrame)
        let table = try #require(frame.table)
        #expect(table.rowCount == 1)
        #expect(table.columnCount == 2)
        #expect(table.cell(0, 0).text == "R1C1")
        #expect(table.cell(0, 1).text == "R1C2")
    }

    @Test func chartFramesResolveTheirPart() throws {
        let deck = try Presentation()
        try deck.chartSlide("Chart", .line,
                            ChartData(categories: ["A", "B"], name: "S", values: [1, 2]))
        let reopened = try Presentation(data: try deck.serializedData())
        let slide = try reopened.slides[reopened.slides.count - 1]
        let chart = try #require(slide.shapes.all.first { $0.kind == .chart } as? ChartFrame)
        let part = try #require(chart.chartPart)
        #expect(part.uri.value.hasPrefix("/ppt/charts/"))
        #expect(String(decoding: part.blob, as: UTF8.self).contains("c:lineChart"))
    }

    @Test func unmodeledGraphicFramesStayVisible() throws {
        let shapes = try deckWithForeignSlide().slides[0].shapes.all
        let chartex = try #require(shapes.first { $0.kind.graphicDataURI?.contains("chartex") == true })
        // Not dropped, and not misreported as a chart Rostrum can read.
        #expect(chartex.kind.isGraphicFrame)
        #expect((chartex as? ChartFrame) == nil)
        #expect(chartex.frame == Rect(x: EMU(5), y: EMU(6), width: EMU(7), height: EMU(8)))
    }

    @Test func connectorsExposeTheirAttachments() throws {
        let shapes = try deckWithForeignSlide().slides[0].shapes.all
        let connector = try #require(shapes.first { $0.kind == .connector } as? Connector)
        #expect(connector.startConnection?.shapeID == 2)
        #expect(connector.startConnection?.index == 3)
        #expect(connector.endConnection?.shapeID == 3)
        #expect(connector.endConnection?.index == 1)
    }

    @Test func groupsRecurseAndMapChildCoordinates() throws {
        let shapes = try deckWithForeignSlide().slides[0].shapes.all
        let group = try #require(shapes.first { $0.kind == .group } as? GroupShape)
        #expect(group.shapes.count == 1)
        let child = group.shapes[0]
        #expect(child.textFrame?.text == "Nested")
        // Child space is 1000×1000 mapped onto a 2000×2000 frame at (1000,1000):
        // a child at (500,500) sized 100×100 lands at (2000,2000) sized 200×200.
        #expect(child.frame == Rect(x: EMU(500), y: EMU(500), width: EMU(100), height: EMU(100)))
        #expect(group.convertToParentSpace(child.frame)
                == Rect(x: EMU(2000), y: EMU(2000), width: EMU(200), height: EMU(200)))
    }

    @Test func degenerateChildSpaceReturnsCoordinatesUnchanged() throws {
        // A group declaring a 0×0 child space (PowerPoint writes exactly this
        // on an empty tree): the mapping is undefined, so coordinates must
        // come back untouched rather than divided by zero.
        let deck = try Presentation()
        let part = try deck.slides[0].part
        let grpSp = XML.Element("p:grpSp")
        let grpSpPr = XML.Element("p:grpSpPr")
        let xfrm = XML.Element("a:xfrm")
        xfrm.appendElement(XML.Element("a:off", attributes: [("x", "0"), ("y", "0")]))
        xfrm.appendElement(XML.Element("a:ext", attributes: [("cx", "0"), ("cy", "0")]))
        xfrm.appendElement(XML.Element("a:chOff", attributes: [("x", "0"), ("y", "0")]))
        xfrm.appendElement(XML.Element("a:chExt", attributes: [("cx", "0"), ("cy", "0")]))
        grpSpPr.appendElement(xfrm)
        grpSp.appendElement(grpSpPr)

        let group = GroupShape(element: grpSp, part: part, package: deck.package)
        let rect = Rect(x: EMU(1), y: EMU(2), width: EMU(3), height: EMU(4))
        #expect(group.convertToParentSpace(rect) == rect)
        #expect(group.shapes.isEmpty)
    }

    @Test func enumerationNeverMutatesThePart() throws {
        let deck = try deckWithForeignSlide()
        let original = try deck.serializedData()

        let reopened = try Presentation(data: original)
        for slide in reopened.slides {
            for shape in slide.shapes.all {
                _ = shape.kind
                _ = shape.frame
                _ = shape.explicitFrame
                _ = shape.rotation
                _ = shape.name
                _ = shape.altText
                _ = shape.textFrame?.text
                if let group = shape as? GroupShape { _ = group.shapes.map(\.frame) }
                if let table = (shape as? TableFrame)?.table { _ = table.rowCount }
                if let picture = shape as? Picture { _ = picture.imageData }
            }
        }
        // Reading the whole tree must leave every part pristine.
        #expect(try reopened.serializedData() == original)
    }

    @Test func readingAGraphicFrameNeverInventsShapeProperties() throws {
        // The 0.3 bug: `frame`'s GETTER ran getOrAddChild("p:spPr"), so merely
        // reading a chart's frame appended a schema-invalid <p:spPr/> to the
        // p:graphicFrame — and PowerPoint offered to repair the file.
        let deck = try Presentation()
        let chart = try deck.slides[0].shapes.addChart(
            .line, data: ChartData(categories: ["A"], name: "S", values: [1]),
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(3)))
        _ = chart.frame
        _ = chart.rotation
        chart.enableSoftShadow()          // no-op: a graphic frame has no spPr
        chart.setLine(Line(color: .black, width: .points(1)))
        #expect(chart.element.firstChild(named: "p:spPr") == nil)
        #expect(throws: RostrumError.self) { try chart.setFill(.solid(.white)) }
        // And the frame still reads from p:xfrm, where it actually lives.
        #expect(chart.frame.width == EMU.inches(4))
        #expect(try deck.validate().isEmpty)
    }
}
