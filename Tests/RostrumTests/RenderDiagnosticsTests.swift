import Foundation
import Testing
@testable import Rostrum

@Suite struct RenderDiagnosticsTests {
    private func realFont() throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf"))
    }

    @Test func registeredLatinAliasesEmbedOnceAndStrictModeDiagnosesLigatureBoundary() throws {
        let deck = try Presentation()
        let bytes = try realFont()
        try deck.fonts.register(bytes, aliases: ["Alias One", "Alias Two"])
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(4), height: .inches(1)))
        shape.textFrame!.text = "AV "
        shape.textFrame!.paragraphs[0].runs[0].fontName = "Alias One"
        let second = shape.textFrame!.paragraphs[0].addRun("office"); second.fontName = "Alias Two"
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(result.problems.fidelityIssues.count == 1)
        #expect(result.problems.fidelityIssues.first?.code == .unsupportedShaping)
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
        #expect(result.svg.components(separatedBy: "@font-face").count - 1 == 1)
        #expect(result.svg.contains(bytes.base64EncodedString()))
        #expect(result.svg.components(separatedBy: "font-family=\"RostrumEmbeddedFace1").count - 1 == 2)
        #expect(result.svg == (try deck.renderSVG(slideAt: 0)))
        _ = try XML.parse(Data(result.svg.utf8))
        second.text = "plain"
        #expect(try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true).problems.isEmpty)
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

    @Test(arguments: [false, true])
    func referencedThemeEffectsAreReportedAtEachShape(_ picture: Bool) throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let frame = Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1))
        let image = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        let shapes: [Shape] = try (0..<2).map { _ in
            if picture { return try slide.shapes.addPicture(image, frame: frame) }
            return try slide.shapes.addShape(.rectangle, frame: frame, fill: .solid(Color("AA4400")))
        }
        let theme = try #require(deck.package.parts.values.first { $0.contentType == ContentType.theme })
        let styles = try #require(theme.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme")?.firstChild(named: "a:effectStyleLst"))
        styles.children = [.element(try XML.parse(Data("<a:effectStyle><a:effectLst><a:outerShdw blurRad=\"40000\"/></a:effectLst></a:effectStyle>".utf8)))]
        theme.markDirty()
        for shape in shapes {
            shape.element.appendElement(try XML.parse(Data("<p:style><a:effectRef idx=\"1\"><a:schemeClr val=\"accent1\"/></a:effectRef></p:style>".utf8)))
        }
        slide.part.markDirty()
        let before = try deck.serializedData()
        let result = try deck.renderSVGReportingProblems(slideAt: 0)
        let effects = result.problems.fidelityIssues.filter { $0.code == .omittedEffect }
        #expect(effects.count == 2)
        #expect(Set(effects.compactMap { $0.location.shapeID }).count == 2)
        #expect(effects.allSatisfy { $0.location.partURI == slide.part.uri.description && $0.location.path.hasSuffix("/p:style/a:effectRef") })
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
        #expect(try deck.serializedData() == before)

        // Direct empty effects are an explicit override; they are not a reason
        // to reject a shape whose referenced style contains a shadow.
        for shape in shapes { shape.element.firstChild(named: "p:spPr")?.appendElement(XML.Element("a:effectLst")) }
        #expect(try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true).problems.isEmpty)
        for shape in shapes {
            shape.element.firstChild(named: "p:spPr")?.removeChildren(named: "a:effectLst")
            shape.element.firstChild(named: "p:style")?.firstChild(named: "a:effectRef")?[attribute: "idx"] = "0"
        }
        #expect(try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true).problems.isEmpty)
        shapes[0].element.firstChild(named: "p:style")?.firstChild(named: "a:effectRef")?[attribute: "idx"] = "999"
        #expect(try deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.contains { $0.code == .unresolvedInheritance })
    }

    @Test(arguments: ["a:effectLst", "a:effectDag", "a:scene3d", "a:sp3d"])
    func namespaceDeclarationsAloneDoNotCreateAnEffect(_ component: String) throws {
        let deck = try Presentation()
        let shape = try deck.slides[0].shapes.addShape(.rectangle,
            frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)), fill: .solid(Color("AA4400")))
        let empty = XML.Element(component, attributes: [("xmlns:a", MinimalTemplate.nsA), ("xmlns", MinimalTemplate.nsA)])
        let properties = try #require(shape.element.firstChild(named: "p:spPr"))
        properties.appendElement(empty)
        #expect(try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true).problems.isEmpty)
        properties.removeChildren(named: component)
        let theme = try #require(deck.package.parts.values.first { $0.contentType == ContentType.theme })
        let styles = try #require(theme.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme")?.firstChild(named: "a:effectStyleLst"))
        styles.children = [.element(XML.Element("a:effectStyle", children: [.element(empty)]))]
        shape.element.appendElement(try XML.parse(Data("<p:style><a:effectRef idx=\"1\"/></p:style>".utf8)))
        #expect(try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true).problems.isEmpty)
    }

    @Test func independentImageFixturesDistinguishMappingFromThemeEffects() throws {
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/ImageOffice")
        for version in ["v1", "v2"] {
            let deck = try Presentation(contentsOf: fixtures.appendingPathComponent("image-mapping-\(version).pptx"))
            let before = try deck.serializedData()
            #expect(deck.slides.count == 12)
            for index in 0..<12 {
                let issues = try deck.renderSVGReportingProblems(slideAt: index).problems.fidelityIssues
                if version == "v1" && (7...9).contains(index) {
                    #expect(issues.count == 1 && issues[0].code == .omittedEffect)
                    #expect(issues[0].location.path.hasSuffix("/p:style/a:effectRef"))
                } else {
                    #expect(issues.isEmpty)
                }
            }
            #expect(try deck.serializedData() == before)
        }
    }

    @Test(arguments: [false, true], [false, true])
    func themeOverrideEffectsCannotBeCertifiedFromTheMaster(_ onLayout: Bool, _ masterHasShadow: Bool) throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let shape = try slide.shapes.addShape(.rectangle,
            frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)), fill: .solid(Color("AA4400")))
        shape.element.appendElement(try XML.parse(Data("<p:style><a:effectRef idx=\"1\"/></p:style>".utf8)))
        let theme = slide.resolvedTheme.part
        let styles = try #require(theme.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme")?.firstChild(named: "a:effectStyleLst"))
        let shadow = "<a:outerShdw blurRad=\"40000\"/>"
        styles.children = [.element(try XML.parse(Data("<a:effectStyle><a:effectLst>\(masterHasShadow ? shadow : "")</a:effectLst></a:effectStyle>".utf8)))]
        theme.markDirty()
        let owner = onLayout ? try #require(slide.inheritanceParts.dropFirst().first) : slide.part
        let override = deck.package.addPart(uri: PackURI("/ppt/theme/override-test.xml"),
            contentType: "application/vnd.openxmlformats-officedocument.themeOverride+xml",
            blob: Data("<a:themeOverride xmlns:a=\"\(MinimalTemplate.nsA)\"><a:fmtScheme name=\"Override\"><a:effectStyleLst><a:effectStyle><a:effectLst>\(masterHasShadow ? "" : shadow)</a:effectLst></a:effectStyle></a:effectStyleLst></a:fmtScheme></a:themeOverride>".utf8))
        let relationType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/themeOverride"
        let overrideID = owner.rels.add(type: relationType, target: owner.uri.relativeReference(to: override.uri))
        slide.part.markDirty()
        let before = try deck.serializedData()
        let issues = try deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues
        #expect(issues.count == 1 && issues[0].code == .unresolvedInheritance)
        #expect(issues[0].location.partURI == slide.part.uri.description)
        #expect(issues[0].location.path.hasSuffix("/p:style/a:effectRef"))
        #expect(!issues.contains { $0.code == .omittedEffect })
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
        #expect(try deck.serializedData() == before)

        // An empty override has no format scheme to replace the master effects.
        override.replaceBlob(Data("<a:themeOverride xmlns:a=\"\(MinimalTemplate.nsA)\"/>".utf8))
        let inherited = try deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues
        #expect(inherited.count == (masterHasShadow ? 1 : 0))
        #expect(inherited.allSatisfy { $0.code == .omittedEffect })
        for xml in [
            "<x:themeOverride xmlns:x=\"urn:foreign\"/>",
            "<d:themeOverride xmlns:d=\"\(MinimalTemplate.nsA)\"><d:fmtScheme/></d:themeOverride>",
            "<themeOverride xmlns=\"\(MinimalTemplate.nsA)\"><fmtScheme/></themeOverride>"
        ] {
            override.replaceBlob(Data(xml.utf8))
            #expect(try deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.contains { $0.code == .unresolvedInheritance })
        }
        for xml in [
            "<a:themeOverride xmlns:a=\"\(MinimalTemplate.nsA)\" xmlns:x=\"urn:foreign\"><x:fmtScheme/></a:themeOverride>",
            "<a:themeOverride xmlns:a=\"\(MinimalTemplate.nsA)\"><a:fmtScheme xmlns:a=\"urn:foreign\"/></a:themeOverride>"
        ] {
            override.replaceBlob(Data(xml.utf8))
            #expect(try deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues == inherited)
        }
        override.replaceBlob(Data("malformed".utf8))
        #expect(try deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.contains { $0.code == .unresolvedInheritance })
        deck.package.removePart(at: override.uri)
        #expect(try deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.contains { $0.code == .unresolvedInheritance })
        owner.rels.remove(rId: overrideID)
        owner.rels.add(type: relationType, target: "https://example.invalid/theme.xml", isExternal: true)
        #expect(try deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.contains { $0.code == .unresolvedInheritance })
    }
}
