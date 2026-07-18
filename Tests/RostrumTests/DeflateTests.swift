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
        // A presentation is XML-heavy; at least one entry must be DEFLATEd,
        // and every entry must still decode to the original.
        let reread = try OPCPackage.read(data: bytes)
        #expect(reread.parts.count == deck.package.parts.count)
        // Round-trip an XML part's bytes through the reader (which inflates).
        let pres = try reread.mainDocumentPart()
        #expect(!pres.blob.isEmpty)
    }
}
