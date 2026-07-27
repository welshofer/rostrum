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

    @Test func aBadColorValueReadsAsNoColorRatherThanAborting() throws {
        // Third-party writers really do emit 3-digit shorthand, 8-digit ARGB
        // and bare names. Color's initializer preconditions on six hex digits,
        // so every read-side accessor that parsed a:srgbClr@val straight from
        // the file used to abort the process.
        let box = Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1))
        for value in ["red", "", "FFF", "80FF0000", "ff0000 ", "GGGGGG"] {
            let deck = try Presentation()
            try deck.slides[0].shapes.addShape(.rectangle, frame: box, fill: .solid(Color("FF0000")))
            let dom = try deck.slides[0].part.dom()
            for srgb in Self.descendants(of: dom, named: "a:srgbClr") {
                srgb[attribute: "val"] = value
            }
            try deck.slides[0].part.markDirty()
            // The theme is read the same way and traps on the same values.
            let theme = try deck.theme.part.dom()
            for srgb in Self.descendants(of: theme, named: "a:srgbClr") {
                srgb[attribute: "val"] = value
            }
            deck.theme.part.markDirty()

            let reopened = try Presentation(data: try deck.serializedData())
            let read = try #require(reopened.slides[0].shapes.all.first)
            // Each of these used to abort the process; returning at all is the
            // assertion, and a malformed value must read as "no color".
            // An unreadable color is still a fill — reporting "no fill" would
            // claim the shape inherits, which it does not.
            #expect(read.fill == .unmodeled(elementName: "a:srgbClr"))
            _ = read.line
            _ = try reopened.slides[0].background
            #expect(reopened.theme.color(.accent1) == nil)
        }
    }

    /// Every descendant element with the given name, in document order.
    private static func descendants(of element: XML.Element, named name: String) -> [XML.Element] {
        var out: [XML.Element] = []
        if element.name == name { out.append(element) }
        for child in element.childElements { out += descendants(of: child, named: name) }
        return out
    }

    @Test func aHostilePointIndexDoesNotOverflow() throws {
        // `<c:pt idx="9223372036854775807"/>` parses as a valid Int, and the
        // cache sizing then computed idx + 1.
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(
            .barClustered, data: ChartData(categories: ["A"], name: "S", values: [1]),
            frame: Rect(x: .zero, y: .zero, width: .inches(4), height: .inches(3)))
        let chart = try #require(deck.charts.first)
        let dom = try chart.part.dom()
        let caches = Self.descendants(of: dom, named: "c:numCache")
            + Self.descendants(of: dom, named: "c:strCache")
        for cache in caches {
            cache.removeChildren(named: "c:ptCount")
            for pt in cache.children(named: "c:pt") {
                pt[attribute: "idx"] = String(Int.max)
            }
        }
        chart.part.markDirty()
        // Reading must return something (possibly empty), never trap.
        _ = chart.series
        _ = chart.categories
        _ = chart.data
    }

    @Test func aShapeIDAtTheFormatsCeilingThrowsRatherThanOverflowing() throws {
        // maxID + 1 on Int.max is a crash; a deck can claim any id.
        let deck = try Presentation()
        let spTree = try Slide.spTree(of: deck.slides[0].part)
        let sp = XML.Element("p:sp")
        let nv = XML.Element("p:nvSpPr")
        nv.appendElement(XML.Element("p:cNvPr", attributes: [
            ("id", String(Int.max)), ("name", "Hostile"),
        ]))
        sp.appendElement(nv)
        spTree.appendElement(sp)
        try deck.slides[0].part.markDirty()

        #expect(throws: RostrumError.self) {
            _ = try deck.slides[0].shapes.addShape(
                .rectangle, frame: Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1)),
                fill: .solid(Color("FF0000")))
        }
    }

    @Test func anAbsurdGroupChildSpaceDoesNotOverflow() throws {
        // Group child-space mapping subtracted and scaled raw Ints from the
        // file, then forced the result back through Int(_: Double).
        let slide = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" \
            xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">\
            <p:cSld><p:spTree>\
            <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\
            <p:grpSpPr/>\
            <p:grpSp>\
            <p:nvGrpSpPr><p:cNvPr id="2" name="G"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\
            <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="9223372036854775807" cy="1"/>\
            <a:chOff x="-9223372036854775808" y="0"/><a:chExt cx="1" cy="1"/></a:xfrm></p:grpSpPr>\
            <p:sp><p:nvSpPr><p:cNvPr id="3" name="S"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\
            <p:spPr><a:xfrm flipH="1" flipV="1">\
            <a:off x="9223372036854775807" y="9223372036854775807"/>\
            <a:ext cx="9223372036854775807" cy="9223372036854775807"/></a:xfrm></p:spPr>\
            <p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>\
            </p:grpSp></p:spTree></p:cSld></p:sld>
            """
        let deck = try Presentation()
        try deck.slides[0].part.replaceBlob(Data(slide.utf8))
        let group = try #require(deck.slides[0].shapes.all.first as? GroupShape)
        // Every one of these used to be an overflow or an out-of-range
        // Int(Double) conversion.
        for child in group.shapes {
            _ = group.convertToParentSpace(child.frame)
            _ = child.explicitFrame
        }
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
