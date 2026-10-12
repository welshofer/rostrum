import Foundation
import Testing
@testable import Rostrum

@Suite struct GroupedRenderDiagnosticsTests {
    private func group(_ id: String, children: [XML.Element]) throws -> XML.Element {
        let group = try XML.parse(Data("""
        <p:grpSp><p:nvGrpSpPr><p:cNvPr id="\(id)" name="Group"/></p:nvGrpSpPr>
        <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="5000000" cy="5000000"/>
        <a:chOff x="0" y="0"/><a:chExt cx="5000000" cy="5000000"/></a:xfrm></p:grpSpPr></p:grpSp>
        """.utf8))
        for child in children { group.appendElement(child) }
        return group
    }

    private func shape(_ id: String, properties: String = "", text: Bool = false) throws -> XML.Element {
        let body = text ? """
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr sz="1200"><a:latin typeface="Missing Group Font"/></a:rPr>
        <a:t>Child text</a:t></a:r></a:p></p:txBody>
        """ : ""
        return try XML.parse(Data("""
        <p:sp><p:nvSpPr><p:cNvPr id="\(id)" name="Child \(id)"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="2000000" cy="1000000"/></a:xfrm>
        <a:prstGeom prst="rect"/><a:solidFill><a:srgbClr val="336699"/></a:solidFill>\(properties)</p:spPr>\(body)</p:sp>
        """.utf8))
    }

    private let shadow = """
    <a:effectLst><a:outerShdw blurRad="40000" dist="20000"><a:srgbClr val="000000"/></a:outerShdw></a:effectLst>
    """

    @Test(arguments: ["slide", "layout", "master"])
    func nestedEffectsKeepTheirShapeAndOwningPart(_ source: String) throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let owner = source == "slide" ? slide.part : source == "layout"
            ? try #require(slide.layout).part : try #require(slide.master).part
        let first = try shape("2", properties: shadow)
        let second = try shape("3", properties: shadow.replacingOccurrences(of: "blurRad=", with: "sx=\"50000\" blurRad="))
        let nested = try group("101", children: [second])
        let tree = try #require(Slide.existingSpTree(of: owner))
        tree.appendElement(try group("100", children: [first, nested]))
        owner.markDirty()
        let before = try deck.serializedData()
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        let effects = report.problems.fidelityIssues.filter { $0.code == .omittedEffect }
        #expect(effects.count == 2)
        #expect(effects.map(\.location.shapeID) == ["2", "3"])
        #expect(effects.map(\.impact) == [.approximation, .omission])
        #expect(effects.allSatisfy { $0.location.partURI == owner.uri.description })
        #expect(effects[0].location.path.hasSuffix("/p:sp[1]/p:spPr[1]/a:effectLst[1]"))
        #expect(effects[1].location.path.hasSuffix("/p:grpSp[1]/p:sp[1]/p:spPr[1]/a:effectLst[1]"))
        #expect(try deck.serializedData() == before)
        let reopened = try Presentation(data: before)
        #expect(try reopened.renderSVGReportingProblems(slideAt: 0) == report)
        do {
            _ = try deck.renderSVG(slideAt: 0, strictRendering: true)
            Issue.record("Strict rendering accepted grouped effects")
        } catch let error as StrictRenderingError {
            #expect(error.problems.fidelityIssues == report.problems.fidelityIssues)
        }
    }

    @Test func siblingTextWarningsDoNotMergeAndReusedRendererKeepsEditsLive() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        // Duplicate producer IDs still have different source paths.
        let hidden = try shape("99", text: true)
        hidden.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "hidden"] = "1"
        let first = try shape("2", text: true), second = try shape("2", text: true)
        let tree = try #require(Slide.existingSpTree(of: slide.part))
        tree.appendElement(try group("100", children: [hidden, first, second]))
        slide.part.markDirty()
        let renderer = SVGRenderer(slidePart: slide.part, slideSize: deck.slideSize,
            theme: slide.resolvedTheme, package: deck.package, fonts: deck.fonts, slideNumber: 1)
        let initial = try renderer.render(pixelWidth: 640)
        let missing = initial.problems.fidelityIssues.filter { $0.code == .missingFont }
        #expect(missing.count == 2)
        #expect(missing.map(\.location.shapeID) == ["2", "2"])
        #expect(missing.map { $0.location.path.split(separator: "/").last.map(String.init) } == ["p:sp[2]", "p:sp[3]"])
        first.removeChildren(named: "p:txBody")
        slide.part.markDirty()
        let next = try renderer.render(pixelWidth: 640)
        if missing.count == 2 {
            #expect(next.problems.fidelityIssues.filter { $0.code == .missingFont }.map(\.location) == [missing[1].location])
        }
        #expect(next.problems.fidelityIssues == (try deck.renderSVGReportingProblems(slideAt: 0)).problems.fidelityIssues)
    }

    @Test func hiddenChildrenAndInheritedPlaceholdersDoNotReportOmittedEffects() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let master = try #require(slide.master).part
        let hidden = try shape("2", properties: "<a:effectLst><a:glow/></a:effectLst>")
        hidden.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "hidden"] = "1"
        let placeholder = try shape("3", properties: "<a:effectLst><a:glow/></a:effectLst>")
        placeholder.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.appendElement(XML.Element("p:ph"))
        let tree = try #require(Slide.existingSpTree(of: master))
        tree.appendElement(try group("100", children: [hidden, placeholder, shape("4")]))
        master.markDirty()
        #expect(try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true).problems.isEmpty)
    }

    @Test func groupedConnectorsKeepTheirSupportedStrokeRules() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let connector = try XML.parse(Data("""
        <p:cxnSp><p:nvCxnSpPr><p:cNvPr id="2" name="Arrow"/></p:nvCxnSpPr>
        <p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1000000" cy="1000000"/></a:xfrm>
        <a:prstGeom prst="line"/><a:ln w="12700"><a:solidFill><a:srgbClr val="000000"/></a:solidFill>
        <a:prstDash val="dash"/><a:tailEnd type="triangle"/></a:ln></p:spPr></p:cxnSp>
        """.utf8))
        let tree = try #require(Slide.existingSpTree(of: slide.part))
        tree.appendElement(try group("100", children: [connector]))
        slide.part.markDirty()
        let report = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(report.problems.isEmpty)
        #expect(report.svg.contains("stroke-dasharray") && report.svg.contains("marker-end"))
    }

    @Test func malformedNestedGroupsAndConnectorsKeepStructuredOmissions() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        let malformedGroup = try XML.parse(Data("<p:grpSp><p:nvGrpSpPr><p:cNvPr id=\"2\"/></p:nvGrpSpPr></p:grpSp>".utf8))
        let malformedConnector = try XML.parse(Data("<p:cxnSp><p:nvCxnSpPr><p:cNvPr id=\"3\"/></p:nvCxnSpPr></p:cxnSp>".utf8))
        let tree = try #require(Slide.existingSpTree(of: slide.part))
        tree.appendElement(try group("100", children: [malformedGroup, malformedConnector]))
        slide.part.markDirty()
        let omissions = try deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.filter { $0.code == .omittedShape }
        #expect(omissions.map(\.location.shapeID) == ["2", "3"])
        #expect(omissions.map { $0.location.path.split(separator: "/").last.map(String.init) } == ["p:grpSp[1]", "p:cxnSp[1]"])
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
    }
}
