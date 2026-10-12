import Foundation
import Testing
@testable import Rostrum

@Suite struct PreparedRichTextTests {
    private func fonts() throws -> FontLibrary {
        let library = FontLibrary()
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/NativeGlyphPlacement/eligibility/fonts")
        for name in ["DejaVuSans", "DejaVuSans-Bold", "DejaVuSans-Oblique", "DejaVuSerif"] {
            try library.register(contentsOf: root.appendingPathComponent(name + ".ttf"))
        }
        return library
    }

    private func bits(_ layout: RichTextLayout) -> [UInt64] {
        var values = [layout.contentHeight]
        for line in layout.lines {
            values += [line.baseline, line.height, line.width, line.visibleWidth]
            for span in line.spans {
                values += [span.x, span.width, span.run.fontSize, span.run.tracking,
                           span.run.baselineShift, span.run.kerningThreshold]
                values += span.scalarPositions ?? []
            }
        }
        return values.map(\.bitPattern)
    }

    private func equal(_ actual: RichTextLayout, _ expected: RichTextLayout) {
        #expect(actual.lines == expected.lines)
        #expect(actual.lines.flatMap(\.spans).map { Array($0.run.text.utf8) }
            == expected.lines.flatMap(\.spans).map { Array($0.run.text.utf8) })
        #expect(bits(actual) == bits(expected))
        #expect(actual.fits == expected.fits)
        #expect(actual.truncated == expected.truncated)
        #expect(actual.diagnostics == expected.diagnostics)
    }

    @Test(arguments: ["mixed", "tabs", "breaks", "scripts", "empty", "invalid"])
    func reusePreservesGeometryAtEveryScaleAndWidth(sample: String) throws {
        let contents = [
            "mixed": """
            <a:p><a:pPr><a:lnSpc><a:spcPts val="3300"/></a:lnSpc><a:buNone/></a:pPr><a:r><a:rPr sz="2423" spc="125" kern="2200" cap="all"/><a:t>AVATAR ToT </a:t></a:r><a:r><a:rPr sz="4800" b="1" u="sng"/><a:t>Large</a:t></a:r><a:r><a:rPr sz="2200" i="1"><a:latin typeface="DejaVu Sans"/></a:rPr><a:t> italic</a:t></a:r></a:p>
            """,
            "tabs": """
            <a:p><a:pPr><a:tabLst><a:tab pos="1270000" algn="dec"/></a:tabLst><a:buAutoNum type="arabicPeriod"/></a:pPr><a:r><a:t>Alpha\t12.75\nBeta\t3.0</a:t></a:r></a:p><a:p><a:pPr lvl="1"><a:buSzPct val="75000"/><a:buChar char="•"/></a:pPr><a:r><a:t>Nested words wrap here</a:t></a:r></a:p>
            """,
            "breaks": """
            <a:p><a:r><a:t>Start</a:t></a:r><a:br><a:rPr sz="3200"/></a:br><a:fld type="slidenum"><a:rPr sz="2200"/><a:t>1</a:t></a:fld><a:r><a:rPr baseline="25000"/><a:t> note</a:t></a:r><a:br/><a:endParaRPr sz="2900" i="1"/></a:p>
            """,
            "scripts": """
            <a:p><a:r><a:t>office é café 中文 אבד 123 مرحبا</a:t></a:r></a:p><a:p><a:r><a:rPr><a:latin typeface="Unregistered face"/></a:rPr><a:t>Missing 🙂</a:t></a:r></a:p>
            """,
            "empty": """
            <a:p><a:endParaRPr sz="3800" b="1"/></a:p><a:p><a:r><a:t>\n</a:t></a:r><a:endParaRPr sz="2100" i="1"/></a:p>
            """,
            "invalid": """
            <a:p><a:pPr marL="NaN" indent="-10000"><a:lnSpc><a:spcPct val="110000"/></a:lnSpc></a:pPr><a:r><a:rPr sz="NaN" spc="inf" kern="0"/><a:t>Bounded malformed attributes</a:t></a:r></a:p>
            """
        ]
        let inherited = try XML.parse(Data("""
        <a:lstStyle><a:defPPr marR="10000"><a:spcBef><a:spcPts val="1000"/></a:spcBef><a:spcAft><a:spcPts val="800"/></a:spcAft><a:defRPr sz="2400"><a:solidFill><a:schemeClr val="accent1"/></a:solidFill><a:latin typeface="+mn-lt"/></a:defRPr></a:defPPr><a:lvl2pPr marL="200000" indent="-100000"><a:defRPr sz="1800"/></a:lvl2pPr></a:lstStyle>
        """.utf8))
        let theme = try Presentation().theme
        theme.minorFont = "DejaVu Sans"
        let registered = try fonts()
        for library: FontLibrary? in [nil, registered] {
            let body = try XML.parse(Data("""
            <p:txBody><a:bodyPr lIns="10000" rIns="20000" tIns="15000" bIns="5000" anchor="ctr"><a:normAutofit/></a:bodyPr><a:lstStyle/>\(try #require(contents[sample]))</p:txBody>
            """.utf8))
            let fit = try #require(body.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit"))
            let before = body.children(named: "a:p").map(XML.document)
            let stylesBefore = XML.document(inherited)
            let preparation = RichTextLayout.Preparation()
            for scale in [100000, 99990, 88300, 75000, 60000, 900, 100] {
                fit[attribute: "fontScale"] = String(scale)
                fit[attribute: "lnSpcReduction"] = scale == 88300 ? "10000" : "0"
                for width in [42.0, 141.25] {
                    for context in [RichTextLayout.Context.shape, .tableCell] {
                        for limit in [2, 64] {
                            let expected = RichTextLayout(textBody: body, width: width, height: 65.75,
                                fonts: library, theme: theme, inheritedStyles: [inherited], slideNumber: 42,
                                maxLines: limit, context: context)
                            let actual = RichTextLayout(textBody: body, width: width, height: 65.75,
                                fonts: library, theme: theme, inheritedStyles: [inherited], slideNumber: 42,
                                maxLines: limit, context: context, preparation: preparation)
                            equal(actual, expected)
                        }
                    }
                }
            }
            #expect(body.children(named: "a:p").map(XML.document) == before)
            #expect(XML.document(inherited) == stylesBefore)
        }
    }

    @Test func sharedXMLRunUsesItsOwnParagraphInheritance() throws {
        let body = try XML.parse(Data("""
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="2400"/></a:pPr><a:r><a:t>Shared node</a:t></a:r></a:p><a:p><a:pPr><a:defRPr sz="3600" b="1"/></a:pPr></a:p></p:txBody>
        """.utf8))
        let paragraphs = body.children(named: "a:p")
        paragraphs[1].appendElement(try #require(paragraphs[0].firstChild(named: "a:r")))
        let preparation = RichTextLayout.Preparation()
        for scale in [100.0, 70, 90] {
            let expected = RichTextLayout(textBody: body, width: 250, height: 100, fontScale: scale)
            let actual = RichTextLayout(textBody: body, width: 250, height: 100, fontScale: scale, preparation: preparation)
            equal(actual, expected)
        }
    }

    @Test func canonicallyEquivalentSegmentsKeepTheirOriginalScalarOffsets() throws {
        let body = try XML.parse(Data("""
        <p:txBody><a:bodyPr/><a:lstStyle><a:defPPr><a:defRPr><a:latin typeface="DejaVu Sans"/></a:defRPr></a:defPPr></a:lstStyle><a:p><a:r><a:t>é x</a:t></a:r><a:r><a:t>é x</a:t></a:r></a:p><a:p><a:r><a:t>é x</a:t></a:r><a:r><a:t>é x</a:t></a:r></a:p></p:txBody>
        """.utf8))
        let preparation = RichTextLayout.Preparation(), library = try fonts()
        let shaper = TextShaper(try #require(library.metrics(for: "DejaVu Sans")))
        for text in ["é x", "é x"] {
            let segment = try #require(preparation.segment(text))
            #expect(shaper.shape(segment.input, pointSize: 18, kerning: true, standardLigatures: true)
                == shaper.shape(text, pointSize: 18))
        }
        for scale in [80.0, 75] {
            let expected = RichTextLayout(textBody: body, width: 120, height: 100, fonts: library, fontScale: scale)
            let actual = RichTextLayout(textBody: body, width: 120, height: 100, fonts: library, fontScale: scale, preparation: preparation)
            equal(actual, expected)
        }
    }

    @Test func exceedingScratchBudgetsKeepsTheUncachedResult() throws {
        let body = try XML.parse(Data("""
        <p:txBody><a:bodyPr/><a:lstStyle><a:defPPr><a:defRPr><a:latin typeface="DejaVu Sans"/></a:defRPr></a:defPPr></a:lstStyle></p:txBody>
        """.utf8))
        let paragraph = XML.Element("a:p")
        for index in 0..<520 {
            paragraph.appendElement(XML.Element("a:r", children: [.element(XML.Element("a:t", children: [
                .text("\(index) " + String(repeating: "Word ", count: 26))]))]))
        }
        body.appendElement(paragraph)
        let preparation = RichTextLayout.Preparation(), library = try fonts()
        for scale in [80.0, 75] {
            let expected = RichTextLayout(textBody: body, width: 180, height: 100, fonts: library, fontScale: scale, maxLines: 2)
            let actual = RichTextLayout(textBody: body, width: 180, height: 100, fonts: library, fontScale: scale, maxLines: 2, preparation: preparation)
            equal(actual, expected)
        }
    }

    @Test(arguments: ["AVATAR office", "é café", "A אב 123", "中文\r\nWords", "x\u{200B}y\u{202E}z"])
    func preparedShapingPreservesSizesFeaturesAndDirections(text: String) throws {
        let shaper = TextShaper(try #require(fonts().metrics(for: "DejaVu Sans")))
        for direction in [TextDirection.automatic, .leftToRight, .rightToLeft] {
            let prepared = TextShaper.PreparedText(text, direction: direction)
            for size in [0.0, 0.9, 10.3, 24, 99.9, .infinity] {
                for kerning in [false, true] {
                    for ligatures in [false, true] {
                        let expected = shaper.shape(text, pointSize: size, direction: direction, kerning: kerning, standardLigatures: ligatures)
                        let actual = shaper.shape(prepared, pointSize: size, kerning: kerning, standardLigatures: ligatures)
                        #expect(actual == expected)
                    }
                }
            }
        }
    }

    // Run in Release too: lazy reversal of a slice of the destination array
    // previously duplicated glyphs after extracting preparation from shaping.
    @Test func bidirectionalReorderingPreservesEverySourceCluster() throws {
        let shaper = TextShaper(try #require(fonts().metrics(for: "DejaVu Sans")))
        for size in [0.0, 24] {
            let latin = shaper.shape("ABC DEF", pointSize: size, direction: .rightToLeft)
            #expect(latin.glyphs.map(\.scalarRange.lowerBound) == Array(0..<7))
            let mixed = shaper.shape("A אב 123", pointSize: size)
            #expect(mixed.glyphs.map(\.scalarRange.lowerBound) == [0, 1, 5, 6, 7, 4, 3, 2])
            let rtl = shaper.shape("A אב 123", pointSize: size, direction: .rightToLeft)
            #expect(rtl.glyphs.map(\.scalarRange.lowerBound) == [5, 6, 7, 4, 3, 2, 1, 0])
        }
    }
}
