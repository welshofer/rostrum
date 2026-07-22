import Foundation
import Testing
@testable import Rostrum

/// Builds tiny, valid-enough sfnt fonts in memory so the parser is tested
/// deterministically with no system-font dependency — the same fixture
/// philosophy as the hand-built DEFLATE streams and PNG bytes elsewhere in
/// the suite.
///
/// The standard test font: 1000 units/em, ascender 800, descender −200,
/// glyphs for ASCII 0x20…0x7E. Advances: space 250, 'i' 200, 'W' 900,
/// everything else 500; `.notdef` 600.
enum TestFont {
    static func be16(_ v: Int) -> [UInt8] { [UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }
    static func be32(_ v: Int) -> [UInt8] {
        [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    }

    static func advance(forChar c: Int) -> Int {
        switch c {
        case 0x20: return 250
        case 0x69: return 200  // 'i'
        case 0x57: return 900  // 'W'
        default: return 500
        }
    }

    /// Assemble an sfnt from tables: offset table + directory + 4-aligned
    /// table data. Offsets are absolute from the start of the returned bytes,
    /// so a collection header can be prepended via `prefixSize`.
    static func assemble(tables: [(tag: String, data: [UInt8])], prefixSize: Int = 0) -> [UInt8] {
        var directory: [UInt8] = be32(0x0001_0000) + be16(tables.count) + be16(0) + be16(0) + be16(0)
        var body: [UInt8] = []
        let tableStart = prefixSize + 12 + 16 * tables.count
        for (tag, data) in tables {
            let offset = tableStart + body.count
            directory += Array(tag.utf8) + be32(0) + be32(offset) + be32(data.count)
            body += data
            while body.count % 4 != 0 { body.append(0) }
        }
        return directory + body
    }

    static func head(upem: Int) -> [UInt8] {
        var t = be32(0x0001_0000) + be32(0) + be32(0) + be32(0x5F0F_3CF5)
        t += be16(0) + be16(upem)
        t += [UInt8](repeating: 0, count: 54 - t.count)
        return t
    }

    static func hhea(ascender: Int, descender: Int, lineGap: Int, numberOfHMetrics: Int) -> [UInt8] {
        var t = be32(0x0001_0000)
        t += be16(ascender & 0xFFFF) + be16(descender & 0xFFFF) + be16(lineGap & 0xFFFF)
        t += [UInt8](repeating: 0, count: 34 - t.count)
        t += be16(numberOfHMetrics)
        return t
    }

    static func maxp(numGlyphs: Int) -> [UInt8] {
        be32(0x0000_5000) + be16(numGlyphs)
    }

    static func hmtx(advances: [Int]) -> [UInt8] {
        advances.flatMap { be16($0) + be16(0) }
    }

    /// cmap with one format 4 subtable: 0x20…0x7E → glyphs 1…95 via idDelta.
    static func cmapFormat4() -> [UInt8] {
        var sub = be16(4) + be16(32) + be16(0)             // format, length, language
        sub += be16(4) + be16(4) + be16(1) + be16(0)       // segCountX2, search fields
        sub += be16(0x7E) + be16(0xFFFF)                   // endCode
        sub += be16(0)                                     // reservedPad
        sub += be16(0x20) + be16(0xFFFF)                   // startCode
        sub += be16((1 - 0x20) & 0xFFFF) + be16(1)         // idDelta
        sub += be16(0) + be16(0)                           // idRangeOffset
        return be16(0) + be16(1) + be16(3) + be16(1) + be32(12) + sub
    }

    /// cmap with one format 12 subtable mapping the same range.
    static func cmapFormat12() -> [UInt8] {
        var sub = be16(12) + be16(0) + be32(28) + be32(0) + be32(1)
        sub += be32(0x20) + be32(0x7E) + be32(1)
        return be16(0) + be16(1) + be16(3) + be16(10) + be32(12) + sub
    }

    /// cmap format 4 exercising the idRangeOffset path: 'A'…'C' → glyphs
    /// 5, 6, 7 through the trailing glyph-id array (idDelta 0).
    static func cmapFormat4RangeOffset() -> [UInt8] {
        var sub = be16(4) + be16(38) + be16(0)
        sub += be16(4) + be16(4) + be16(1) + be16(0)
        sub += be16(0x43) + be16(0xFFFF)                   // endCode
        sub += be16(0)
        sub += be16(0x41) + be16(0xFFFF)                   // startCode
        sub += be16(0) + be16(1)                           // idDelta
        // idRangeOffset[0] lives at subtable offset 28; the glyph-id array
        // starts at 32, so the self-relative offset is 4.
        sub += be16(4) + be16(0)                           // idRangeOffset
        sub += be16(5) + be16(6) + be16(7)                 // glyph ids for A, B, C
        return be16(0) + be16(1) + be16(3) + be16(1) + be32(12) + sub
    }

    /// OS/2 with typographic metrics 750 / −250 / 100 and, optionally, the
    /// USE_TYPO_METRICS selection bit.
    static func os2(useTypoMetrics: Bool) -> [UInt8] {
        var t = [UInt8](repeating: 0, count: 78)
        t.replaceSubrange(0..<2, with: be16(4))            // version
        t.replaceSubrange(62..<64, with: be16(useTypoMetrics ? 0x80 : 0x40))
        t.replaceSubrange(68..<70, with: be16(750))
        t.replaceSubrange(70..<72, with: be16((-250) & 0xFFFF))
        t.replaceSubrange(72..<74, with: be16(100))
        return t
    }

    /// A `name` table (format 0) with a single Windows/Unicode family-name
    /// record (nameID 1). BMP-only fixture strings.
    static func nameTable(family: String) -> [UInt8] {
        var utf16be: [UInt8] = []
        for scalar in family.unicodeScalars { utf16be += be16(Int(scalar.value)) }
        return be16(0) + be16(1) + be16(18)
            + be16(3) + be16(1) + be16(0x409) + be16(1) + be16(utf16be.count) + be16(0)
            + utf16be
    }

    /// The standard 96-glyph ASCII test font.
    static func standard(cmap: [UInt8] = cmapFormat4(), os2: [UInt8]? = nil,
                         familyName: String? = nil) -> Data {
        let advances = [600] + (0x20...0x7E).map(advance(forChar:))
        var tables: [(String, [UInt8])] = [
            ("head", head(upem: 1000)),
            ("hhea", hhea(ascender: 800, descender: -200, lineGap: 0, numberOfHMetrics: advances.count)),
            ("maxp", maxp(numGlyphs: advances.count)),
            ("hmtx", hmtx(advances: advances)),
            ("cmap", cmap),
        ]
        if let os2 { tables.append(("OS/2", os2)) }
        if let familyName { tables.append(("name", nameTable(family: familyName))) }
        return Data(assemble(tables: tables))
    }

    /// The standard font wrapped in a single-face TrueType collection.
    static func collection() -> Data {
        let advances = [600] + (0x20...0x7E).map(advance(forChar:))
        let prefix = Array("ttcf".utf8) + be32(0x0001_0000) + be32(1) + be32(16)
        let font = assemble(tables: [
            ("head", head(upem: 1000)),
            ("hhea", hhea(ascender: 800, descender: -200, lineGap: 0, numberOfHMetrics: advances.count)),
            ("maxp", maxp(numGlyphs: advances.count)),
            ("hmtx", hmtx(advances: advances)),
            ("cmap", cmapFormat4()),
        ], prefixSize: prefix.count)
        return Data(prefix + font)
    }
}

@Suite struct FontMetricsTests {
    @Test func parsesTheStandardFont() throws {
        let m = try FontMetrics(data: TestFont.standard())
        #expect(m.unitsPerEm == 1000)
        #expect(m.ascender == 800)
        #expect(m.descender == -200)
        #expect(m.advance(of: "W") == 900)
        #expect(m.advance(of: "i") == 200)
        #expect(m.advance(of: " ") == 250)
        #expect(m.advance(of: "x") == 500)
    }

    @Test func widthSumsAdvances() throws {
        let m = try FontMetrics(data: TestFont.standard())
        #expect(m.width(of: "Wi", pointSize: 10) == 11.0)
        #expect(m.width(of: "a b", pointSize: 10) == 12.5)
        #expect(m.width(of: "", pointSize: 10) == 0)
    }

    @Test func lineMetricsComeFromHheaByDefault() throws {
        let m = try FontMetrics(data: TestFont.standard())
        #expect(m.lineHeight(pointSize: 10) == 10.0)     // (800 + 200 + 0) / 1000 × 10
        #expect(m.ascent(pointSize: 10) == 8.0)
        #expect(m.descent(pointSize: 10) == 2.0)
    }

    @Test func os2TypoMetricsApplyOnlyWhenSelected() throws {
        let selected = try FontMetrics(data: TestFont.standard(os2: TestFont.os2(useTypoMetrics: true)))
        #expect(selected.lineHeight(pointSize: 10) == 11.0)  // (750 + 250 + 100) / 1000 × 10
        let unselected = try FontMetrics(data: TestFont.standard(os2: TestFont.os2(useTypoMetrics: false)))
        #expect(unselected.lineHeight(pointSize: 10) == 10.0)
    }

    @Test func format12MatchesFormat4() throws {
        let f4 = try FontMetrics(data: TestFont.standard())
        let f12 = try FontMetrics(data: TestFont.standard(cmap: TestFont.cmapFormat12()))
        for text in ["Wide", "i i i", "~"] {
            #expect(f4.width(of: text, pointSize: 12) == f12.width(of: text, pointSize: 12))
        }
    }

    @Test func format4RangeOffsetPathResolvesGlyphIds() throws {
        let advances = [600, 500, 500, 500, 500, 111, 222, 333]
        let font = Data(TestFont.assemble(tables: [
            ("head", TestFont.head(upem: 1000)),
            ("hhea", TestFont.hhea(ascender: 800, descender: -200, lineGap: 0,
                                   numberOfHMetrics: advances.count)),
            ("maxp", TestFont.maxp(numGlyphs: advances.count)),
            ("hmtx", TestFont.hmtx(advances: advances)),
            ("cmap", TestFont.cmapFormat4RangeOffset()),
        ]))
        let m = try FontMetrics(data: font)
        #expect(m.advance(of: "A") == 111)
        #expect(m.advance(of: "B") == 222)
        #expect(m.advance(of: "C") == 333)
        #expect(m.advance(of: "D") == 600)  // unmapped → .notdef
    }

    @Test func unmappedCharactersMeasureAsNotdef() throws {
        let m = try FontMetrics(data: TestFont.standard())
        #expect(m.advance(of: "é") == 600)
        #expect(m.advance(of: Unicode.Scalar(0x1F600)!) == 600)
    }

    @Test func collectionsParseByIndex() throws {
        let m = try FontMetrics(data: TestFont.collection(), fontIndex: 0)
        #expect(m.unitsPerEm == 1000)
        #expect(m.advance(of: "W") == 900)
        #expect(throws: RostrumError.self) {
            try FontMetrics(data: TestFont.collection(), fontIndex: 3)
        }
    }

    @Test func malformedFontsThrowInsteadOfTrapping() {
        #expect(throws: RostrumError.self) { try FontMetrics(data: Data()) }
        #expect(throws: RostrumError.self) { try FontMetrics(data: Data([0xDE, 0xAD, 0xBE, 0xEF])) }
        // Truncations at every prefix of a valid font must throw, never crash.
        let good = TestFont.standard()
        for cut in stride(from: 0, to: good.count, by: 7) {
            #expect(throws: RostrumError.self) { try FontMetrics(data: good.prefix(cut)) }
        }
    }
}

@Suite struct TextMeasurerTests {
    private func measurer() throws -> TextMeasurer {
        TextMeasurer(try FontMetrics(data: TestFont.standard()))
    }

    @Test func greedyWordWrap() throws {
        let t = try measurer()
        // At 10pt: 'a' is 5pt, space 2.5pt. "aaaa bb" = 20 + 2.5 + 10 = 32.5.
        #expect(t.wrap("aaaa bb", pointSize: 10, width: 25) == ["aaaa", "bb"])
        #expect(t.wrap("aaaa bb", pointSize: 10, width: 33) == ["aaaa bb"])
        #expect(t.wrap("", pointSize: 10, width: 25) == [""])
        #expect(t.wrap("one\n\ntwo", pointSize: 10, width: 100) == ["one", "", "two"])
    }

    @Test func oversizedWordsBreakMidWord() throws {
        let t = try measurer()
        // Ten 'a's = 50pt; a 12pt box holds two per line.
        #expect(t.wrap("aaaaaaaaaa", pointSize: 10, width: 12)
                == ["aa", "aa", "aa", "aa", "aa"])
        // Even a box narrower than one character makes progress.
        #expect(t.wrap("aa", pointSize: 10, width: 1) == ["a", "a"])
    }

    @Test func heightIsLineCountTimesLineHeight() throws {
        let t = try measurer()
        #expect(t.height(of: "aaaa bb", pointSize: 10, width: 25) == 20.0)
        #expect(t.height(of: "aaaa bb", pointSize: 10, width: 25, lineSpacing: 1.5) == 30.0)
    }

    @Test func autofitStopsAtTheFirstFittingStep() throws {
        let t = try measurer()
        let fitsAt100 = t.autofit(paragraphs: [("aaaa", 10)], width: 25, height: 10)
        #expect(fitsAt100 == Autofit(fontScale: 100, lineSpacingReduction: 0, fits: true))

        let oneStep = t.autofit(paragraphs: [("aaaa", 10)], width: 25, height: 9.5)
        #expect(oneStep == Autofit(fontScale: 92.5, lineSpacingReduction: 0, fits: true))
    }

    @Test func autofitReportsTheFloorWhenNothingFits() throws {
        let t = try measurer()
        let wall = String(repeating: "a ", count: 400)
        let floor = t.autofit(paragraphs: [(wall, 18)], width: 20, height: 10)
        #expect(floor.fontScale == 25)
        #expect(floor.lineSpacingReduction == 20)
        #expect(!floor.fits)
    }

    @Test func fitTextWritesComputedNormAutofit() throws {
        let deck = try Presentation()
        let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(2), height: .inches(0.5))
        let box = try deck.slides[0].shapes.addTextBox(frame)
        let text = box.textFrame!
        text.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        text.text = "A sentence long enough that eighteen point text overflows half an inch"
        text.paragraphs[0].runs[0].fontSize = 18

        let result = box.fitText(using: try FontMetrics(data: TestFont.standard()))!
        #expect(result.fontScale < 100)

        let bodyPr = try #require(text.txBody.firstChild(named: "a:bodyPr"))
        let normAutofit = try #require(bodyPr.firstChild(named: "a:normAutofit"))
        #expect(normAutofit[attribute: "fontScale"]
                == String(Int((result.fontScale * 1000).rounded())))

        // The computed autofit round-trips and the deck stays valid.
        let reopened = try Presentation(data: try deck.serializedData())
        let reopenedBodyPr = try reopened.slides[0].shapes[0].textFrame!.txBody
            .firstChild(named: "a:bodyPr")
        #expect(reopenedBodyPr?.firstChild(named: "a:normAutofit")?[attribute: "fontScale"]
                == normAutofit[attribute: "fontScale"])
        #expect(try deck.validate().isEmpty)
    }

    @Test func fitTextAt100PercentLeavesABareNormAutofit() throws {
        let deck = try Presentation()
        let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(2))
        let box = try deck.slides[0].shapes.addTextBox(frame)
        box.textFrame!.text = "Fits"
        let result = box.fitText(using: try FontMetrics(data: TestFont.standard()))!
        #expect(result == Autofit(fontScale: 100, lineSpacingReduction: 0, fits: true))
        let normAutofit = box.textFrame!.txBody.firstChild(named: "a:bodyPr")?
            .firstChild(named: "a:normAutofit")
        #expect(normAutofit != nil)
        #expect(normAutofit?[attribute: "fontScale"] == nil)
        #expect(normAutofit?[attribute: "lnSpcReduction"] == nil)
    }
}

/// A real font from the host, when one exists (CI installs DejaVu on Linux;
/// macOS ships Arial/Helvetica). Pure sanity oracle — the deterministic
/// coverage lives above with the synthetic fonts.
private let realFontURL: URL? = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
].map { URL(fileURLWithPath: $0) }.first { FileManager.default.fileExists(atPath: $0.path) }

@Suite struct RealFontOracleTests {
    @Test(.enabled(if: realFontURL != nil))
    func realFontsParseAndMeasureSanely() throws {
        let m = try FontMetrics(contentsOf: realFontURL!)
        #expect((16...16384).contains(m.unitsPerEm))
        #expect(m.width(of: "WWW", pointSize: 12) > m.width(of: "iii", pointSize: 12))
        let lineHeight = m.lineHeight(pointSize: 12)
        #expect(lineHeight > 8 && lineHeight < 24)
        let wrapped = TextMeasurer(m).wrap(
            "The quick brown fox jumps over the lazy dog", pointSize: 12, width: 100)
        #expect(wrapped.count >= 2)
    }
}
