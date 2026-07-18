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
