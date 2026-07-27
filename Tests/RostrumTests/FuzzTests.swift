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
        // The layer below must throw too — Presentation delegates to it, but
        // OPCPackage is public API a caller can reach on its own.
        #expect(throws: RostrumError.self) { _ = try OPCPackage.read(data: bad) }
    }

    @Test func aBadColorValueReadsAsNoColorRatherThanAborting() throws {
        // Third-party writers really do emit 3-digit shorthand, 8-digit ARGB
        // and bare names. Color's initializer preconditions on six hex digits,
        // so every read-side accessor that parsed a:srgbClr@val straight from
        // the file used to abort the process.
        let box = Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1))
        for value in ["red", "", "FFF", "80FF0000", "ff0000 ", "GGGGGG"] {
            let deck = try Presentation()
            // Every distinct colour-parsing path in one deck, because each
            // reads a:srgbClr separately: a solid fill, an outline (ReadLine,
            // which the first sweep missed), a gradient stop, a text run, and
            // the slide background.
            try deck.slides[0].shapes.addShape(.rectangle, frame: box,
                                               fill: .solid(Color("FF0000")),
                                               line: Line(color: Color("00FF00")))
            try deck.slides[0].shapes.addShape(
                .ellipse, frame: box,
                fill: .gradient(GradientFill(from: Color("112233"), to: Color("445566"))))
            let textBox = try deck.slides[0].shapes.addTextBox(box)
            let paragraph = try #require(textBox.textFrame?.paragraphs.first)
            paragraph.addRun("tinted").color = Color("778899")
            try deck.slides[0].setBackground(.solid(Color("ABCDEF")))
            let dom = try deck.slides[0].part.dom()
            for srgb in Self.descendants(of: dom, named: "a:srgbClr") {
                srgb[attribute: "val"] = value
            }
            try deck.slides[0].part.markDirty()
            // The theme is read the same way and traps on the same values —
            // through a:sysClr@lastClr as well as a:srgbClr@val, which is a
            // separate branch of Theme.color.
            let theme = try deck.theme.part.dom()
            for srgb in Self.descendants(of: theme, named: "a:srgbClr") {
                srgb[attribute: "val"] = value
            }
            for sysClr in Self.descendants(of: theme, named: "a:sysClr") {
                sysClr[attribute: "lastClr"] = value
            }
            deck.theme.part.markDirty()

            let reopened = try Presentation(data: try deck.serializedData())
            let read = try #require(reopened.slides[0].shapes.all.first)
            // Each of these used to abort the process; returning at all is the
            // assertion, and a malformed value must read as "no color".
            // An unreadable color is still a fill — reporting "no fill" would
            // claim the shape inherits, which it does not.
            #expect(read.fill == .unmodeled(elementName: "a:srgbClr"))
            // The outline is still there — only its unreadable color is gone.
            let line = try #require(read.line)
            #expect(line.color == nil)
            #expect(line.width != nil)

            let shapes = try reopened.slides[0].shapes.all
            // The gradient's stops are unreadable, so the fill reports no stops
            // rather than trapping on the first one.
            #expect(shapes.compactMap(\.fill).contains { fill in
                if case .gradient(let stops) = fill { return stops.isEmpty }
                return false
            }, "the gradient stop colours must drop out, not abort")
            // A run's colour, the slide background, and both theme branches.
            for shape in shapes {
                for paragraph in shape.textFrame?.paragraphs ?? [] {
                    for run in paragraph.runs { #expect(run.color == nil) }
                }
            }
            #expect(try reopened.slides[0].background == .unmodeled(elementName: "a:srgbClr"))
            #expect(reopened.theme.color(.accent1) == nil)
            #expect(reopened.theme.color(.dk1) == nil)
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

    /// Plant a `p:cNvPr` carrying `id` on the deck's first slide.
    private func plantShapeID(_ deck: Presentation, _ id: String) throws {
        let spTree = try Slide.spTree(of: deck.slides[0].part)
        let sp = XML.Element("p:sp")
        let nv = XML.Element("p:nvSpPr")
        nv.appendElement(XML.Element("p:cNvPr", attributes: [("id", id), ("name", "Hostile")]))
        sp.appendElement(nv)
        spTree.appendElement(sp)
        try deck.slides[0].part.markDirty()
    }

    private var unitBox: Rect {
        Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1))
    }

    @Test func anOutOfRangeShapeIDIsIgnoredNotClamped() throws {
        // `maxID + 1` on Int.max is a crash. Clamping the id to the ceiling
        // instead would be its own bug: one hostile id would pin maxID at the
        // maximum and refuse every future shape on the slide.
        let deck = try Presentation()
        try plantShapeID(deck, String(Int.max))
        let shape = try deck.slides[0].shapes.addShape(
            .rectangle, frame: unitBox, fill: .solid(Color("FF0000")))
        let id = try #require(shape.element.firstChild(named: "p:nvSpPr")?
            .firstChild(named: "p:cNvPr")?[attribute: "id"])
        #expect(Int(id) != nil && Int(id)! < Slide.maxShapeID,
                "the out-of-range id must be ignored, leaving a small next id")
    }

    @Test func aShapeIDAtTheFormatsCeilingThrows() throws {
        // A legitimately-valid id at the top of ST_DrawingElementId genuinely
        // leaves nothing to allocate, and that is an error, not a crash.
        let deck = try Presentation()
        try plantShapeID(deck, String(Slide.maxShapeID))
        #expect(throws: RostrumError.self) {
            _ = try deck.slides[0].shapes.addShape(
                .rectangle, frame: unitBox, fill: .solid(Color("FF0000")))
        }
    }

    @Test func aHostileSlideIDDoesNotOverflowWhenAddingASlide() throws {
        // The exact twin of the shape-id overflow, on p:sldId@id.
        let deck = try Presentation()
        let list = try #require(try deck.presentationPart.dom().firstChild(named: "p:sldIdLst"))
        list.childElements.first?[attribute: "id"] = String(Int.max)
        deck.presentationPart.markDirty()
        // Out of ST_SlideId's range, so ignored — adding must still work.
        _ = try deck.slides.add()

        // At the ceiling it is a real exhaustion, and must throw.
        list.childElements.first?[attribute: "id"] = "2147483647"
        deck.presentationPart.markDirty()
        #expect(throws: RostrumError.self) { _ = try deck.slides.add() }
    }

    @Test func hostileGeometryDoesNotOverflowTheSVGRenderer() throws {
        // renderSVG is a pure read API doing Int arithmetic on every a:off and
        // a:ext it reads — x + inset, cx += cw, x + w / 2 — and Swift's + traps.
        let slide = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" \
            xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">\
            <p:cSld><p:spTree>\
            <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\
            <p:grpSpPr/>\
            <p:sp><p:nvSpPr><p:cNvPr id="2" name="S"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\
            <p:spPr><a:xfrm><a:off x="9223372036854775807" y="9223372036854775807"/>\
            <a:ext cx="9223372036854775807" cy="9223372036854775807"/></a:xfrm>\
            <a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></p:spPr>\
            <p:txBody><a:bodyPr lIns="9223372036854775807"/><a:lstStyle/>\
            <a:p><a:pPr algn="ctr"/><a:r><a:rPr sz="9223372036854775807"/>\
            <a:t>hi</a:t></a:r></a:p></p:txBody></p:sp>\
            </p:spTree></p:cSld></p:sld>
            """
        let deck = try Presentation()
        try deck.slides[0].part.replaceBlob(Data(slide.utf8))
        // Also make the slide size itself absurd: the aspect-ratio conversion
        // runs Int(_: Double) before any shape is visited.
        deck.slideSize = (width: EMU(1), height: EMU(Int.max))
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("<svg"))
    }

    @Test func aHostileColourCannotInjectMarkupIntoTheSVG() throws {
        // colorHex interpolates into an SVG attribute, unescaped.
        let deck = try Presentation()
        try deck.slides[0].shapes.addShape(.rectangle, frame: unitBox,
                                           fill: .solid(Color("FF0000")))
        let dom = try deck.slides[0].part.dom()
        for srgb in Self.descendants(of: dom, named: "a:srgbClr") {
            srgb[attribute: "val"] = "x\" onload=\"alert(1)"
        }
        try deck.slides[0].part.markDirty()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(!svg.contains("onload"), "a file-supplied colour must not become markup")
    }

    @Test func aChartWithTooManySeriesReadsAsNilRatherThanTrapping() throws {
        // ChartData's 255-series bound is a precondition — a programmer check.
        // A file can declare any number of c:ser.
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(
            .barClustered, data: ChartData(categories: ["A"], name: "S", values: [1]),
            frame: Rect(x: .zero, y: .zero, width: .inches(4), height: .inches(3)))
        let chart = try #require(deck.charts.first)
        let plot = try #require(chart.plots.first)
        let template = try #require(plot.children(named: "c:ser").first)
        for _ in 0..<300 { plot.appendElement(template.deepCopy()) }
        chart.part.markDirty()

        #expect(chart.seriesElements.count > 255)
        #expect(chart.data == nil, "over the bound, the category view is honestly nil")
        _ = chart.series
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
            <p:grpSpPr><a:xfrm flipH="1" flipV="1">\
            <a:off x="0" y="0"/><a:ext cx="9223372036854775807" cy="1"/>\
            <a:chOff x="-9223372036854775808" y="0"/><a:chExt cx="1" cy="1"/></a:xfrm></p:grpSpPr>\
            <p:sp><p:nvSpPr><p:cNvPr id="3" name="S"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\
            <p:spPr><a:xfrm>\
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

    @Test func duplicateSectionStartsDoNotTripTheStrictlyIncreasingCheck() throws {
        // boundaries() is derived from the file, and two p14:section entries
        // can resolve to the same start slide — an unresolvable sldId falls
        // back to 0. set(_:) requires strictly increasing starts.
        let deck = try Presentation()
        try deck.slides.add()
        _ = try deck.sections.add("One", startingAtSlide: 1)
        let list = try #require(try deck.presentationPart.dom()
            .firstChild(named: "p:extLst"))
        for sldId in Self.descendants(of: list, named: "p14:sldId") {
            sldId[attribute: "id"] = "999999"   // resolves nowhere → index 0
        }
        deck.presentationPart.markDirty()

        // Adding another section must not abort the process.
        _ = try? deck.sections.add("Two", startingAtSlide: 1)
    }

    @Test func tooManyPartsIsReportedNotTrapped() throws {
        // ZipWriter's 0xFFFF entry ceiling is a precondition. A deck can carry
        // that many parts, and saving one you just opened must not abort.
        let deck = try Presentation()
        for n in 0..<0xFFFF {
            deck.package.addPart(uri: PackURI("/ppt/media/pad\(n).png"),
                                 contentType: ContentType.png, blob: Data())
        }
        #expect(throws: RostrumError.self) { _ = try deck.serializedData() }
    }

    @Test func anAbsurdlyLongPartNameIsReportedNotTrapped() throws {
        // ZipWriter's 0xFFFF name field is a precondition; the name can come
        // from a file somebody else wrote.
        let deck = try Presentation()
        let long = "/ppt/media/" + String(repeating: "a", count: 70_000) + ".png"
        deck.package.addPart(uri: PackURI(long), contentType: ContentType.png, blob: Data([1, 2, 3]))
        #expect(throws: RostrumError.self) { _ = try deck.serializedData() }
    }

    @Test func aRaggedForeignTableReportsRatherThanTrapping() throws {
        // columnCount reports what a:tblGrid declares. A table written
        // elsewhere can have a row with fewer a:tc than that, so the natural
        // reading idiom — for c in 0..<columnCount — used to abort the host.
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(
            rows: 2, columns: 3,
            frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(2)))
        // Strip a cell from the second row, leaving the grid claiming three.
        let tbl = table.tbl
        let secondRow = tbl.children(named: "a:tr")[1]
        let doomed = secondRow.children(named: "a:tc")[2]
        secondRow.removeChild(doomed)
        try deck.slides[0].part.markDirty()

        #expect(table.columnCount == 3)
        #expect(throws: RostrumError.self) { _ = try table.cell(1, 2) }
        // The cells that do exist still read.
        #expect(try table.cell(1, 1).text == "")
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
