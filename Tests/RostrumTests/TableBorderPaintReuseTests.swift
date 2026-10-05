import Foundation
import Testing
@testable import Rostrum

@Suite struct TableBorderPaintReuseTests {
    @Test func admittedOwnersRetainIdentityIncludingNoneAndBoundEntries() {
        var cache: TableBorderPaintCache<String>? = TableBorderPaintCache(limit: 2)
        var first: XML.Element? = XML.Element("line", attributes: [("value", "first")])
        weak var owner = first
        let none = XML.Element("none"), overflow = XML.Element("overflow")
        var decodes = 0
        func decode(_ line: XML.Element) -> String? {
            decodes += 1
            return line[attribute: "value"]
        }
        for _ in 0..<3 {
            #expect(cache?.value(for: first, canReuse: { _ in true }, decode: decode) == "first")
            #expect(cache?.value(for: none, canReuse: { _ in true }, decode: decode) == nil)
        }
        #expect(decodes == 2)
        first = nil
        #expect(owner != nil)
        _ = cache?.value(for: overflow, canReuse: { _ in true }, decode: decode)
        overflow[attribute: "value"] = "live"
        #expect(cache?.value(for: overflow, canReuse: { _ in true }, decode: decode) == "live")
        #expect(decodes == 4)
        cache = nil
        #expect(owner == nil)
    }

    private func style(_ body: String) throws -> XML.Element {
        try XML.parse(Data("<a:tblStyle xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" styleId=\"{20200000-0000-4000-8000-000000000020}\" styleName=\"Paint reuse\"><a:wholeTbl><a:tcStyle><a:tcBdr>\(body)</a:tcBdr></a:tcStyle></a:wholeTbl></a:tblStyle>".utf8))
    }
    private func deck(_ line: String, size: Int = 6) throws -> (Presentation, Table) {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: size, columns: size,
            frame: Rect(x: .points(30), y: .points(30), width: .points(240), height: .points(240)))
        let borders = ["left", "right", "top", "bottom", "insideH", "insideV"].map { "<a:\($0)>\(line)</a:\($0)>" }.joined()
        try table.setStyleDefinition(style(borders))
        return (deck, table)
    }

    @Test func directAndOversizeNodesNeverEnterSharedReuse() throws {
        let (deck, table) = try deck("<a:ln w=\"25400\"><a:solidFill><a:srgbClr val=\"123456\"/></a:solidFill></a:ln>")
        try table.cell(2, 2).setBorder(.left, line: Line(color: .black, width: .points(3)))
        var session = TableStyleResolver.RenderSession(TableStyleResolver(table: table, theme: deck.theme))
        let shared = try #require(session.effective(row: 1, column: 1).properties.firstChild(named: "a:lnL"))
        #expect(session.ownsSharedBorder(shared))
        let direct = try #require(session.effective(row: 2, column: 2).properties.firstChild(named: "a:lnL"))
        #expect(!session.ownsSharedBorder(direct))
        var cache = TableBorderPaintCache<String>()
        var decodes = 0
        func decode(_ line: XML.Element) -> String? { decodes += 1; return line[attribute: "w"] }
        #expect(cache.value(for: direct, canReuse: session.ownsSharedBorder, decode: decode) == "38100")
        direct[attribute: "w"] = "50800"
        #expect(cache.value(for: direct, canReuse: session.ownsSharedBorder, decode: decode) == "50800")
        #expect(decodes == 2)
        let huge = "<a:ln><a:noFill/><a:extLst><!--" + String(repeating: "x", count: 1_100_000) + "--></a:extLst></a:ln>"
        try table.setStyleDefinition(style("<a:left>\(huge)</a:left>"))
        session = TableStyleResolver.RenderSession(TableStyleResolver(table: table, theme: deck.theme))
        let oversized = try #require(session.effective(row: 0, column: 0).properties.firstChild(named: "a:lnL"))
        #expect(!session.ownsSharedBorder(oversized))
        let before = try deck.serializedData()
        _ = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(try deck.serializedData() == before)
    }

    @Test func sharedPaintExactlyMatchesUncachedDirectPaint() throws {
        for attributes in ["w=\"12700\"", "w=\"25400\" cmpd=\"dbl\"", "w=\"1524000\""] {
            for fill in ["<a:noFill/>", "", "<a:solidFill><a:schemeClr val=\"accent1\"><a:alpha val=\"45000\"/></a:schemeClr></a:solidFill>", "<a:solidFill><a:srgbClr val=\"123456\"/></a:solidFill><a:prstDash val=\"dash\"/>"] {
                let (deck, table) = try deck("<a:ln \(attributes)>\(fill)</a:ln>")
                let expected = try deck.renderSVGReportingProblems(slideAt: 0)
                // Materialize equivalent direct paint in this owned test deck.
                // Those copied nodes bypass template reuse, including maximum
                // width admission, none, alpha, dash and supported double lines.
                let resolver = TableStyleResolver(table: table, theme: deck.theme)
                for row in 0..<6 { for column in 0..<6 {
                    let effective = resolver.effective(row: row, column: column)
                    let cell = try table.cell(row, column)
                    cell.tc.removeChildren(named: "a:tcPr")
                    cell.tc.appendElement(effective.properties.deepCopy())
                } }
                table.part.markDirty()
                let direct = try deck.renderSVGReportingProblems(slideAt: 0)
                let samePaint = direct.svg == expected.svg
                #expect(samePaint)
                // Materializing unsupported declarations changes their source
                // locations and multiplicity. Preserve each input's diagnostics
                // exactly across reopen; cross-version proof uses identical input.
                let saved = try deck.serializedData()
                let reopened = try Presentation(data: saved).renderSVGReportingProblems(slideAt: 0)
                #expect(reopened.problems.fidelityIssues == direct.problems.fidelityIssues)
                #expect(reopened.problems.unsupportedContent == direct.problems.unsupportedContent)
                let repeated = try deck.renderSVGReportingProblems(slideAt: 0)
                #expect(repeated.problems.fidelityIssues == direct.problems.fidelityIssues)
                #expect(try deck.serializedData() == saved)
            }
        }
    }
    @Test func reusedRendererSeesAliasedStyleThemeAndDirectEdits() throws {
        let (deck, table) = try deck("<a:ln w=\"25400\"><a:solidFill><a:schemeClr val=\"accent1\"/></a:solidFill></a:ln>")
        let slide = try deck.slides[0]
        let renderer = SVGRenderer(slidePart: slide.part, slideSize: deck.slideSize,
            theme: slide.resolvedTheme, package: deck.package, fonts: deck.fonts, slideNumber: 1)
        let initial = try renderer.render(pixelWidth: 640)
        let alias = try #require((slide.shapes.first { $0 is TableFrame } as? TableFrame)?.table)
        deck.theme.setAccent(1, Color("987654"))
        try alias.cell(1, 1).setBorder(.bottom, line: Line(color: .black, width: .points(4)))
        let part = try #require(TableStyleResolver(table: alias, theme: deck.theme).stylePart)
        let definition = try #require(try part.dom().childElements.first { $0[attribute: "styleId"] == table.styleID })
        let line = try #require(definition.firstChild(named: "a:wholeTbl")?.firstChild(named: "a:tcStyle")?
            .firstChild(named: "a:tcBdr")?.firstChild(named: "a:left")?.firstChild(named: "a:ln"))
        line[attribute: "w"] = "63500"; part.markDirty()
        let before = try deck.serializedData()
        let changed = try renderer.render(pixelWidth: 640)
        let fresh = try deck.renderSVGReportingProblems(slideAt: 0, pixelWidth: 640)
        let same = changed.svg == fresh.svg
        #expect(same && changed.svg != initial.svg)
        #expect(changed.problems.fidelityIssues == fresh.problems.fidelityIssues)
        #expect(changed.svg.contains("#987654") && changed.svg.contains("stroke-width=\"63500\""))
        #expect(try deck.serializedData() == before)
    }

}
