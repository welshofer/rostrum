import Foundation
import Testing
@testable import Rostrum

/// Tests for the raw-DEFLATE decoder. Compressed fixtures are produced by an
/// external oracle: Python's zlib (`compressobj` with `wbits=-15` emits raw
/// DEFLATE with no zlib header/trailer).
@Suite struct InflateTests {

    // MARK: - Fixture helpers

    /// Compress `data` to a raw DEFLATE stream using Python's zlib as an oracle.
    private func rawDeflate(_ data: Data, level: Int = 9, strategy: String = "Z_DEFAULT_STRATEGY") throws -> Data {
        let script = """
            import sys, zlib
            level = int(sys.argv[1])
            strategy = getattr(zlib, sys.argv[2])
            c = zlib.compressobj(level, zlib.DEFLATED, -15, 9, strategy)
            payload = sys.stdin.buffer.read()
            sys.stdout.buffer.write(c.compress(payload) + c.flush())
            """
        return try runTool("/usr/bin/python3", ["-c", script, String(level), strategy], stdin: data)
    }

    private func runTool(_ path: String, _ arguments: [String], stdin: Data? = nil) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        if let stdin, !stdin.isEmpty {
            try stdinPipe.fileHandleForWriting.write(contentsOf: stdin)
        }
        try stdinPipe.fileHandleForWriting.close()
        let output = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw FixtureError.toolFailed(path, process.terminationStatus)
        }
        return output
    }

    private enum FixtureError: Error {
        case toolFailed(String, Int32)
    }

    /// Deterministic pseudorandom bytes (64-bit LCG), independent of Foundation's RNG.
    private func pseudorandomData(count: Int, seed: UInt64) -> Data {
        var state = seed
        var bytes = [UInt8]()
        bytes.reserveCapacity(count)
        for _ in 0..<count {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            bytes.append(UInt8(truncatingIfNeeded: state >> 33))
        }
        return Data(bytes)
    }

    /// Expect `body` to throw `RostrumError.deflateCorrupt`.
    private func expectDeflateCorrupt(
        _ label: String, sourceLocation: SourceLocation = #_sourceLocation, _ body: () throws -> Void
    ) {
        do {
            try body()
            Issue.record("\(label): expected deflateCorrupt but nothing was thrown", sourceLocation: sourceLocation)
        } catch let error as RostrumError {
            guard case .deflateCorrupt = error else {
                Issue.record("\(label): expected deflateCorrupt, got \(error)", sourceLocation: sourceLocation)
                return
            }
        } catch {
            Issue.record("\(label): expected RostrumError.deflateCorrupt, got \(error)", sourceLocation: sourceLocation)
        }
    }

    /// LSB-first bit writer for hand-crafting DEFLATE streams.
    private struct BitWriter {
        var bytes: [UInt8] = []
        var bitCount = 0

        mutating func write(_ value: Int, bits: Int) {
            for i in 0..<bits {
                let bit = (value >> i) & 1
                if bitCount % 8 == 0 { bytes.append(0) }
                bytes[bytes.count - 1] |= UInt8(bit << (bitCount % 8))
                bitCount += 1
            }
        }

        var data: Data { Data(bytes) }
    }

    // MARK: - Round trips against the zlib oracle

    @Test func emptyPayloadRoundTrip() throws {
        let compressed = try rawDeflate(Data())
        #expect(!compressed.isEmpty)
        let decoded = try Inflate.inflate(compressed)
        #expect(decoded == Data())
    }

    @Test func shortASCIIRoundTrip() throws {
        let original = Data("The quick brown fox jumps over the lazy dog.".utf8)
        for level in [1, 6, 9] {
            let compressed = try rawDeflate(original, level: level)
            let decoded = try Inflate.inflate(compressed)
            #expect(decoded == original, "level \(level)")
        }
    }

    @Test func fixedHuffmanRoundTrip() throws {
        // Z_FIXED forces fixed-Huffman blocks (BTYPE=01).
        let original = Data("hello hello hello hello — fixed Huffman coding block".utf8)
        let compressed = try rawDeflate(original, strategy: "Z_FIXED")
        let decoded = try Inflate.inflate(compressed)
        #expect(decoded == original)
    }

    @Test func storedBlocksRoundTrip() throws {
        // Level 0 forces stored blocks; 150,000 bytes needs at least three
        // stored blocks (max 65,535 bytes each).
        let original = pseudorandomData(count: 150_000, seed: 7)
        let compressed = try rawDeflate(original, level: 0)
        let decoded = try Inflate.inflate(compressed)
        #expect(decoded == original)
    }

    @Test func repetitive200KBRoundTrip() throws {
        // Highly repetitive data exercises long matches and dynamic Huffman blocks.
        var original = Data()
        original.reserveCapacity(200_000)
        let phrase = Data("rostrum makes slides; slides make points; points make decks. ".utf8)
        while original.count < 200_000 {
            original.append(phrase)
        }
        original = original.prefix(200_000)
        let compressed = try rawDeflate(original, level: 9)
        #expect(compressed.count < original.count / 10) // sanity: it really compressed
        let decoded = try Inflate.inflate(compressed, expectedOutputSize: original.count)
        #expect(decoded == original)
    }

    @Test func pseudorandom100KBRoundTrip() throws {
        // Poorly compressible data: zlib falls back to stored/near-stored blocks.
        let original = pseudorandomData(count: 100_000, seed: 0xDEAD_BEEF)
        for level in [0, 9] {
            let compressed = try rawDeflate(original, level: level)
            let decoded = try Inflate.inflate(compressed, expectedOutputSize: original.count)
            #expect(decoded == original, "level \(level)")
        }
    }

    @Test func allByteValuesRoundTrip() throws {
        var original = Data()
        for _ in 0..<50 {
            original.append(contentsOf: UInt8.min...UInt8.max)
        }
        let compressed = try rawDeflate(original)
        let decoded = try Inflate.inflate(compressed)
        #expect(decoded == original)
    }

    @Test func longMatchAcross32KBWindow() throws {
        // Two copies of the same 40KB chunk separated by filler close to the
        // 32KB window limit exercises large distances.
        let chunk = pseudorandomData(count: 40_000, seed: 42)
        var original = Data()
        original.append(chunk)
        original.append(Data(repeating: 0x2E, count: 30_000))
        original.append(chunk)
        let compressed = try rawDeflate(original, level: 9)
        let decoded = try Inflate.inflate(compressed)
        #expect(decoded == original)
    }

    // MARK: - Corrupt streams

    @Test func emptyInputThrows() {
        expectDeflateCorrupt("empty input") {
            _ = try Inflate.inflate(Data())
        }
    }

    @Test func blockType3Throws() {
        // BFINAL=1, BTYPE=11 → invalid. (zlib oracle: "invalid block type")
        expectDeflateCorrupt("BTYPE=11") {
            _ = try Inflate.inflate(Data([0x07]))
        }
    }

    @Test func truncatedStreamsThrow() throws {
        let original = Data("compression is fun; compression is fun; compression is fun".utf8)
        let compressed = try rawDeflate(original)
        expectDeflateCorrupt("half stream") {
            _ = try Inflate.inflate(compressed.prefix(compressed.count / 2))
        }
        expectDeflateCorrupt("missing last byte") {
            _ = try Inflate.inflate(compressed.prefix(compressed.count - 1))
        }
        expectDeflateCorrupt("first byte only") {
            _ = try Inflate.inflate(compressed.prefix(1))
        }
    }

    @Test func truncatedStoredBlockThrows() {
        // BFINAL=1, BTYPE=00, LEN=5/NLEN ok, but only two data bytes follow.
        expectDeflateCorrupt("truncated stored data") {
            _ = try Inflate.inflate(Data([0x01, 0x05, 0x00, 0xFA, 0xFF, 0x61, 0x62]))
        }
        // Stored block header cut off mid-LEN.
        expectDeflateCorrupt("truncated stored header") {
            _ = try Inflate.inflate(Data([0x01, 0x05]))
        }
    }

    @Test func storedLenNlenMismatchThrows() {
        // LEN=5 but NLEN=0 (should be ~5). (zlib oracle: "invalid stored block lengths")
        expectDeflateCorrupt("LEN/NLEN mismatch") {
            _ = try Inflate.inflate(Data([0x01, 0x05, 0x00, 0x00, 0x00]))
        }
    }

    @Test func distanceBeforeStartThrows() {
        // Hand-crafted fixed-Huffman block: first symbol is length 3 with
        // distance 1, but there is no prior output.
        // (zlib oracle: "invalid distance too far back")
        expectDeflateCorrupt("distance too far back") {
            _ = try Inflate.inflate(Data([0x03, 0x02]))
        }
    }

    @Test func oversubscribedCodeLengthsThrow() {
        // Dynamic block whose 19 code-length codes all have length 1: wildly
        // oversubscribed (only two 1-bit codes can exist).
        var writer = BitWriter()
        writer.write(1, bits: 1) // BFINAL
        writer.write(2, bits: 2) // BTYPE=10 dynamic
        writer.write(0, bits: 5) // HLIT  = 257
        writer.write(0, bits: 5) // HDIST = 1
        writer.write(15, bits: 4) // HCLEN = 19
        for _ in 0..<19 {
            writer.write(1, bits: 3) // every code-length code gets length 1
        }
        expectDeflateCorrupt("oversubscribed code lengths") {
            _ = try Inflate.inflate(writer.data)
        }
    }

    @Test func tooManyLiteralCodesThrows() {
        // HLIT=30 → 287 literal/length codes; the maximum is 286.
        var writer = BitWriter()
        writer.write(1, bits: 1) // BFINAL
        writer.write(2, bits: 2) // BTYPE=10 dynamic
        writer.write(30, bits: 5) // HLIT = 287 (invalid)
        writer.write(0, bits: 5)
        writer.write(0, bits: 4)
        expectDeflateCorrupt("too many literal codes") {
            _ = try Inflate.inflate(writer.data)
        }
    }

    @Test func corruptedByteMidStreamThrows() throws {
        // Flip a byte in the middle of a dynamic-Huffman stream. Decoding must
        // fail (never hang or crash); with the Huffman tables scrambled the
        // stream is invalid.
        let original = Data(String(repeating: "abcdefgabcdefg hijklmnop ", count: 400).utf8)
        var compressed = try rawDeflate(original)
        compressed[compressed.count / 3] ^= 0xFF
        do {
            let decoded = try Inflate.inflate(compressed, expectedOutputSize: original.count)
            // A single flipped byte occasionally still decodes structurally; it
            // must then at least produce wrong bytes rather than silently match.
            #expect(decoded != original, "flipped byte cannot round-trip cleanly")
        } catch let error as RostrumError {
            guard case .deflateCorrupt = error else {
                Issue.record("expected deflateCorrupt, got \(error)")
                return
            }
        }
    }

    // MARK: - Primary (9-bit) Huffman lookup

    /// A complete code with one symbol per length 1...14 and two of length 15:
    /// symbol k < 15 is k ones then a zero; symbol 15 is fifteen ones. Codes
    /// 0...8 fit the primary table; 9...15 are longer than `fastBits` and must
    /// fall back to the canonical walk.
    private static let staircaseLengths: [Int] = Array(1...15) + [15]

    /// MSB-first code bits for symbol `sym` of `staircaseLengths`.
    private func writeStaircase(_ sym: Int, into writer: inout BitWriter) {
        let ones = sym == 15 ? 15 : sym
        for _ in 0..<ones { writer.write(1, bits: 1) }
        if sym < 15 { writer.write(0, bits: 1) }
    }

    @Test func fastTableResolvesShortCodesAndMissesLongOnes() throws {
        let table = try HuffmanTable(lengths: Self.staircaseLengths)
        #expect(table.left == 0)
        // Symbol 3 is `1110` MSB-first, i.e. stream bits 1,1,1,0 → index 0b0111
        // LSB-first; every 9-bit index sharing that prefix resolves to it.
        for high in 0..<(1 << 5) {
            let index = 0b0111 | (high << 4)
            let hit = try #require(table.fastLookup(index))
            #expect(hit.symbol == 3)
            #expect(hit.length == 4)
        }
        // Symbol 0 is the single bit `0`: half the table.
        for high in 0..<(1 << 8) {
            let hit = try #require(table.fastLookup(high << 1))
            #expect(hit.symbol == 0 && hit.length == 1)
        }
        // The longest code the table can hold is symbol 8 (`111111110`).
        let eight = try #require(table.fastLookup(0b0_1111_1111))
        #expect(eight.symbol == 8 && eight.length == 9)
        // Nine ones is the prefix of every code longer than 9 bits: a miss.
        #expect(table.fastLookup(0b1_1111_1111) == nil)

        // The fixed literal table (7/8/9-bit codes) is fully resolvable.
        let fixed = InflateDecoder.fixedTables.0
        for index in 0..<(1 << HuffmanTable.fastBits) {
            #expect(fixed.fastLookup(index) != nil, "fixed index \(index)")
        }
    }

    @Test func decodeFallsBackToCanonicalWalkForLongCodes() throws {
        let table = try HuffmanTable(lengths: Self.staircaseLengths)
        let sequence = [12, 3, 15, 0, 9, 14, 8, 10, 0, 0, 13, 5]
        var writer = BitWriter()
        for sym in sequence { writeStaircase(sym, into: &writer) }
        var decoder = InflateDecoder(input: [UInt8](writer.data), expectedOutputSize: nil)
        var decoded: [Int] = []
        for _ in sequence { decoded.append(try decoder.decode(table)) }
        #expect(decoded == sequence)
        // The slow walk must agree bit-for-bit with the fast path.
        var walker = InflateDecoder(input: [UInt8](writer.data), expectedOutputSize: nil)
        var walked: [Int] = []
        for _ in sequence { walked.append(try walker.decodeSlow(table)) }
        #expect(walked == sequence)
    }

    @Test func decodeThrowsWhenStreamEndsInsideACode() throws {
        let table = try HuffmanTable(lengths: Self.staircaseLengths)
        // Eight ones and then nothing: the primary table pads the ninth bit
        // with a zero and finds symbol 8 (`111111110`), but that ninth bit is
        // not in the input, so the hit must be rejected rather than consumed.
        var decoder = InflateDecoder(input: [0xFF], expectedOutputSize: nil)
        expectDeflateCorrupt("code cut off by end of input") { _ = try decoder.decode(table) }
        // Two zeros (symbol 0 twice) then fourteen ones: past the primary
        // table, the walk runs out of input one bit short of symbol 14/15.
        decoder = InflateDecoder(input: [0xFC, 0xFF], expectedOutputSize: nil)
        #expect(try decoder.decode(table) == 0)
        #expect(try decoder.decode(table) == 0)
        expectDeflateCorrupt("long code cut off by end of input") { _ = try decoder.decode(table) }
        // No input at all.
        decoder = InflateDecoder(input: [], expectedOutputSize: nil)
        expectDeflateCorrupt("empty input") { _ = try decoder.decode(table) }
        // A short code followed by padding zeros decodes: `0` is symbol 0 and
        // the zero padding of the final byte is a legitimate symbol 0 too.
        decoder = InflateDecoder(input: [0x00], expectedOutputSize: nil)
        for _ in 0..<8 { #expect(try decoder.decode(table) == 0) }
        expectDeflateCorrupt("byte fully consumed") { _ = try decoder.decode(table) }
    }

    @Test func peekAndDropMirrorBits() throws {
        var reader = InflateDecoder(input: [0b1010_0101, 0b1100_0011, 0xFF], expectedOutputSize: nil)
        #expect(reader.peek(9) == 0b1_1010_0101)
        #expect(reader.bitCount == 16)
        reader.drop(3)
        #expect(reader.peek(9) == 0b0_0111_0100)
        #expect(try reader.bits(5) == 0b1_0100)
        #expect(reader.bitCount == 8)
        // At the end of input peek returns the real bits zero-padded and
        // reports how many are real through bitCount; it never throws.
        reader.drop(8)
        #expect(reader.bitCount == 0)
        #expect(reader.peek(9) == 0b0_1111_1111)
        #expect(reader.bitCount == 8)
        reader.drop(8)
        #expect(reader.peek(9) == 0)
        #expect(reader.bitCount == 0)
        expectDeflateCorrupt("bits past the end") { _ = try reader.bits(1) }
    }

    // MARK: - Randomized oracle round trips

    /// Payload shapes that drive the encoder into different block types and
    /// code-length distributions: dynamic tables with long codes (skewed
    /// alphabets), fixed blocks, stored blocks and far-back distances.
    private func oraclePayload(kind: Int, seed: UInt64) -> Data {
        switch kind {
        case 0:
            // Skewed byte frequencies (Zipf-like) force dynamic tables whose
            // rare symbols get the long (10-15 bit) codes.
            var state = seed
            var bytes = [UInt8]()
            for _ in 0..<60_000 {
                state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let r = Int(state >> 33)
                let rank = r % 1_000
                let sym: Int
                if rank < 700 { sym = r % 4 } else if rank < 950 { sym = 4 + r % 24 } else { sym = 28 + r % 228 }
                bytes.append(UInt8(sym))
            }
            return Data(bytes)
        case 1:
            // Repeats separated by just under the 32 KiB window: the longest
            // distance codes (13 extra bits) with long matches.
            let chunk = pseudorandomData(count: 3_000, seed: seed)
            var data = Data()
            for i in 0..<4 {
                data.append(chunk)
                data.append(pseudorandomData(count: 29_500 + i * 100, seed: seed &+ UInt64(i) &+ 1))
            }
            data.append(chunk)
            return data
        case 2:
            // Text-like content: ordinary dynamic blocks with short matches.
            let words = ["slide", "deck", "layout", "placeholder", "theme", "master", "rostrum", "\n", " ", "—"]
            var state = seed
            var text = ""
            while text.utf8.count < 40_000 {
                state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                text += words[Int(state >> 33) % words.count]
                text += " "
            }
            return Data(text.utf8)
        default:
            // Near-incompressible noise with a few planted runs.
            var data = pseudorandomData(count: 20_000, seed: seed)
            data.append(Data(repeating: UInt8(truncatingIfNeeded: seed), count: 700))
            data.append(pseudorandomData(count: 20_000, seed: seed ^ 0xABCD))
            return data
        }
    }

    @Test func randomizedOracleRoundTrips() throws {
        let strategies = ["Z_DEFAULT_STRATEGY", "Z_FILTERED", "Z_HUFFMAN_ONLY", "Z_RLE", "Z_FIXED"]
        var seed: UInt64 = 0x5EED_0000_0000_0001
        for kind in 0..<4 {
            for (i, strategy) in strategies.enumerated() {
                seed = seed &* 2_862_933_555_777_941_757 &+ 3_037_000_493
                let original = oraclePayload(kind: kind, seed: seed)
                let level = [1, 6, 9][(kind + i) % 3]
                let compressed = try rawDeflate(original, level: level, strategy: strategy)
                let decoded = try Inflate.inflate(compressed, expectedOutputSize: original.count)
                #expect(decoded == original, "kind \(kind) \(strategy) level \(level) seed \(seed)")
                let undeclared = try Inflate.inflate(compressed)
                #expect(undeclared == original, "kind \(kind) \(strategy) level \(level) undeclared size")
            }
        }
    }

    @Test func skewedAlphabetProducesLongDynamicCodes() throws {
        // Guard the premise of the fallback coverage: the skewed payload's
        // dynamic table really does contain codes longer than the primary
        // lookup, so `randomizedOracleRoundTrips` exercises `decodeSlow`.
        let original = oraclePayload(kind: 0, seed: 99)
        let compressed = try rawDeflate(original, level: 9)
        var decoder = InflateDecoder(input: [UInt8](compressed), expectedOutputSize: original.count)
        _ = try decoder.bits(1) // BFINAL of the first block
        #expect(try decoder.bits(2) == 2) // dynamic
        let (literals, _) = try decoder.dynamicTables()
        let longest = (1...15).last { literals.count[$0] > 0 } ?? 0
        #expect(longest > HuffmanTable.fastBits, "longest literal code is \(longest) bits")
        #expect(literals.fastLookup(0b1_1111_1111) == nil)
    }

    @Test func everyTruncationOfOracleStreamsThrows() throws {
        // A proper prefix of a valid stream always ends before the final
        // end-of-block code, so every truncation must throw — through the
        // fast path's padding check as well as the walk's `bits(1)`.
        let streams: [Data] = [
            try rawDeflate(Data()),
            try rawDeflate(Data("a".utf8)),
            try rawDeflate(Data(String(repeating: "truncate me ", count: 40).utf8)),
            try rawDeflate(oraclePayload(kind: 0, seed: 5).prefix(2_000), level: 9),
            try rawDeflate(oraclePayload(kind: 2, seed: 6).prefix(1_500), strategy: "Z_FIXED"),
            try rawDeflate(pseudorandomData(count: 300, seed: 8), level: 0),
            try rawDeflate(oraclePayload(kind: 1, seed: 7), level: 9),
        ]
        for (n, stream) in streams.enumerated() {
            // Every byte of the small streams; a 120-cut sample of the big one.
            let step = Swift.max(1, stream.count / (stream.count > 10_000 ? 120 : 400))
            var cut = 0
            while cut < stream.count {
                expectDeflateCorrupt("stream \(n) cut at \(cut) of \(stream.count)") {
                    _ = try Inflate.inflate(stream.prefix(cut))
                }
                cut += step
            }
            _ = try Inflate.inflate(stream)
        }
    }

    // MARK: - expectedOutputSize

    @Test func expectedOutputSizeExceededThrows() throws {
        let original = Data("hello world, this will not fit".utf8)
        let compressed = try rawDeflate(original)
        expectDeflateCorrupt("output exceeds expected size") {
            _ = try Inflate.inflate(compressed, expectedOutputSize: 3)
        }
    }

    @Test func expectedOutputSizeExactPasses() throws {
        let original = Data("exactly sized output".utf8)
        let compressed = try rawDeflate(original)
        let decoded = try Inflate.inflate(compressed, expectedOutputSize: original.count)
        #expect(decoded == original)
    }
}
