import Foundation
import Testing
@testable import Rostrum

@Suite struct FontCompatibilityTests {
    private var fixture: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/Typography")
    }
    struct Record: Decodable { let fileName: String; let fontSHA256: String; let cases: [TextShaperTests.OracleCase] }
    struct Oracle: Decodable { let fonts: [Record]; let owned: Record; let wrapped: Record }
    private func oracle() throws -> Oracle {
        try JSONDecoder().decode(Oracle.self, from: Data(contentsOf: fixture.appendingPathComponent("calibri-harfbuzz-14.4.0.json")))
    }
    private func compare(_ record: Record, directory: URL) throws {
        let shaper = TextShaper(try FontMetrics(contentsOf: directory.appendingPathComponent(record.fileName)))
        for expected in record.cases {
            let run = shaper.shape(expected.text, pointSize: Double(shaper.metrics.unitsPerEm), direction: .leftToRight)
            #expect(run.isSupported, "\(record.fileName): \(expected.text): \(run.diagnostics)")
            #expect(run.glyphs.map(\.glyphID) == expected.glyphs.map(\.g), "\(record.fileName): \(expected.text)")
            #expect(run.glyphs.map(\.scalarRange.lowerBound) == expected.glyphs.map(\.cl))
            #expect(run.glyphs.map(\.advance) == expected.glyphs.map { Double($0.ax) }, "\(record.fileName): \(expected.text)")
            #expect(run.glyphs.map(\.xOffset) == expected.glyphs.map { Double($0.dx) })
            #expect(run.glyphs.map(\.yOffset) == expected.glyphs.map { Double($0.dy) })
            #expect(run == shaper.shape(expected.text, pointSize: Double(shaper.metrics.unitsPerEm), direction: .leftToRight))
        }
    }
    @Test func singleComponentLigaturesMatchHarfBuzzAndMakeProgress() throws {
        try compare(oracle().owned, directory: fixture)
        let shaper = TextShaper(try FontMetrics(contentsOf: fixture.appendingPathComponent("SingleComponentLigature.ttf")))
        let run = shaper.shape(String(repeating: "g", count: 10000), pointSize: 1000)
        #expect(run.isSupported)
        #expect(run.glyphs.count == 10000)
        #expect(run.glyphs.last?.scalarRange == 9999..<10000)
    }
    /// Run the pinned-hash Python verifier first. Portable CI needs no Office font.
    @Test func suppliedLocalCalibriMatchesPinnedHarfBuzz() throws {
        guard let path = ProcessInfo.processInfo.environment["ROSTRUM_CALIBRI_FONT_DIRECTORY"] else { return }
        for record in try oracle().fonts { try compare(record, directory: URL(fileURLWithPath: path)) }
    }
    private func wrappedKern(_ count: Int = 11000) -> [UInt8] {
        let u = TestFont.be16
        var power = 1, selector = 0
        while power <= count / 2 { power *= 2; selector += 1 }
        var result = u(0) + u(1) + u(0) + u(14 + 6 * count) + u(1)
        result += u(count) + u(power * 6) + u(selector) + u((count - power) * 6)
        // A complete, strictly sorted format-0 pair array.
        for key in 0..<count { result += u(key / 256) + u(key % 256) + u(-20) }
        return result
    }
    @Test func wrappedLegacyKerningMatchesHarfBuzz() throws {
        let record = try oracle().wrapped
        let shaper = TextShaper(try FontMetrics(contentsOf: fixture.appendingPathComponent(record.fileName)))
        for expected in record.cases {
            let run = shaper.shape(expected.text, pointSize: Double(shaper.metrics.unitsPerEm))
            #expect(run.isSupported)
            #expect(run.glyphs.map(\.glyphID) == expected.glyphs.map(\.g))
            #expect(run.glyphs.map(\.scalarRange.lowerBound) == expected.glyphs.map(\.cl))
            // Legacy kern specifies a pair adjustment, not how a client divides
            // it between glyph advances/offsets. HB divides it between glyphs;
            // Rostrum applies it to the first advance. Compare actual geometry.
            var actualPen = 0.0, expectedPen = 0.0
            for (actual, reference) in zip(run.glyphs, expected.glyphs) {
                #expect(actualPen + actual.xOffset == expectedPen + Double(reference.dx))
                #expect(actual.yOffset == Double(reference.dy))
                actualPen += actual.advance; expectedPen += Double(reference.ax)
            }
            #expect(actualPen == expectedPen)
        }
    }
    @Test func wrappedLengthRequiresExactUnambiguousFormatZeroTable() {
        for count in [11000, 21843, 26706, 65535] {
            let parsed = FontLayoutTables(tables: ["kern": wrappedKern(count)])
            #expect(parsed.diagnostics.isEmpty, "\(count)")
            #expect(parsed.legacyPairs.count == count)
            #expect(parsed.legacyPairs[0] == -20)
        }
    }
    @Test func malformedWrappedLengthsAndPairOrderRefuseAtomically() {
        let original = wrappedKern()
        var variants: [[UInt8]] = []
        // No guessing about subtable counts, versions, flags, or search fields.
        for (offset, value) in [(2, 2), (4, 1), (6, 1), (8, 9 + 16), (10, 65535),
                                (12, 0), (14, 0), (16, 0)] {
            var copy = original
            copy.replaceSubrange(offset..<(offset + 2), with: TestFont.be16(value))
            variants.append(copy)
        }
        variants += [Array(original.dropLast()), original + [0], Array(original.prefix(65536))]
        var duplicate = original
        duplicate.replaceSubrange(24..<28, with: Array(duplicate[18..<22]))
        variants.append(duplicate)
        var disorder = original
        disorder.replaceSubrange(24..<28, with: [255, 255, 255, 255])
        variants.append(disorder)
        for data in variants {
            let parsed = FontLayoutTables(tables: ["kern": data])
            #expect(!parsed.diagnostics.isEmpty)
            #expect(parsed.legacyPairs.isEmpty)
        }
    }
    private func sourceTables(_ file: String) throws -> [String: [UInt8]] {
        let r = SFNTReader(bytes: Array(try Data(contentsOf: fixture.appendingPathComponent(file))))
        var result: [String: [UInt8]] = [:]
        for i in 0..<(try r.u16(4)) {
            let p = 12 + 16 * i, offset = try r.u32(p + 8), count = try r.u32(p + 12)
            result[try r.tag(p)] = Array(r.bytes[offset..<(offset + count)])
        }
        return result
    }
    @Test func zeroComponentLigaturesStillRefuse() throws {
        var tables = try sourceTables("SingleComponentLigature.ttf"), bytes = try #require(tables["GSUB"])
        let r = SFNTReader(bytes: bytes), list = try r.u16(8)
        let lookup = list + (try r.u16(list + 2)), sub = lookup + (try r.u16(lookup + 6))
        let set = sub + (try r.u16(sub + 6)), rule = set + (try r.u16(set + 2))
        bytes.replaceSubrange((rule + 2)..<(rule + 4), with: [0, 0])
        tables["GSUB"] = bytes
        #expect(FontLayoutTables(tables: tables).diagnostics.contains("Malformed or unsupported GSUB Latin layout table"))
    }
    @Test func arabicSingleComponentIdentityAndReplacementMakeProgress() throws {
        let u = TestFont.be16
        var tables = try sourceTables("ArabicContexts.ttf")
        let metrics = try FontMetrics(contentsOf: fixture.appendingPathComponent("ArabicContexts.ttf"))
        let input = metrics.glyphID(for: "ب".unicodeScalars.first!)
        for replacement in [input, 75] {
            let scripts = u(1) + Array("arab".utf8) + u(8) + u(4) + u(0) + u(0) + u(65535) + u(1) + u(0)
            let features = u(1) + Array("liga".utf8) + u(8) + u(0) + u(1) + u(0)
            let sub = u(1) + u(8) + u(1) + u(14) + u(1) + u(1) + u(input) + u(1) + u(4) + u(replacement) + u(1)
            let lookup = u(1) + u(4) + u(4) + u(0) + u(1) + u(8) + sub
            tables["GSUB"] = u(1) + u(0) + u(10) + u(10 + scripts.count) + u(10 + scripts.count + features.count) + scripts + features + lookup
            let shaper = TextShaper(try FontMetrics(data: Data(TestFont.assemble(tables: tables.keys.sorted().map { ($0, tables[$0]!) }))))
            let run = shaper.shape("ببب", pointSize: 1000)
            #expect(run.isSupported)
            #expect(run.glyphs.map(\.glyphID) == [replacement, replacement, replacement])
            #expect(run.glyphs.map(\.scalarRange.lowerBound) == [2, 1, 0])
        }
    }
}
