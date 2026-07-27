import Foundation
import Testing
@testable import Rostrum

/// Robustness: hostile, malformed, and truncated input must fail as a thrown
/// `RostrumError` (or parse to a value) — never trap, crash, or hang. A trap
/// would abort the whole test process, so these tests SURFACE any such bug.
@Suite struct FuzzTests {
    /// Deterministic xorshift PRNG so any failure is reproducible.
    private struct RNG: RandomNumberGenerator {
        var state: UInt64
        init(_ seed: UInt64) { state = seed == 0 ? 0x9e3779b97f4a7c15 : seed }
        mutating func next() -> UInt64 {
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            return state
        }
    }

    private func validDeckBytes() throws -> Data {
        let deck = try Presentation()
        try deck.titleSlide("Fuzz", subtitle: "seed")
        try deck.bulletSlide("B", ["one", "two"])
        try deck.slides[0].shapes.addTable(rows: 2, columns: 2, frame: Rect(x: .zero, y: .zero, width: .inches(4), height: .inches(2)))
        return try deck.serializedData()
    }

    @Test func randomBytesNeverCrash() throws {
        var rng = RNG(0xF0F0)
        for length in [0, 1, 4, 22, 100, 512, 4096] {
            for _ in 0..<40 {
                var bytes = [UInt8](); bytes.reserveCapacity(length)
                for _ in 0..<length { bytes.append(UInt8(truncatingIfNeeded: rng.next())) }
                let data = Data(bytes)
                // Each entry point tolerates arbitrary bytes: it throws or returns.
                _ = try? ZipReader(data: data)
                _ = try? OPCPackage.read(data: data)
                _ = try? Presentation(data: data)
                _ = try? XML.parse(data)
                _ = try? Inflate.inflate(data)
            }
        }
    }

    /// Rebuild a deck with one entry's bytes replaced — for malformations that
    /// are structural rather than random, and so cannot be reached by flipping
    /// bits.
    private func deck(_ valid: Data, replacing entry: String,
                      _ transform: (String) -> String) throws -> Data {
        let reader = try ZipReader(data: valid)
        var writer = ZipWriter()
        for name in reader.entryNames {
            var bytes = try reader.data(forEntry: name)
            if name == entry {
                let text = try #require(String(data: bytes, encoding: .utf8))
                bytes = Data(transform(text).utf8)
            }
            writer.addFile(name: name, data: bytes)
        }
        return writer.finalize()
    }

    @Test func aRelativePartNameThrowsRatherThanAbortingTheProcess() throws {
        // OPC requires an <Override> PartName to be absolute. A file that omits
        // the leading slash reached PackURI's precondition, which aborts the
        // host process — a caller cannot catch that, and the bytes came from
        // whoever sent the file.
        let bad = try deck(try validDeckBytes(), replacing: "[Content_Types].xml") {
            $0.replacingOccurrences(of: "PartName=\"/", with: "PartName=\"")
        }
        #expect(throws: RostrumError.self) { _ = try Presentation(data: bad) }
        // And the same bytes must not trap the layer below either.
        _ = try? OPCPackage.read(data: bad)
    }

    @Test func truncatedValidDeckThrowsNotCrash() throws {
        let valid = try validDeckBytes()
        // Truncating a real deck at many lengths must throw a Rostrum error, not trap.
        var rng = RNG(0xBEEF)
        for _ in 0..<80 {
            let cut = Int(rng.next() % UInt64(valid.count))
            let truncated = valid.prefix(cut)
            #expect(throws: (any Error).self) { _ = try Presentation(data: truncated) }
            _ = try? ZipReader(data: truncated)   // must not crash either
        }
    }

    @Test func bitFlippedDeckNeverCrashes() throws {
        let valid = [UInt8](try validDeckBytes())
        var rng = RNG(0xC0FFEE)
        for _ in 0..<120 {
            var corrupted = valid
            // Flip a handful of random bytes.
            for _ in 0..<Int(1 + rng.next() % 8) {
                let i = Int(rng.next() % UInt64(corrupted.count))
                corrupted[i] = UInt8(truncatingIfNeeded: rng.next())
            }
            // May throw (CRC/parse) or occasionally still open — but never crash.
            _ = try? Presentation(data: Data(corrupted))
        }
    }

    @Test func malformedXMLNeverCrashes() throws {
        let inputs: [String] = [
            "", "<", "<a", "<a>", "<a></b>", "<a x=", "<a x='>", "<?xml", "<!--",
            "<![CDATA[", "<a>&badentity;</a>", String(repeating: "<a>", count: 5000),
            "<a>\u{FFFF}</a>", "<\u{0}>", "<a b='\u{0}'/>",
        ]
        for s in inputs { _ = try? XML.parse(Data(s.utf8)) }
        // Random UTF-8-ish blobs.
        var rng = RNG(0xD00D)
        for _ in 0..<60 {
            var bytes = [UInt8]("<a>".utf8)
            for _ in 0..<Int(rng.next() % 200) { bytes.append(UInt8(truncatingIfNeeded: rng.next())) }
            _ = try? XML.parse(Data(bytes))
        }
    }

    @Test func malformedDesignMarkdownNeverCrashes() throws {
        // Design.parse must never trap on hostile markdown (it feeds bad hex to
        // Color, weird headings, huge input, control chars).
        let inputs: [String] = [
            "", "#", "##", "## Palette\n- x: #ZZZZZZ", "## Palette\n- : #fff",
            "## Fonts\n- Heading:", "## Typography tokens\n- x: size px, weight",
            "**Theme:**\n**Vibe:**", String(repeating: "- a: #123456\n", count: 3000),
            "## Palette\n- c: ##123456", "## Palette\n- c: 12345", "## Palette\n- c: 1234567",
        ]
        for s in inputs {
            let d = Design.parse(s)
            let deck = try Presentation()
            deck.applyDesign(d)          // must not trap
            _ = deck.style
        }
    }
}
