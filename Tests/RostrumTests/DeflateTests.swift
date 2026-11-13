import Foundation
import Testing
@testable import Rostrum

@Suite struct DeflateTests {
    /// Seeded pseudo-random bytes (deterministic; SystemRandomNumberGenerator
    /// would break reproducibility).
    private func pseudoRandom(count: Int, seed: UInt64) -> Data {
        var state = seed
        var out = [UInt8]()
        out.reserveCapacity(count)
        for _ in 0..<count {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            out.append(UInt8((state >> 33) & 0xFF))
        }
        return Data(out)
    }

    @Test func roundTripsThroughOwnInflate() throws {
        let cases: [Data] = [
            Data(),
            Data("a".utf8),
            Data("hello hello hello hello world world world".utf8),
            Data(String(repeating: "The sunflower turns toward the sun. ", count: 200).utf8),
            Data(repeating: 0x42, count: 5000),
            pseudoRandom(count: 4000, seed: 7),
            Data((0..<256).map { UInt8($0) } + (0..<256).map { UInt8($0) }),
        ]
        for original in cases {
            let deflated = Deflate.deflate(original)
            let restored = try Inflate.inflate(deflated, expectedOutputSize: original.count)
            #expect(restored == original, "round-trip failed for \(original.count) bytes")
        }
    }

    @Test func compressesRepetitiveText() {
        let text = Data(String(repeating: "sunflower ", count: 1000).utf8)   // 10,000 bytes
        let deflated = Deflate.deflate(text)
        #expect(deflated.count < text.count / 5, "expected >5x on repetitive text, got \(text.count)->\(deflated.count)")
    }

    @Test func deterministicOutput() {
        let text = Data(String(repeating: "Helianthus annuus ", count: 500).utf8)
        #expect(Deflate.deflate(text) == Deflate.deflate(text))
    }

    @Test func externalUnzipCanExtract() throws {
        // Write a real .zip with a DEFLATEd entry and verify /usr/bin/unzip
        // both validates it and extracts the exact bytes.
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/unzip") else { return }
        let payload = Data(String(repeating: "toward the light, always. ", count: 400).utf8)
        var zip = ZipWriter()
        zip.addFile(name: "note.txt", data: payload)   // compresses by default
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rostrum-deflate-\(UUID().uuidString).zip")
        try zip.finalize().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        func run(_ args: [String]) throws -> (Int32, Data) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            p.arguments = args
            let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
            try p.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return (p.terminationStatus, data)
        }
        #expect(try run(["-t", url.path]).0 == 0)               // integrity OK
        #expect(try run(["-p", url.path, "note.txt"]).1 == payload)   // exact bytes
    }

    @Test func packageEntriesAreDeflatedAndReadBack() throws {
        let deck = try Presentation()
        let bytes = try deck.serializedData()
        let zip = try ZipReader(data: bytes)
        // A presentation is XML-heavy; at least one entry must be DEFLATEd
        // (method 8), and every entry must still decode to the original.
        #expect(zip.allEntries.contains { $0.method == 8 })
        let reread = try OPCPackage.read(data: bytes)
        #expect(reread.parts.count == deck.package.parts.count)
        // Round-trip an XML part's bytes through the reader (which inflates).
        let pres = try reread.mainDocumentPart()
        #expect(!pres.blob.isEmpty)
    }

    // MARK: - Dynamic Huffman blocks

    /// Inflate a raw DEFLATE stream with Python's zlib, an independent decoder.
    private func zlibInflate(_ data: Data) throws -> Data? {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/python3") else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-c", "import sys, zlib; sys.stdout.buffer.write(zlib.decompress(sys.stdin.buffer.read(), -15))"]
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        // Feed stdin from another thread: a large stream would otherwise fill
        // the pipe while the child is blocked writing its own output.
        let writer = Thread {
            try? input.fileHandleForWriting.write(contentsOf: data)
            try? input.fileHandleForWriting.close()
        }
        writer.start()
        let result = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? result : Data("zlib rejected the stream".utf8)
    }

    /// Text whose byte frequencies follow a Fibonacci-like curve: an
    /// unrestricted Huffman code for it is deeper than DEFLATE's 15-bit limit.
    private func skewed() -> Data {
        var out = [UInt8]()
        var a = 1, b = 1
        for symbol in 0..<26 {
            out.append(contentsOf: repeatElement(UInt8(65 + symbol), count: a))
            (a, b) = (b, a + b)
        }
        // Interleave deterministically so LZ77 cannot reduce it to a few runs.
        var state: UInt64 = 99
        for i in stride(from: out.count - 1, to: 0, by: -1) {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            out.swapAt(i, Int((state >> 33) % UInt64(i + 1)))
        }
        return Data(out)
    }

    private var slideLikeXML: Data {
        var xml = "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"><p:cSld><p:spTree>"
        for i in 0..<400 {
            xml += "<p:sp><p:nvSpPr><p:cNvPr id=\"\(i)\" name=\"Shape \(i)\"/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"\(i * 914400)\" y=\"\(i * 7)\"/></a:xfrm></p:spPr><p:txBody><a:p><a:r><a:t>Row \(i) of the quarterly figures</a:t></a:r></a:p></p:txBody></p:sp>"
        }
        return Data((xml + "</p:spTree></p:cSld></p:sld>").utf8)
    }

    @Test func independentDecoderAcceptsEveryBlockShape() throws {
        let cases: [(String, Data)] = [
            ("empty", Data()),
            ("one byte", Data("a".utf8)),
            ("one repeated byte", Data(repeating: 0x42, count: 70000)),
            ("no matches", Data((0..<256).map { UInt8($0) })),
            ("xml", slideLikeXML),
            ("depth-limited code", skewed()),
            ("incompressible", pseudoRandom(count: 50000, seed: 3)),
            // More tokens than one block holds, so several blocks are written.
            ("multi-block", pseudoRandom(count: 150000, seed: 11) + slideLikeXML + pseudoRandom(count: 20000, seed: 5)),
        ]
        for (name, original) in cases {
            let deflated = Deflate.deflate(original)
            #expect(try Inflate.inflate(deflated, expectedOutputSize: original.count) == original, "own inflate: \(name)")
            if let restored = try zlibInflate(deflated) {
                #expect(restored == original, "zlib: \(name)")
            }
            #expect(Deflate.deflate(original) == deflated, "determinism: \(name)")
        }
    }

    @Test func codeLengthsAreCompleteAndWithinTheLimit() {
        var frequency = [Int](repeating: 0, count: 286)
        var a = 1, b = 1
        for symbol in 0..<40 { frequency[symbol * 7] = a; (a, b) = (b, a + b) }
        for limit in [7, 15] {
            let lengths = Deflate.codeLengths(frequency, limit: limit)
            #expect(lengths.allSatisfy { Int($0) <= limit })
            #expect(zip(frequency, lengths).allSatisfy { ($0 == 0) == ($1 == 0) })
            // Kraft equality: the code is complete, never oversubscribed.
            #expect(lengths.reduce(0) { $0 + ($1 == 0 ? 0 : 1 << (limit - Int($1))) } == 1 << limit)
        }
        #expect(Deflate.codeLengths([0, 5, 0], limit: 15) == [0, 1, 0])
        #expect(Deflate.codeLengths([0, 0], limit: 15) == [0, 0])
    }

    @Test func markupCompressesWellBelowTheFixedCode() {
        // The fixed code spends at least 7 bits per token; a code fitted to
        // markup does much better. Guards against silently losing BTYPE=10.
        let xml = slideLikeXML
        let deflated = Deflate.deflate(xml)
        #expect(deflated.first.map { ($0 >> 1) & 3 } == 2, "expected a dynamic Huffman block")
        #expect(deflated.count * 10 < xml.count, "expected >10x on repetitive markup, got \(xml.count)->\(deflated.count)")
    }
}
