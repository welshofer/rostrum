import Foundation
import Testing
@testable import Rostrum

@Suite struct LigatureStyleInheritanceTests {
    private struct Span {
        let text: String
        let disabled: Bool
        let localStyle: String?
    }
    private func spans(_ element: XML.Element, inherited: Bool = false) -> [Span] {
        let style = element[attribute: "style"] ?? ""
        let disabled = style.contains("'liga' 0") ? true : (style.contains("font-feature-settings: normal") ? false : inherited)
        if element.name == "tspan" {
            return [Span(text: element.textContent, disabled: disabled, localStyle: element[attribute: "style"])]
        }
        return element.childElements.flatMap { spans($0, inherited: disabled) }
    }
    private func elements(_ name: String, in element: XML.Element) -> [XML.Element] {
        (element.name == name ? [element] : []) + element.childElements.flatMap { elements(name, in: $0) }
    }
    private func deck(paragraphs: String) throws -> Presentation {
        let deck = try Presentation()
        let font = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf")
        try deck.fonts.register(Data(contentsOf: font), aliases: ["Inherited Policy"])
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .points(400), height: .points(300)))
        let body = try XML.parse(Data("""
        <p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0"/><a:lstStyle>
        <a:defPPr><a:defRPr sz="1800"><a:latin typeface="Inherited Policy"/></a:defRPr></a:defPPr>
        </a:lstStyle>\(paragraphs)</p:txBody>
        """.utf8))
        try #require(shape.textFrame).txBody.children = body.children
        return deck
    }

    @Test func homogeneousBlockAndMixedParagraphsKeepEffectiveViewerPolicy() throws {
        let homogeneous = try deck(paragraphs: """
        <a:p><a:r><a:t>office</a:t></a:r><a:r><a:t> final</a:t></a:r></a:p>
        <a:p><a:r><a:t>waffle</a:t></a:r></a:p>
        """)
        let before = try homogeneous.serializedData()
        let first = try homogeneous.renderSVGReportingProblems(slideAt: 0)
        let xml = try XML.parse(Data(first.svg.utf8))
        #expect(spans(xml).map(\.text) == ["office", " final", "waffle"])
        #expect(spans(xml).allSatisfy { $0.disabled && $0.localStyle == nil })
        #expect(first.svg.components(separatedBy: "font-feature-settings").count - 1 == 1)
        #expect(elements("g", in: xml).filter { $0[attribute: "style"] != nil }.count == 1)
        #expect(first.problems.isEmpty)
        #expect(try homogeneous.serializedData() == before)
        #expect(try homogeneous.renderSVGReportingProblems(slideAt: 0).svg == first.svg)

        let empty = try deck(paragraphs: "<a:p/><a:p/>")
        let emptySVG = try empty.renderSVG(slideAt: 0)
        #expect(!emptySVG.contains("font-feature-settings"))
        #expect(spans(try XML.parse(Data(emptySVG.utf8))).isEmpty)

        let mixed = try deck(paragraphs: """
        <a:p/>
        <a:p><a:r><a:t>office</a:t></a:r><a:r><a:t> final</a:t></a:r></a:p>
        <a:p><a:r><a:t>office café</a:t></a:r></a:p>
        <a:p><a:pPr rtl="1"/><a:r><a:t>RTL office</a:t></a:r></a:p>
        <a:p><a:pPr><a:buChar char="ffi"/></a:pPr><a:r><a:t>café</a:t></a:r></a:p>
        """)
        let report = try mixed.renderSVGReportingProblems(slideAt: 0)
        let mixedXML = try XML.parse(Data(report.svg.utf8))
        let rendered = spans(mixedXML)
        #expect(rendered.map(\.text) == ["office", " final", "office café", "RTL office", "ffi ", "café"])
        #expect(rendered.map(\.disabled) == [true, true, false, false, false, false])
        #expect(elements("g", in: mixedXML).allSatisfy { $0[attribute: "style"] == nil })
        #expect(elements("text", in: mixedXML).filter { $0[attribute: "style"] != nil }.count == 1)
        #expect(!report.problems.isEmpty)
    }

    @Test func cacheSeparatesInheritedAndExplicitPoliciesAndRestoresGeneralDefaults() {
        let cache = RenderTextAttributes()
        var run = ResolvedTextRun(text: "office", fontFamily: nil, fontSize: 18,
            bold: false, italic: false, color: "#000000", tracking: 0)
        run.usesStandardLigatures = false
        let explicit = cache.attributes(for: run, family: nil)
        let inherited = cache.attributes(for: run, family: nil, inheritsDisabledStandardLigatures: true)
        #expect(explicit.contains("font-feature-settings: 'liga' 0"))
        #expect(!inherited.contains("font-feature-settings"))
        #expect(cache.attributes(for: run, family: nil) == explicit)
        run.usesStandardLigatures = true
        let restored = cache.attributes(for: run, family: nil, inheritsDisabledStandardLigatures: true)
        #expect(restored.contains("font-feature-settings: normal"))
        #expect(!cache.attributes(for: run, family: nil).contains("font-feature-settings"))
        #expect(cache.count == 4)
    }

    @Test func narrowTableTextBlocksAvoidRepeatedPolicyBytes() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 2, columns: 50,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(10), height: .points(3.6)))
        _ = table.setContents((0..<2).map { row in (0..<50).map { "R\(row) C\($0)" } })
        _ = table.styleBanded(style: deck.style).cellPadding(.points(4))
        let svg = try deck.renderSVG(slideAt: 0)
        let xml = try XML.parse(Data(svg.utf8))
        let rendered = spans(xml)
        let policyCount = svg.components(separatedBy: "font-feature-settings").count - 1
        let groups = elements("g", in: xml).filter { $0[attribute: "style"] != nil }.count
        #expect(rendered.count > 400)
        #expect(rendered.allSatisfy { $0.disabled && $0.localStyle == nil })
        #expect(policyCount == 100)
        // Previous output repeated this exact attribute on every span. Hoisting
        // adds seven wrapper bytes only for each multi-line text block.
        let attributeBytes = " style=\"font-feature-settings: 'liga' 0\"".utf8.count
        let savedBytes = (rendered.count - policyCount) * attributeBytes - groups * 7
        #expect(savedBytes > 10_000)
    }
}
