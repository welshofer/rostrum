import Foundation
import Testing
@testable import Rostrum

@Suite struct RenderDiagnosticsTests {
    private func realFont() throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf"))
    }

    @Test func strictRegisteredLatinEmbedsOneDeterministicFontForAliases() throws {
        let deck = try Presentation()
        let bytes = try realFont()
        try deck.fonts.register(bytes, aliases: ["Alias One", "Alias Two"])
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(4), height: .inches(1)))
        shape.textFrame!.text = "AV "
        shape.textFrame!.paragraphs[0].runs[0].fontName = "Alias One"
        let second = shape.textFrame!.paragraphs[0].addRun("office"); second.fontName = "Alias Two"
        let result = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(result.problems.isEmpty)
        #expect(result.svg.components(separatedBy: "@font-face").count - 1 == 1)
        #expect(result.svg.contains(bytes.base64EncodedString()))
        #expect(result.svg.components(separatedBy: "font-family=\"RostrumEmbeddedFace1").count - 1 == 2)
        #expect(result.svg == (try deck.renderSVG(slideAt: 0, strictRendering: true)))
        _ = try XML.parse(Data(result.svg.utf8))
    }

    @Test func restrictedFontsRemainMeasuredButAreNotEmbedded() throws {
        var bytes = try realFont()
        let reader = SFNTReader(bytes: Array(bytes))
        for i in 0..<(try reader.u16(4)) {
            let record = 12 + 16 * i
            if try reader.tag(record) == "OS/2" {
                let offset = try reader.u32(record + 8)
                bytes.replaceSubrange((offset + 8)..<(offset + 10), with: [0, 2])
            }
        }
        let deck = try Presentation()
        try deck.fonts.register(bytes, aliases: ["Restricted"])
        for x in [0, 1] {
            let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .inches(Double(x)), y: .zero, width: .inches(2), height: .inches(1)))
            shape.textFrame!.text = "AV"
            shape.textFrame!.paragraphs[0].runs[0].fontName = "Restricted"
        }
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(!result.svg.contains("@font-face"))
        #expect(result.problems.fidelityIssues.filter { $0.code == .fontEmbeddingRestricted }.count == 2)
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
    }

    @Test func strictAcceptsSupportedGeometryAndDefaultRemainsPermissive() throws {
        let deck = try Presentation()
        _ = try deck.slides[0].shapes.addShape(.rectangle,
            frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)), fill: .solid(Color("AA4400")))
        let before = try deck.serializedData()
        let result = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(result.problems.isEmpty)
        #expect(result.svg == (try deck.renderSVG(slideAt: 0)))
        #expect(try deck.serializedData() == before)
    }

    @Test func supportedPictureTransformsPassAndInvalidCropIsDiagnosed() throws {
        let deck = try Presentation()
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        let picture = try deck.slides[0].shapes.addPicture(png,
            frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
        let transform = try #require(picture.element.firstChild(named: "p:spPr")?.firstChild(named: "a:xfrm"))
        transform[attribute: "rot"] = "5400000"; transform[attribute: "flipH"] = "1"
        let blip = try #require(picture.element.firstChild(named: "p:blipFill")?.firstChild(named: "a:blip"))
        blip.appendElement(XML.Element("a:extLst"))
        try picture.setCrop(PictureCrop(left: 0.25))
        #expect(try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true).problems.isEmpty)
        let crop = try #require(picture.element.firstChild(named: "p:blipFill")?.firstChild(named: "a:srcRect"))
        crop[attribute: "l"] = "100000"
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(report.problems.fidelityIssues.contains { $0.code == .unsupportedImage && $0.location.path.contains("a:srcRect") })
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
    }

    @Test func missingFacesHaveStableLocationsAndStrictCarriesTheSameReport() throws {
        let deck = try Presentation()
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(3), height: .inches(1)))
        shape.textFrame!.text = "Missing face"
        shape.textFrame!.paragraphs[0].runs[0].fontName = "Never Registered"
        let before = try deck.serializedData()
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        let issue = try #require(result.problems.fidelityIssues.first { $0.code == .missingFont })
        #expect(issue.location.slideIndex == 0)
        #expect(issue.location.partURI == "/ppt/slides/slide1.xml")
        #expect(issue.location.shapeID != nil && issue.location.path.contains("p:sp["))
        #expect(issue.message.contains("Never Registered"))
        #expect(!result.problems.isEmpty)
        do {
            _ = try deck.renderSVG(slideAt: 0, strictRendering: true)
            Issue.record("Strict rendering accepted an unregistered face")
        } catch let error as StrictRenderingError {
            #expect(error.problems == result.problems)
        }
        #expect(try deck.renderSVGReportingProblems(slideAt: 0).problems == result.problems)
        #expect(try deck.serializedData() == before)
    }

    @Test func registeredMetricsEmbedFontsAndStillExposeUnsupportedShaping() throws {
        let deck = try Presentation()
        try deck.fonts.register(realFont(), aliases: ["Test Face"])
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(4), height: .inches(2)))
        shape.textFrame!.text = "Arabic سلام👩"
        shape.textFrame!.paragraphs[0].runs[0].fontName = "Test Face"
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        let codes = Set(result.problems.fidelityIssues.map(\.code))
        #expect(codes.contains(.unsupportedShaping) && codes.contains(.missingGlyph))
        #expect(!codes.contains(.viewerFontDependency) && !codes.contains(.missingFont))
        #expect(result.svg.contains("@font-face") && result.svg.contains("RostrumEmbeddedFace1"))
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
    }

    @Test func boundedTextOmissionIsReported() throws {
        let deck = try Presentation()
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: EMU(1), height: .inches(2)))
        shape.textFrame!.text = String(repeating: "too much text ", count: 100)
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.problems.fidelityIssues.contains { $0.code == .textTruncated && $0.impact == .omission })
        #expect(result.svg.contains("…"))
    }

    @Test func scannerReportsActualOmittedAndApproximateFeaturesWithoutMutation() throws {
        let deck = try Presentation(), part = try deck.slides[0].part
        let shape = try XML.parse(Data("""
        <p:sp><p:nvSpPr><p:cNvPr id="99"/></p:nvSpPr><p:spPr><a:xfrm rot="60000"/><a:prstGeom prst="star5"/><a:effectLst><a:outerShdw/></a:effectLst><a:blipFill><a:blip r:embed="missing"/></a:blipFill></p:spPr><p:txBody><a:bodyPr vert="vert" numCol="2"/></p:txBody></p:sp>
        """.utf8))
        let before = XML.document(shape)
        let collector = RenderDiagnosticCollector()
        collector.inspect(shape, owner: part, slideIndex: 2, path: "/p:sp[1]", package: deck.package)
        let codes = Set(collector.issues.map(\.code))
        #expect(codes.isSuperset(of: [.ignoredTransform, .unsupportedGeometry, .omittedEffect, .unavailableImage, .unsupportedTextProperty]))
        #expect(collector.issues.allSatisfy { $0.location.slideIndex == 2 && $0.location.shapeID == "99" })
        #expect(XML.document(shape) == before)
    }

    @Test func nativeTableStyleWithoutDefinitionIsReported() throws {
        let deck = try Presentation(), part = try deck.slides[0].part
        let frame = try XML.parse(Data("""
        <p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="7"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table"><a:tbl><a:tblPr><a:tableStyleId>{UNKNOWN-NATIVE-GUID}</a:tableStyleId></a:tblPr></a:tbl></a:graphicData></a:graphic></p:graphicFrame>
        """.utf8))
        let collector = RenderDiagnosticCollector()
        collector.inspect(frame, owner: part, slideIndex: 0, path: "/p:graphicFrame[1]", package: deck.package)
        #expect(collector.issues.contains { $0.code == .unresolvedTableStyle })
    }

    @Test func unsupportedCellPatternAndColorTransformsRemainVisible() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
        table.clearBuiltInStyle()
        try table.cell(0, 0).tcPr.appendElement(XML.parse(Data("<a:pattFill prst=\"cross\"><a:fgClr><a:srgbClr val=\"FF0000\"><a:hueOff val=\"60000\"/></a:srgbClr></a:fgClr><a:bgClr><a:prstClr val=\"orange\"/></a:bgClr></a:pattFill>".utf8)))
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(report.problems.fidelityIssues.contains { $0.code == .unsupportedFill })
        #expect(report.problems.fidelityIssues.filter { $0.code == .unsupportedColor }.count == 2)
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
    }

    @Test func unresolvedTableStylePropertiesAreReportedAtTheirOwningPart() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
        try table.setStyleDefinition(XML.parse(Data("<a:tblStyle styleId=\"{00000000-0000-0000-0000-000000000001}\" styleName=\"Pattern\"><a:wholeTbl><a:tcStyle><a:fill><a:pattFill prst=\"cross\"/></a:fill></a:tcStyle></a:wholeTbl></a:tblStyle>".utf8)))
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        let issue = try #require(report.problems.fidelityIssues.first { $0.code == .unsupportedFill })
        #expect(issue.location.partURI == "/ppt/tableStyles.xml")
        #expect(issue.location.path.contains("a:pattFill"))
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
    }

    @Test(arguments: [false, true])
    func disabledTableStyleRegionsDoNotCauseFalseStrictFailures(_ inline: Bool) throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1,
            frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
        table.firstRowHeader = false
        try table.setStyleDefinition(XML.parse(Data("<a:tblStyle styleId=\"{00000000-0000-0000-0000-000000000002}\" styleName=\"Inactive\"><a:wholeTbl><a:tcStyle><a:fill><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:fill></a:tcStyle></a:wholeTbl><a:firstRow><a:tcStyle><a:fill><a:pattFill prst=\"cross\"/></a:fill></a:tcStyle></a:firstRow></a:tblStyle>".utf8)))
        if inline {
            let definition = try #require(TableStyleResolver.definition(for: table.tbl, package: deck.package).0).deepCopy()
            definition.name = "a:tableStyle"
            let properties = try #require(table.tbl.firstChild(named: "a:tblPr"))
            properties.removeChildren(named: "a:tableStyleId")
            properties.insertChild(definition, beforeAnyOf: ["a:extLst"])
        }
        #expect(try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true).problems.isEmpty)
        table.firstRowHeader = true
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
    }

    @Test func fontFamilyAttributeRemainsValidXML() throws {
        let deck = try Presentation()
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
        shape.textFrame!.text = "Quoted family"
        shape.textFrame!.paragraphs[0].runs[0].fontName = "A\"B & C"
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("A&quot;B &amp; C"))
        _ = try XML.parse(Data(svg.utf8))
    }
}
