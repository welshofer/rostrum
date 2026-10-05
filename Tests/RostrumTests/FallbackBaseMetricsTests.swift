import Foundation
import Testing
@testable import Rostrum

@Suite struct FallbackBaseMetricsTests {
    @Test(arguments: ["", "malformed", "NaN", "-Infinity", "0", "1250", "999999"])
    func emptyAndBulletedParagraphsMatchUnresolvedRegisteredPath(size: String) throws {
        // A nonempty library selects full base-style resolution, but this face
        // cannot resolve any requested family. Both layouts use fallback metrics.
        let unrelated = FontLibrary()
        try unrelated.register(FontFaceTests.font(400, bold: false, italic: false), aliases: ["Unrelated"])
        #expect(unrelated.previewFace(for: FontFaceKey(family: "Absent", bold: false, italic: false)) == nil)
        let inherited = try XML.parse(Data("""
        <a:lstStyle><a:defPPr spcFirstLastPara="1"><a:spcBef><a:spcPct val="25000"/></a:spcBef>
        <a:spcAft><a:spcPct val="30000"/></a:spcAft><a:defRPr sz="2400" b="1" spc="75" u="sng" baseline="20000">
        <a:latin typeface="Absent"/><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill>
        </a:defRPr></a:defPPr></a:lstStyle>
        """.utf8))
        let fragments = [
            "<a:endParaRPr sz=\"\(size)\"/>",
            "<a:r><a:rPr sz=\"7200\"/><a:t/></a:r><a:endParaRPr sz=\"\(size)\"/>",
            "<a:br/><a:endParaRPr sz=\"\(size)\"/>",
            "<a:r><a:rPr sz=\"\(size)\"/><a:t>A B C</a:t></a:r>",
            "<a:fld type=\"slidenum\"><a:t/></a:fld><a:endParaRPr sz=\"\(size)\"/>",
            "<a:r><a:t>\tA\nB</a:t></a:r><a:endParaRPr sz=\"\(size)\"/>"
        ]
        for bullet in ["<a:buNone/>", "<a:buChar char=\"•\"/>", "<a:buAutoNum type=\"arabicPeriod\"/>"] {
            let content = fragments.map { "<a:p><a:pPr>\(bullet)</a:pPr>\($0)</a:p>" }.joined()
            let body = try XML.parse(Data("""
            <a:txBody><a:bodyPr anchor="ctr" spcFirstLastPara="1"><a:normAutofit fontScale="80000" lnSpcReduction="12500"/></a:bodyPr>
            <a:lstStyle><a:defPPr><a:defRPr sz="\(size)"/></a:defPPr></a:lstStyle>\(content)</a:txBody>
            """.utf8))
            let before = body.serialized(), inheritedBefore = inherited.serialized()
            func layout(_ fonts: FontLibrary?) -> RichTextLayout {
                RichTextLayout(textBody: body, width: 65, height: 250, fonts: fonts,
                    inheritedStyles: [inherited], defaultPointSize: 19, slideNumber: 7)
            }
            let fast = layout(nil), full = layout(unrelated)
            #expect(fast.lines == full.lines)
            #expect(fast.contentHeight == full.contentHeight)
            #expect(fast.fits == full.fits && fast.truncated == full.truncated)
            #expect(fast.diagnostics == full.diagnostics)
            #expect(body.serialized() == before && inherited.serialized() == inheritedBefore)

            let previousLines = fast.lines
            let ownDefaults = try #require(body.firstChild(named: "a:lstStyle")?.firstChild(named: "a:defPPr")?.firstChild(named: "a:defRPr"))
            ownDefaults[attribute: "sz"] = nil
            let inheritedDefaults = try #require(inherited.firstChild(named: "a:defPPr")?.firstChild(named: "a:defRPr"))
            inheritedDefaults[attribute: "sz"] = "1700"
            inheritedDefaults[attribute: "baseline"] = "-10000"
            let editedBody = body.serialized(), editedInherited = inherited.serialized()
            let editedFast = layout(nil), editedFull = layout(unrelated)
            #expect(editedFast.lines == editedFull.lines)
            #expect(editedFast.contentHeight == editedFull.contentHeight)
            #expect(editedFast.diagnostics == editedFull.diagnostics)
            #expect(fast.lines == previousLines)
            #expect(body.serialized() == editedBody && inherited.serialized() == editedInherited)
        }
    }
}
