import Foundation
import Testing
@testable import Rostrum

@Suite struct RichTextParagraphMetricsTests {
    @Test func paragraphSpacingRetainsPerLineMetricsAndMalformedChoicePrecedence() throws {
        let font = try FontMetrics(data: TestFont.standard())
        for (spacing, expectedHeights) in [
            ("", [20.0, 10.0]),
            ("<a:lnSpc><a:spcPts val=\"1250\"/></a:lnSpc>", [12.5, 12.5]),
            ("<a:lnSpc><a:spcPct val=\"125000\"/></a:lnSpc>", [25.0, 12.5]),
            ("<a:lnSpc/>", [0.0, 0.0]),
            ("<a:lnSpc><a:spcPts val=\"bad\"/><a:spcPct val=\"125000\"/></a:lnSpc>", [0.0, 0.0]),
        ] {
            let body = try XML.parse(Data("""
            <a:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0"/>
            <a:p><a:pPr algn="r">\(spacing)</a:pPr>
            <a:r><a:rPr sz="2000"/><a:t>A</a:t></a:r><a:br/>
            <a:r><a:rPr sz="1000"/><a:t>B</a:t></a:r></a:p></a:txBody>
            """.utf8))
            let layout = RichTextLayout(textBody: body, width: 100, height: 100, fallbackMetrics: font)
            #expect(layout.lines.map(\.height) == expectedHeights, "\(spacing)")
            #expect(layout.lines.map(\.baseline) == [16, expectedHeights[0] + 8], "\(spacing)")
            #expect(layout.contentHeight == expectedHeights.reduce(0, +))
            #expect(layout.lines.allSatisfy { abs(($0.spans.first?.x ?? 0) + $0.width - 100) < 0.000001 })
        }
    }

    @Test func inheritedPercentageSpacingUsesEachWrappedLineHeight() throws {
        let body = try XML.parse(Data("""
        <a:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0">
        <a:normAutofit lnSpcReduction="10000"/></a:bodyPr>
        <a:p><a:r><a:rPr sz="2000"/><a:t>AA</a:t></a:r></a:p>
        <a:p><a:pPr><a:lnSpc><a:spcPts val="1250"/></a:lnSpc></a:pPr>
        <a:r><a:rPr sz="1000"/><a:t>BB</a:t></a:r></a:p></a:txBody>
        """.utf8))
        let inherited = try XML.parse(Data("""
        <a:lstStyle><a:lvl1pPr><a:lnSpc><a:spcPct val="125000"/></a:lnSpc></a:lvl1pPr></a:lstStyle>
        """.utf8))
        let layout = RichTextLayout(textBody: body, width: 6, height: 200,
            fallbackMetrics: try FontMetrics(data: TestFont.standard()), inheritedStyles: [inherited])
        #expect(layout.lines.map(\.height) == [22.5, 22.5, 11.25, 11.25])
        #expect(layout.lines.map(\.baseline) == [16, 38.5, 53, 64.25])
        #expect(layout.contentHeight == 67.5)
    }
}
