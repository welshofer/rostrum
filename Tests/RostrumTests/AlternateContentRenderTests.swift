import Foundation
import Testing
@testable import Rostrum

@Suite struct AlternateContentRenderTests {
    private func shape(_ id: Int, color: String, preset: String = "rect") -> String {
        """
        <p:sp><p:nvSpPr><p:cNvPr id="\(id)" name="Box"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="100" y="200"/><a:ext cx="400" cy="200"/></a:xfrm>
        <a:prstGeom prst="\(preset)"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="\(color)"/></a:solidFill></p:spPr></p:sp>
        """
    }

    private func alternate(choice: String, fallback: String?) -> String {
        "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\">"
            + "<mc:Choice xmlns:a14=\"http://schemas.microsoft.com/office/drawing/2010/main\" Requires=\"a14\">\(choice)</mc:Choice>"
            + (fallback.map { "<mc:Fallback>\($0)</mc:Fallback>" } ?? "")
            + "</mc:AlternateContent>"
    }

    private func group(_ children: String) -> String {
        """
        <p:grpSp><p:nvGrpSpPr><p:cNvPr id="2" name="Group"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
        <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1000" cy="1000"/>
        <a:chOff x="0" y="0"/><a:chExt cx="1000" cy="1000"/></a:xfrm></p:grpSpPr>\(children)</p:grpSp>
        """
    }

    private func append(_ xml: String, to part: Part) throws {
        let tree = try #require(Slide.existingSpTree(of: part))
        tree.appendElement(try XML.parse(Data(xml.utf8)))
        part.markDirty()
    }

    @Test func fallbackIsDrawnInsteadOfAnUnsupportedChoiceWithoutEditingTheDeck() throws {
        let deck = try Presentation()
        try append(alternate(choice: shape(20, color: "00FF00"), fallback: shape(21, color: "FF0000")), to: deck.slides[0].part)
        let before = try deck.serializedData()
        let result = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(result.problems.isEmpty)
        #expect(result.svg.contains("fill=\"#FF0000\""))
        #expect(!result.svg.contains("#00FF00"))
        #expect(try deck.serializedData() == before)
        _ = try XML.parse(Data(result.svg.utf8))
    }

    @Test func equationFallbackPictureIsDrawn() throws {
        let deck = try Presentation()
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        let slide = try deck.slides[0]
        let picture = try slide.shapes.addPicture(png,
            frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
        let tree = try #require(Slide.existingSpTree(of: slide.part))
        let index = try #require(tree.children.firstIndex { node in
            if case .element(let element) = node { return element === picture.element }
            return false
        })
        // PowerPoint's equation shape: a14 math in the choice, a picture of it in the fallback.
        let equation = try XML.parse(Data("""
        <p:sp><p:nvSpPr><p:cNvPr id="30" name="Equation"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1828800" cy="914400"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>
        <p:txBody><a:bodyPr/><a:p><a14:m><m:oMathPara><m:oMath><m:r><m:t>x</m:t></m:r></m:oMath></m:oMathPara></a14:m></a:p></p:txBody></p:sp>
        """.utf8))
        let wrapper = try XML.parse(Data(alternate(choice: "", fallback: "").utf8))
        wrapper.childElements[0].appendElement(equation)
        wrapper.childElements[1].appendElement(picture.element)
        tree.children[index] = .element(wrapper)
        slide.part.markDirty()
        let result = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(result.problems.isEmpty)
        #expect(result.svg.contains("<image"))
    }

    @Test func groupedBranchesKeepShapeLocationsAndMissingFallbackIsReported() throws {
        let deck = try Presentation()
        try append(group(
            alternate(choice: shape(20, color: "00FF00", preset: "star5"), fallback: shape(21, color: "FF0000", preset: "star5"))
            + alternate(choice: shape(22, color: "0000FF"), fallback: nil)
        ), to: deck.slides[0].part)
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        let geometry = report.problems.fidelityIssues.filter { $0.code == .unsupportedGeometry }
        #expect(geometry.map(\.location.shapeID) == ["21"])
        #expect(geometry.allSatisfy { $0.location.path.contains("/mc:AlternateContent[1]/mc:Fallback[1]/p:sp[1]/") })
        let omissions = report.problems.fidelityIssues.filter { $0.code == .omittedShape }
        #expect(omissions.count == 1)
        #expect(omissions.first?.location.path.hasSuffix("/mc:AlternateContent[2]") == true)
        #expect(report.problems.unsupportedContent.contains("Preview omitted alternate content that has no fallback."))
        #expect(!report.svg.contains("#00FF00") && !report.svg.contains("#0000FF"))
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
    }

    @Test func understoodChoiceIsPreferredOnlyWhenEveryRequirementIsKnown() throws {
        let content = try XML.parse(Data(alternate(choice: "<p:sp/>", fallback: "<p:pic/>").utf8))
        #expect(MarkupCompatibility.selectedBranch(of: content)?.branch.name == "mc:Fallback")
        let choiceOnly = try XML.parse(Data(alternate(choice: "<p:sp/>", fallback: nil).utf8))
        #expect(MarkupCompatibility.selectedBranch(of: choiceOnly) == nil)
    }
}
