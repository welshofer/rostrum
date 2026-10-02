import Foundation
import Testing
@testable import Rostrum

@Suite struct MarkPositioningTests {
    private var directory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/Typography")
    }
    struct Record: Decodable { let fontSHA256: String; let cases: [TextShaperTests.OracleCase] }
    struct Oracle: Decodable { let fonts: [String: Record] }
    private func compare(_ font: URL, _ cases: [TextShaperTests.OracleCase]) throws {
        let shaper = TextShaper(try FontMetrics(contentsOf: font))
        for oracle in cases {
            let direction: TextDirection = oracle.direction == "rtl" ? .rightToLeft : .leftToRight
            let size = Double(shaper.metrics.unitsPerEm)
            let run = shaper.shape(oracle.text, pointSize: size, direction: direction)
            #expect(run.isSupported == oracle.supported, "\(font.lastPathComponent) \(oracle.text): \(run.diagnostics)")
            if oracle.supported {
                #expect(run.glyphs.map(\.glyphID) == oracle.glyphs.map(\.g), "glyphs: \(oracle.text)")
                #expect(run.glyphs.map(\.scalarRange.lowerBound) == oracle.glyphs.map(\.cl), "clusters: \(oracle.text)")
                #expect(run.glyphs.map(\.advance) == oracle.glyphs.map { Double($0.ax) }, "advances: \(oracle.text)")
                #expect(run.glyphs.map(\.xOffset) == oracle.glyphs.map { Double($0.dx) }, "x: \(oracle.text)")
                #expect(run.glyphs.map(\.yOffset) == oracle.glyphs.map { Double($0.dy) }, "y: \(oracle.text)")
                let scaled = shaper.shape(oracle.text, pointSize: size / 2, direction: direction)
                #expect(scaled.glyphs.map { $0.xOffset * 2 } == run.glyphs.map(\.xOffset))
                #expect(scaled.glyphs.map { $0.yOffset * 2 } == run.glyphs.map(\.yOffset))
                #expect(scaled.width * 2 == run.width)
            }
            #expect(run == shaper.shape(oracle.text, pointSize: size, direction: direction))
        }
    }
    @Test func pinnedIndependentBaseMarkAndRTLGeometry() throws {
        let oracle = try JSONDecoder().decode(Oracle.self, from: Data(contentsOf: directory.appendingPathComponent("marks-harfbuzz-14.4.0.json")))
        for name in oracle.fonts.keys.sorted() { try compare(directory.appendingPathComponent(name), oracle.fonts[name]!.cases) }
    }
    @Test func suppliedLocalMarkOracle() throws {
        guard let path = ProcessInfo.processInfo.environment["ROSTRUM_MARK_ORACLE"] else { return }
        struct Local: Decodable { let fontPath: String; let cases: [TextShaperTests.OracleCase] }
        let oracle = try JSONDecoder().decode(Local.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        try compare(URL(fileURLWithPath: oracle.fontPath), oracle.cases)
    }
    private func tables(_ name: String = "MarkAttachments.ttf") throws -> [String: [UInt8]] {
        let r = SFNTReader(bytes: Array(try Data(contentsOf: directory.appendingPathComponent(name))))
        var tables: [String: [UInt8]] = [:]
        for i in 0..<(try r.u16(4)) {
            let p = 12 + 16 * i, offset = try r.u32(p + 8), count = try r.u32(p + 12)
            tables[try r.tag(p)] = Array(r.bytes[offset..<(offset + count)])
        }
        return tables
    }
    private func shaper(_ tables: [String: [UInt8]]) throws -> TextShaper {
        TextShaper(try FontMetrics(data: Data(TestFont.assemble(tables: tables.keys.sorted().map { ($0, tables[$0]!) }))))
    }
    @Test func activeLatinCompositionRetainsDiagnosticAndUnrelatedMarksRemainSupported() throws {
        let source = try tables("MarkComposition.ttf"), shaper = try shaper(source)
        let run = shaper.shape("x́", pointSize: 1000)
        #expect(run.diagnostics.contains(.unsupportedLayoutFeature("Latin ccmp changes this residual combining sequence; composition shaping is unsupported")))
        // The diagnostic probe never changes production glyphs or clusters.
        #expect(run.glyphs.map(\.glyphID) == [7, 8])
        #expect(run.glyphs.map(\.scalarRange) == [0..<2, 0..<2])
        let oracle = try JSONDecoder().decode(Oracle.self, from: Data(contentsOf: directory.appendingPathComponent("marks-harfbuzz-14.4.0.json")))
        let reference = try #require(oracle.fonts["MarkComposition.ttf"]?.cases.first { $0.text == "x́" })
        #expect(run.glyphs.map(\.glyphID) != reference.glyphs.map(\.g))
        #expect(reference.glyphs.count == 1)
        #expect(shaper.shape("q́", pointSize: 1000).isSupported)
        #expect(shaper.shape("x̀", pointSize: 1000).isSupported)
        #expect(!shaper.shape("x\ń", pointSize: 1000).diagnostics.contains(.unsupportedLayoutFeature("Latin ccmp changes this residual combining sequence; composition shaping is unsupported")))

        var copy = source, bytes = try #require(source["GSUB"])
        let r = SFNTReader(bytes: bytes), features = try r.u16(6), list = try r.u16(8)
        // Find the ccmp feature rather than depending on fixture lookup order.
        let featureRecord = try #require((0..<(try r.u16(features))).first { try r.tag(features + 2 + 6 * $0) == "ccmp" })
        let feature = features + (try r.u16(features + 6 + 6 * featureRecord))
        let index = try r.u16(feature + 4), lookup = list + (try r.u16(list + 2 + 2 * index))
        bytes.replaceSubrange(lookup..<(lookup + 2), with: TestFont.be16(2))
        copy["GSUB"] = bytes
        let unsupported = try self.shaper(copy).shape("x́", pointSize: 1000)
        #expect(unsupported.diagnostics.contains(.unsupportedLayoutFeature("Unsupported Latin ccmp GSUB lookup 2")))
        #expect(!unsupported.isSupported)
    }
    @Test func truncationInvalidClassesNullAnchorsAndMissingGDEFRefuse() throws {
        let source = try tables(), original = try #require(source["GPOS"])
        for cut in 0..<original.count {
            let parsed = FontLayoutTables(tables: ["GPOS": Array(original.prefix(cut)), "GDEF": source["GDEF"]!])
            #expect(!parsed.diagnostics.isEmpty || !parsed.markDiagnostics.isEmpty, "cut \(cut)")
            #expect(parsed.markLookups.isEmpty, "cut \(cut)")
        }
        let r = SFNTReader(bytes: original), list = try r.u16(8)
        let lookup = list + (try r.u16(list + 2)) // Base extension lookup.
        let extensionTable = lookup + (try r.u16(lookup + 6))
        let sub = extensionTable + (try r.u32(extensionTable + 4))
        let array = sub + (try r.u16(sub + 8))
        for (field, value) in [(sub + 6, 65535), (sub + 8, 65535), (array + 2, 65535), (array + 4, 0)] {
            var tables = source, modified = original
            modified.replaceSubrange(field..<(field + 2), with: TestFont.be16(value)); tables["GPOS"] = modified
            let run = try shaper(tables).shape("x́", pointSize: 1000)
            #expect(!run.isSupported)
            #expect(run == (try shaper(tables).shape("x́", pointSize: 1000)))
        }
        var missing = source; missing.removeValue(forKey: "GDEF")
        #expect(try !shaper(missing).shape("x́", pointSize: 1000).isSupported)
    }
    @Test func unsupportedDeviceAndVariationAnchorsNeverEnableAttachment() throws {
        let source = try tables(), original = try #require(source["GPOS"])
        let r = SFNTReader(bytes: original), list = try r.u16(8)
        let lookup = list + (try r.u16(list + 2)), ext = lookup + (try r.u16(lookup + 6))
        let sub = ext + (try r.u32(ext + 4)), array = sub + (try r.u16(sub + 8))
        let anchor = array + (try r.u16(array + 4))
        var copy = source, modified = original
        modified.replaceSubrange(anchor..<(anchor + 2), with: TestFont.be16(3))
        modified.replaceSubrange((anchor + 6)..<(anchor + 8), with: TestFont.be16(1))
        copy["GPOS"] = modified
        let run = try shaper(copy).shape("x́", pointSize: 1000)
        #expect(run.diagnostics.contains(.unsupportedLayoutFeature("GPOS mark device or variation anchors are unsupported")))
        #expect(!run.isSupported)
        copy = source; copy["fvar"] = [0]
        #expect(try shaper(copy).shape("x́", pointSize: 1000).diagnostics.contains(.unsupportedLayoutFeature("Variable-font shaping is unsupported")))
    }
    @Test func aliasedMarkMatricesConsumeSharedParsingBudget() {
        let u = TestFont.be16, copies = 32, classes = 128, bases = 128
        var bytes = u(1) + u(0) + u(10) + u(30) + u(44)
        bytes += u(1) + Array("latn".utf8) + u(8) + u(4) + u(0) + u(0) + u(65535) + u(1) + u(0)
        bytes += u(1) + Array("mark".utf8) + u(8) + u(0) + u(1) + u(0)
        bytes += u(1) + u(4) + u(4) + u(0) + u(copies)
        for _ in 0..<copies { bytes += u(6 + 2 * copies) }
        let markArray = 18 + 4 + 2 * bases, baseArray = markArray + 12
        bytes += u(1) + u(12) + u(18) + u(classes) + u(markArray) + u(baseArray)
        bytes += u(1) + u(1) + u(10) + u(1) + u(bases)
        for glyph in 100..<(100 + bases) { bytes += u(glyph) }
        bytes += u(1) + u(0) + u(6) + u(1) + u(0) + u(0)
        bytes += u(bases)
        for _ in 0..<(classes * bases) { bytes += u(2 + 2 * classes * bases) }
        bytes += u(1) + u(100) + u(200)
        let parsed = FontLayoutTables(tables: ["GPOS": bytes])
        #expect(parsed.markLookups.isEmpty)
        #expect(parsed.diagnostics == ["GPOS layout expansion exceeds the parsing budget"])
    }
    @Test func controlsLigaturesBreaksAndLongMarkRunsRemainBounded() throws {
        let shaper = try shaper(tables())
        #expect(!shaper.shape("f́i", pointSize: 1000).isSupported)
        #expect(!shaper.shape("xfí", pointSize: 1000).isSupported)
        #expect(!shaper.shape("x\ń", pointSize: 1000).isSupported)
        #expect(!shaper.shape("x\u{200D}́", pointSize: 1000).isSupported)
        let text = "x" + String(repeating: "́", count: 10000)
        let run = shaper.shape(text, pointSize: 1000)
        #expect(run.diagnostics.contains(.unsupportedLayoutFeature("Mark attachment execution exceeds the bounded profile")))
        #expect(run.glyphs.dropFirst().allSatisfy { $0.advance == 0 })
        #expect(run == shaper.shape(text, pointSize: 1000))
        #expect(shaper.shape("x́", pointSize: 1000, kerning: false) == shaper.shape("x́", pointSize: 1000))
    }
}
