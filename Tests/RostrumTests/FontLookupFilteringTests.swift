import Foundation
import Testing
@testable import Rostrum

@Suite struct FontLookupFilteringTests {
    private var directory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/Typography")
    }
    private func bytes() throws -> Data { try Data(contentsOf: directory.appendingPathComponent("LookupFlags.ttf")) }
    private func tables() throws -> [String: [UInt8]] {
        let r = SFNTReader(bytes: Array(try bytes()))
        var result: [String: [UInt8]] = [:]
        for i in 0..<(try r.u16(4)) {
            let p = 12 + 16 * i, offset = try r.u32(p + 8), count = try r.u32(p + 12)
            result[try r.tag(p)] = Array(r.bytes[offset..<(offset + count)])
        }
        return result
    }
    private func compare(_ cases: [TextShaperTests.OracleCase], _ shaper: TextShaper) {
        for oracle in cases {
            let run = shaper.shape(oracle.text, pointSize: Double(shaper.metrics.unitsPerEm), direction: .leftToRight)
            #expect(run.isSupported, "\(oracle.text): \(run.diagnostics)")
            #expect(run.glyphs.map(\.glyphID) == oracle.glyphs.map(\.g), "glyphs: \(oracle.text)")
            #expect(run.glyphs.map(\.scalarRange.lowerBound) == oracle.glyphs.map(\.cl), "clusters: \(oracle.text)")
            #expect(run.glyphs.map(\.advance) == oracle.glyphs.map { Double($0.ax) }, "advances: \(oracle.text)")
            #expect(run.glyphs.map(\.xOffset) == oracle.glyphs.map { Double($0.dx) }, "offsets: \(oracle.text)")
            #expect(run.glyphs.map(\.yOffset) == oracle.glyphs.map { Double($0.dy) }, "offsets: \(oracle.text)")
            #expect(run == shaper.shape(oracle.text, pointSize: Double(shaper.metrics.unitsPerEm), direction: .leftToRight))
        }
    }

    @Test func pinnedHarfBuzzLookupFilters() throws {
        let cases = try JSONDecoder().decode([TextShaperTests.OracleCase].self,
            from: Data(contentsOf: directory.appendingPathComponent("lookup-flags-harfbuzz-14.4.0.json")))
        compare(cases, TextShaper(try FontMetrics(data: bytes())))
    }

    /// Explicit opt-in local-font oracle: no host font is required by portable CI.
    @Test func suppliedLocalFontOracle() throws {
        guard let path = ProcessInfo.processInfo.environment["ROSTRUM_LOCAL_FONT_ORACLE"] else { return }
        struct Record: Decodable { let fontPath: String; let cases: [TextShaperTests.OracleCase] }
        let oracle = try JSONDecoder().decode(Record.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        compare(oracle.cases, TextShaper(try FontMetrics(contentsOf: URL(fileURLWithPath: oracle.fontPath))))
    }

    @Test func absentAndTruncatedGDEFNeverEnableFiltering() throws {
        var source = try tables()
        let valid = try #require(source["GDEF"])
        source.removeValue(forKey: "GDEF")
        let absent = FontLayoutTables(tables: source)
        #expect(absent.diagnostics.contains { $0.contains("require valid GDEF") })
        // RIGHT_TO_LEFT is irrelevant to these lookup types and still works.
        #expect(absent.ligatureLookups.count == 1)
        for cut in 0..<valid.count {
            source["GDEF"] = Array(valid.prefix(cut))
            let parsed = FontLayoutTables(tables: source)
            #expect(parsed.diagnostics.contains("Malformed or unsupported GDEF table"))
            #expect(parsed.ligatureLookups.count == 1)
        }
    }

    @Test func malformedOffsetsClassesAndMarkSetsAreDiagnosed() throws {
        let source = try tables(), original = try #require(source["GDEF"])
        let r = SFNTReader(bytes: original)
        let classes = try r.u16(4), marks = try r.u16(12)
        for (position, value) in [(0, 2), (2, 1), (4, 1), (4, 65535), (classes + 8, 5),
                                   (marks, 2), (marks + 4, 65535), (marks + 6, 0)] {
            var modified = source, data = original
            data.replaceSubrange(position..<(position + 2), with: TestFont.be16(value))
            modified["GDEF"] = data
            #expect(FontLayoutTables(tables: modified).diagnostics.contains("Malformed or unsupported GDEF table"), "offset \(position)")
        }
        var modified = source
        var gsub = try #require(source["GSUB"])
        let sr = SFNTReader(bytes: gsub), list = try sr.u16(8), lookup = list + (try sr.u16(list + 4))
        gsub.replaceSubrange((lookup + 8)..<(lookup + 10), with: TestFont.be16(65535))
        modified["GSUB"] = gsub
        #expect(FontLayoutTables(tables: modified).diagnostics.contains { $0.contains("require valid GDEF") })
        gsub.replaceSubrange((lookup + 2)..<(lookup + 4), with: TestFont.be16(0x20))
        modified["GSUB"] = gsub
        #expect(FontLayoutTables(tables: modified).diagnostics.contains("Unsupported lookup flags 32"))
    }

    @Test func classFormatOneAndSupportedGDEFVersions() throws {
        let source = try tables(), original = try #require(source["GDEF"])
        let reader = SFNTReader(bytes: original)
        let markClassOffset = try reader.u16(10), markSetOffset = try reader.u16(12)
        // Class format 1 covers all glyphs; glyphs outside the array are class 0.
        let glyphClasses = (0..<97).map { glyph in
            glyph == 63 || glyph == 95 ? 3 : (glyph == 64 || glyph == 96 ? 2 : 1)
        }
        let classBytes = TestFont.be16(1) + TestFont.be16(0) + TestFont.be16(97)
            + glyphClasses.flatMap(TestFont.be16)
        let u16 = TestFont.be16
        for minor in [0, 2, 3] {
            let size = minor == 0 ? 12 : (minor == 2 ? 14 : 18)
            var header = u16(1) + u16(minor) + u16(size) + u16(0) + u16(0) + u16(size + classBytes.count)
            if minor >= 2 { header += u16(size + classBytes.count + markSetOffset - markClassOffset) }
            if minor == 3 { header += TestFont.be32(0) }
            var modified = source
            modified["GDEF"] = header + classBytes + Array(original[markClassOffset...])
            let parsed = FontLayoutTables(tables: modified)
            #expect(!parsed.diagnostics.contains { $0.contains("Malformed") })
            #expect(parsed.isNonspacingMark(63))
            #expect(!parsed.isNonspacingMark(97))
            #expect(parsed.ligatureLookups.contains { $0.filter.flags == 8 })
            if minor >= 2 { #expect(parsed.diagnostics.isEmpty) }
        }
    }

    @Test func aliasedMarkSetCoveragesConsumeSharedBudget() {
        let u16 = TestFont.be16, u32 = TestFont.be32
        let count = 128
        var gdef = u16(1) + u16(2) + u16(14) + u16(0) + u16(0) + u16(0) + u16(18)
        gdef += u16(2) + u16(0) // Present empty class definition.
        gdef += u16(1) + u16(count)
        for _ in 0..<count { gdef += u32(4 + 4 * count) }
        gdef += u16(2) + u16(1) + u16(1) + u16(4096) + u16(0)
        let result = FontLayoutTables(tables: ["GDEF": gdef])
        #expect(result.diagnostics == ["GDEF layout expansion exceeds the parsing budget"])
        #expect(result.diagnostics == FontLayoutTables(tables: ["GDEF": gdef]).diagnostics)
    }

    @Test func filtersKeepIgnoredGlyphsAndDoNotCrossRemovedBreaks() throws {
        let shaper = TextShaper(try FontMetrics(data: bytes()))
        let run = shaper.shape("f^^i", pointSize: 1000)
        #expect(run.glyphs.map(\.glyphID) == [96, 63, 63])
        #expect(run.glyphs.map(\.scalarRange) == [0..<4, 0..<4, 0..<4])
        #expect(shaper.shape("f^\ni", pointSize: 1000).glyphs.count == 3)
        #expect(shaper.shape("A^\nV", pointSize: 1000).glyphs.map(\.advance) == [600, 0, 600])
        #expect(shaper.shape("A" + String(repeating: "^", count: 10000) + "V", pointSize: 1000).glyphs.first?.advance == 520)
    }
}
