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

    @Test func fragmentsRetainSourceFacesAcrossEmptyRunsTabsAndFreshRegistration() throws {
        let library = FontLibrary()
        try library.register(FontFaceTests.font(400, bold: false, italic: false), aliases: ["Alias"])
        try library.register(FontFaceTests.font(700, bold: true, italic: false), aliases: ["Alias"])
        let body = try XML.parse(Data("""
        <p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0"/>
        <a:p><a:pPr><a:tabLst><a:tab pos="508000"/></a:tabLst>
        <a:defRPr sz="1000"><a:latin typeface="Alias"/></a:defRPr></a:pPr>
        <a:r><a:rPr b="1"/><a:t/></a:r><a:r><a:t>AB </a:t></a:r>
        <a:r><a:t/></a:r><a:r><a:rPr b="1"/><a:t>CD\tEF\nG</a:t></a:r></a:p></p:txBody>
        """.utf8))
        for boldAdvance in [7.0, 6.0] {
            if boldAdvance == 6 {
                try library.register(FontFaceTests.font(600, bold: true, italic: false), aliases: ["Alias"])
            }
            for width in [100.0, 35] {
                let expected = RichTextLayout(textBody: body, width: width, height: 100, fonts: library)
                let prepared = RichTextLayout.Preparation(fragments: .init())
                for trialWidth in [100.0, width, width] {
                    let actual = RichTextLayout(textBody: body, width: trialWidth, height: 100,
                        fonts: library, preparation: prepared)
                    if trialWidth == width { equal(actual, expected) }
                    if trialWidth == 100 {
                        let first = try #require(actual.lines.first)
                        #expect(first.spans.map(\.run.text) == ["AB ", "CD", "EF"])
                        #expect(first.spans.map(\.x) == [0, 12, 40])
                        #expect(first.spans.map(\.width) == [12, 2 * boldAdvance, 2 * boldAdvance])
                        #expect(first.spans.map(\.run.bold) == [false, true, true])
                        #expect(first.spans.map(\.followsPreviousRun) == [false, true, false])
                        #expect(actual.lines.last?.spans.first?.width == boldAdvance)
                    }
                }
            }
        }
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
            let preparation = RichTextLayout.Preparation(fragments: .init())
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
        let preparation = RichTextLayout.Preparation(fragments: .init()), library = try fonts()
        for scale in [80.0, 75] {
            let expected = RichTextLayout(textBody: body, width: 180, height: 100, fonts: library, fontScale: scale, maxLines: 2)
            let actual = RichTextLayout(textBody: body, width: 180, height: 100, fonts: library, fontScale: scale, maxLines: 2, preparation: preparation)
            equal(actual, expected)
        }
    }

    @Test func sharedFragmentAdvancesPreserveFacesFeaturesAndLineBoundaries() throws {
        let library = try fonts(), fragments = RichTextLayout.FragmentMeasurements()
        for family in ["DejaVu Sans", "DejaVu Serif"] {
            for properties in ["kern=\"0\"", "kern=\"100\"", "b=\"1\"", "i=\"1\"", "spc=\"125\""] {
                for rtl in ["0", "1"] {
                    let body = try XML.parse(Data("""
                    <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:pPr rtl="\(rtl)" algn="just"><a:defRPr sz="2423" \(properties)><a:latin typeface="\(family)"/></a:defRPr></a:pPr><a:r><a:t>AVATAR office ToT AVATAR\t12.34\nRepeated words wrap again.</a:t></a:r></a:p><a:p><a:r><a:rPr sz="2423" \(properties)><a:latin typeface="\(family)"/></a:rPr><a:t>é é אבד مرحبا 日本語</a:t></a:r></a:p></p:txBody>
                    """.utf8))
                    let prepared = RichTextLayout.Preparation(fragments: fragments)
                    for scale in [100.0, 83.3, 100] {
                        for width in [75.0, 160.25, 310, 75] {
                            let expected = RichTextLayout(textBody: body, width: width, height: 300,
                                fonts: library, fontScale: scale)
                            let actual = RichTextLayout(textBody: body, width: width, height: 300,
                                fonts: library, fontScale: scale, preparation: prepared)
                            equal(actual, expected)
                        }
                    }
                }
            }
        }
        #expect(fragments.count > 0 && fragments.count <= 2048)
    }

    @Test func fragmentAdmissionIsBoundedAndSourceBytesStayDistinct() throws {
        let fragments = RichTextLayout.FragmentMeasurements()
        let style = ResolvedTextRun(text: "", fontFamily: nil, fontSize: 18, bold: false,
            italic: false, color: "000000", tracking: 0)
        #expect(fragments.advance("é", style: style, nativeLTR: false) { 1 } == 1)
        #expect(fragments.advance("e\u{301}", style: style, nativeLTR: false) { 2 } == 2)
        #expect(fragments.advance("é", style: style, nativeLTR: false) { Issue.record("Expected reuse"); return 3 } == 1)
        for index in 0..<2050 {
            _ = fragments.advance("\(index)", style: style, nativeLTR: true) { Double(index) }
        }
        #expect(fragments.count == 2048)
        #expect(fragments.advance("2049", style: style, nativeLTR: true) { 99 } == 99)
        #expect(fragments.advance("é", style: style, nativeLTR: false) { 3 } == 1)

        let byteBounded = RichTextLayout.FragmentMeasurements()
        let large = String(repeating: "x", count: 262_145)
        #expect(byteBounded.advance(large, style: style, nativeLTR: true) { 7 } == 7)
        #expect(byteBounded.count == 0 && byteBounded.retainedBytes == 0)
        let chunk = String(repeating: "y", count: 65536)
        for index in 0..<5 {
            _ = byteBounded.advance(chunk + String(index), style: style, nativeLTR: true) { 7 }
        }
        #expect(byteBounded.count == 3 && byteBounded.retainedBytes == 196611)

        // A saturated operation must still lay out every new fragment normally.
        let body = try XML.parse(Data("""
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr><a:latin typeface="DejaVu Sans"/></a:rPr><a:t>New words beyond the cache still wrap correctly.</a:t></a:r></a:p></p:txBody>
        """.utf8))
        let library = try fonts(), prepared = RichTextLayout.Preparation(fragments: fragments)
        for width in [55.0, 180] {
            equal(RichTextLayout(textBody: body, width: width, height: 200, fonts: library, preparation: prepared),
                  RichTextLayout(textBody: body, width: width, height: 200, fonts: library))
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
