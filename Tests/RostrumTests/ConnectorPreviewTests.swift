import Foundation
import Testing
@testable import Rostrum

@Suite struct ConnectorPreviewTests {
    @Test func elbowGeometryIsRenderedOnceWithoutRectangleWarning() throws {
        for (height, preset, guide) in [(0, "bentConnector3", ""), (200000, "bentConnector3", "val 25000"), (200000, "curvedConnector3", "")] {
            let deck = try Presentation(), slide = try deck.slides[0]
            let tree = try #require(Slide.existingSpTree(of: slide.part))
            let adjustment = guide.isEmpty ? "" : "<a:gd name=\"adj1\" fmla=\"\(guide)\"/>"
            tree.appendElement(try XML.parse(Data("""
            <p:cxnSp><p:nvCxnSpPr><p:cNvPr id="77" name="Connector"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>
            <p:spPr><a:xfrm><a:off x="100" y="200"/><a:ext cx="400000" cy="\(height)"/></a:xfrm>
            <a:prstGeom prst="\(preset)"><a:avLst>\(adjustment)</a:avLst></a:prstGeom>
            <a:ln w="12700"><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></a:ln></p:spPr></p:cxnSp>
            """.utf8)))
            slide.part.markDirty()
            let bytes = try deck.serializedData(), result = try deck.renderSVGReportingProblems(slideAt: 0)
            let issues = result.problems.fidelityIssues.filter { $0.code == .unsupportedGeometry }
            #expect(!result.problems.messages.contains { $0.contains("rectangle") })
            if preset == "bentConnector3" {
                #expect(issues.isEmpty)
                if height > 0 { #expect(result.svg.contains("M100 200 H100100 V200200 H400100")) }
                else { #expect(result.svg.contains("x1=\"100\" y1=\"200\" x2=\"400100\" y2=\"200\"")) }
            } else {
                #expect(issues.count == 1)
                #expect(issues.first?.location.shapeID == "77")
            }
            #expect(try deck.serializedData() == bytes)
        }
    }
}
