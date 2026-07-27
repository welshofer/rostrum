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
        return try writer.finalize()
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
        // The fixture must actually produce the duplicate this test is named
        // for, or it proves nothing: with every sldId unresolvable, both
        // sections now report the same start slide.
        let startsBefore = try deck.sections.boundaries().map(\.startSlide)
        #expect(startsBefore.count > Set(startsBefore).count,
                "fixture did not create duplicate section starts: \(startsBefore)")

        // Adding another must not abort, and must succeed — a `try?` here
        // would pass whether the call worked or threw.
        let added = try deck.sections.add("Two", startingAtSlide: 1)
        #expect(added.name == "Two")
        // What gets written must satisfy set(_:)'s own rule.
        let startsAfter = try deck.sections.boundaries().map(\.startSlide)
        #expect(startsAfter == startsAfter.sorted())
        #expect(startsAfter.count == Set(startsAfter).count)
    }

    @Test func tooManyPartsIsReportedNotTrapped() throws {
        // ZipWriter's 0xFFFF entry ceiling is a precondition. A deck can carry
        // that many parts, and saving one you just opened must not abort.
        let deck = try Presentation()
        let before = deck.package.parts.count
        // Land exactly on the ceiling rather than far past it, so the check is
        // exercised at its boundary — the place an off-by-one would hide.
        while deck.package.parts.count + 2 <= 0xFFFF {
            let n = deck.package.parts.count
            deck.package.addPart(uri: PackURI("/ppt/media/pad\(n).png"),
                                 contentType: ContentType.png, blob: Data())
        }
        #expect(deck.package.parts.count > before)
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

    /// A table whose grid claims three columns while its second row has two.
    private func raggedTable(_ deck: Presentation) throws -> Table {
        let table = try deck.slides[0].shapes.addTable(
            rows: 2, columns: 3,
            frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(2)))
        let secondRow = table.tbl.children(named: "a:tr")[1]
        secondRow.removeChild(secondRow.children(named: "a:tc")[2])
        try deck.slides[0].part.markDirty()
        return table
    }

    @Test func bulkStylingSkipsCellsARaggedRowDoesNotHave() throws {
        // header/styleBanded/cellPadding all iterate 0..<columnCount. The
        // tolerant branch each gained had no test that reached it.
        let deck = try Presentation()
        let table = try raggedTable(deck)
        let style = deck.style
        table.header(style: style)
        table.styleBanded(style: style)
        table.cellPadding(.points(4))
        // The cells that exist are styled; the missing one is simply absent.
        #expect(try table.cell(1, 1).tc.firstChild(named: "a:tcPr") != nil)
        #expect(throws: RostrumError.self) { _ = try table.cell(1, 2) }
        #expect(try deck.validate().isEmpty)
    }

    @Test func styleBandedOnAZeroRowTableDoesNotBuildABackwardsRange() throws {
        // With a header, the loop starts at 1; a zero-row table made that
        // 1..<0, which is a trap rather than an empty range.
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(
            rows: 1, columns: 1,
            frame: Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
        table.tbl.removeChildren(named: "a:tr")
        try deck.slides[0].part.markDirty()
        #expect(table.rowCount == 0)
        table.styleBanded(style: deck.style)
    }

    @Test func aRefusedMergeLeavesTheTableExactlyAsItWas() throws {
        // merge destroys covered cells' text as it goes. Throwing part-way
        // through would leave a half-merged table with text already gone.
        let deck = try Presentation()
        let table = try raggedTable(deck)
        try table.cell(0, 0).text = "keep me"
        let before = table.tbl.serialized()

        #expect(throws: RostrumError.self) {
            try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 3)
        }
        #expect(table.tbl.serialized() == before, "a refused merge must change nothing")
        #expect(try table.cell(0, 0).text == "keep me")
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

    // MARK: - Aggregate decompression budget

    /// An archive whose entries are individually modest but collectively large:
    /// `count` entries of `each` zero bytes, which DEFLATE crushes to almost
    /// nothing. This is the shape a per-entry bound cannot see.
    private func amplifyingArchive(count: Int, each: Int) throws -> Data {
        var writer = ZipWriter()
        let payload = Data(repeating: 0, count: each)
        for i in 0..<count {
            writer.addFile(name: "ppt/media/pad\(i).bin", data: payload)
        }
        return try writer.finalize()
    }

    /// Rewrite every central-directory `uncompressed size` field to `value`.
    /// Reaching the 32-bit ceiling with real data would need gigabytes; the
    /// declared size is what the guard reads, so declare it directly.
    private func declaringUncompressedSize(_ value: UInt32, in archive: Data) throws -> Data {
        var bytes = [UInt8](archive)
        // Walk the central directory from the offset the EOCD records, rather
        // than scanning the whole file for the signature — those four bytes can
        // occur inside a compressed payload, and patching one would corrupt it.
        func u16(_ at: Int) -> Int { Int(bytes[at]) | (Int(bytes[at + 1]) << 8) }
        func u32(_ at: Int) -> Int {
            (0..<4).reduce(0) { $0 | (Int(bytes[at + $1]) << (8 * $1)) }
        }
        let eocd = bytes.count - 22                    // our writer emits no comment
        try #require(u32(eocd) == 0x0605_4B50)
        var offset = u32(eocd + 16)
        for _ in 0..<u16(eocd + 10) {
            try #require(u32(offset) == 0x0201_4B50)
            for b in 0..<4 {                           // field at central header + 24
                bytes[offset + 24 + b] = UInt8(truncatingIfNeeded: value >> (8 * UInt32(b)))
            }
            offset += 46 + u16(offset + 28) + u16(offset + 30) + u16(offset + 32)
        }
        return Data(bytes)
    }

    @Test func anArchiveOverTheReadBudgetIsRefused() throws {
        // 16 entries x 128 KB of zeros: 2 MB declared from a few kilobytes of
        // archive. Each entry is well within its own declared size, so nothing
        // per-entry can object — only the sum can.
        let bomb = try amplifyingArchive(count: 16, each: 128 * 1024)
        #expect(bomb.count < 128 * 1024, "fixture did not amplify: \(bomb.count) bytes on disk")

        let declared = 16 * 128 * 1024
        let generous = try ZipReader(data: bomb, limits: .init(totalUncompressedBytes: declared))
        #expect(generous.declaredUncompressedSize == UInt64(declared))

        // One byte under the declared total must refuse: the ceiling is
        // inclusive, so this pins the boundary rather than just "some big number
        // is rejected".
        #expect(throws: RostrumError.self) {
            _ = try ZipReader(data: bomb, limits: .init(totalUncompressedBytes: declared - 1))
        }
        // And the default is still unlimited — a large deck must keep opening.
        let unbounded = try ZipReader(data: bomb)
        #expect(unbounded.declaredUncompressedSize == UInt64(declared))
    }

    @Test func theBudgetIsCheckedBeforeAnythingIsInflated() throws {
        // Corrupt every entry's payload, then read it two ways. Without a budget
        // the failure must come from DEFLATE — proving the data really is
        // unreadable. With a budget the SAME archive must fail earlier, at the
        // declared total, without touching the streams.
        var bomb = [UInt8](try amplifyingArchive(count: 8, each: 64 * 1024))
        // Damage only the first entry's payload, at a byte the layout puts there
        // for certain: 30-byte local header + an 18-byte name. Blanket-corrupting
        // a range could reach the central directory and make the reader fail to
        // construct, which would test the wrong thing.
        let firstPayload = 30 + "ppt/media/pad0.bin".utf8.count
        for i in firstPayload..<(firstPayload + 8) { bomb[i] ^= 0xFF }
        let corrupt = Data(bomb)

        let unlimited = try ZipReader(data: corrupt)
        var inflateFailed = false
        for name in unlimited.entryNames {
            if (try? unlimited.data(forEntry: name)) == nil { inflateFailed = true }
        }
        #expect(inflateFailed, "fixture is not corrupt, so this proves nothing")

        // The budget rejects at construction, where no entry has been decoded.
        #expect(throws: RostrumError.self) {
            _ = try ZipReader(data: corrupt, limits: .init(totalUncompressedBytes: 1024))
        }
    }

    @Test func theDeclaredTotalCannotOverflowTheAccumulator() throws {
        // Sizes come from the file. 0xFFFFFFFE is the largest an entry may
        // declare (0xFFFFFFFF is the zip64 sentinel and is rejected), and enough
        // entries declaring it pass what a 32-bit accumulator would hold — the
        // arithmetic that bounds hostile input must not itself overflow.
        let small = try amplifyingArchive(count: 8, each: 64)
        let huge = try declaringUncompressedSize(0xFFFF_FFFE, in: small)

        let reader = try ZipReader(data: huge)          // must not trap
        #expect(reader.declaredUncompressedSize == 8 * UInt64(0xFFFF_FFFE))
        #expect(reader.declaredUncompressedSize > UInt64(UInt32.max))

        #expect(throws: RostrumError.self) {
            _ = try ZipReader(data: huge, limits: .init(totalUncompressedBytes: 1 << 30))
        }
    }

    @Test func aBudgetedPresentationOpensAnOrdinaryDeck() throws {
        // The budget must not get in the way of a real deck: a normal
        // presentation opens under a modest ceiling and reads back intact.
        let bytes = try validDeckBytes()
        // Compare against an unbudgeted open of the same bytes rather than a
        // hardcoded count: the property under test is that setting a budget
        // changes nothing, and a literal here would only track the fixture.
        let reference = try Presentation(data: bytes)
        let deck = try Presentation(data: bytes, limits: .init(totalUncompressedBytes: 64 << 20))
        #expect(deck.slides.count == reference.slides.count)
        #expect(deck.slides.count > 0, "fixture has no slides, so this proves nothing")
        // Comparing the two serializations rather than comparing to `bytes`
        // isolates the budget: both decks came from the same input, so any
        // normalisation on open applies to each equally and cannot make this
        // fail for a reason that has nothing to do with limits.
        let budgeted = try deck.serializedData()
        let plain = try reference.serializedData()
        #expect(budgeted == plain, "setting a budget changed what was read")
        #expect(throws: RostrumError.self) {
            _ = try Presentation(data: bytes, limits: .init(totalUncompressedBytes: 1))
        }
    }
}
