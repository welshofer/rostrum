import Foundation
import Testing
@testable import Rostrum

@Suite struct RenderTextAttributesTests {
    @Test func serializedStyleKeepsEveryVariantAndEscapesFontNames() throws {
        let cache = RenderTextAttributes()
        var run = ResolvedTextRun(text: "café 中文", fontFamily: "Unused", fontSize: 18,
            bold: false, italic: false, color: "#123456", tracking: 0)
        #expect(cache.attributes(for: run, family: "A&B") == " font-size=\"18\" fill=\"#123456\" font-family=\"A&amp;B, sans-serif\"")
        run.fontSize = 24.5; run.bold = true; run.italic = true
        run.color = "rgba(1,2,3,0.5)"; run.tracking = -0.25
        let attrs = cache.attributes(for: run, family: "Face \"Two\"")
        let element = try XML.parse(Data(("<tspan" + attrs + "/>").utf8))
        #expect(element[attribute: "font-size"] == "24.5000")
        #expect(element[attribute: "font-family"] == "Face \"Two\", sans-serif")
        #expect(element[attribute: "font-weight"] == "bold")
        #expect(element[attribute: "font-style"] == "italic")
        #expect(element[attribute: "letter-spacing"] == "-0.2500")
        #expect(element[attribute: "fill"] == "rgba(1,2,3,0.5)")
        #expect(!cache.attributes(for: run, family: nil).contains("font-family"))
        #expect(!cache.attributes(for: run, family: "").contains("font-family"))
    }

    @Test func retainedStylesAreBoundedAndResetBetweenRenders() {
        let cache = RenderTextAttributes()
        let run = ResolvedTextRun(text: "", fontFamily: nil, fontSize: 18,
            bold: false, italic: false, color: "#123456", tracking: 0)
        for i in 0..<256 { _ = cache.attributes(for: run, family: "Face \(i)") }
        #expect(cache.count <= 128)
        #expect(cache.retainedBytes <= 65_536)
        let large = String(repeating: "a", count: 100_000)
        #expect(cache.attributes(for: run, family: large).contains(large))
        #expect(cache.retainedBytes <= 65_536)
        cache.reset()
        #expect(cache.count == 0 && cache.retainedBytes == 0)
    }

    @Test func canonicallyEquivalentAliasesRetainTheirOriginalUTF8Spelling() {
        let cache = RenderTextAttributes()
        let run = ResolvedTextRun(text: "", fontFamily: nil, fontSize: 18,
            bold: false, italic: false, color: "#123456", tracking: 0)
        let composed = "Caf\u{00e9}", decomposed = "Cafe\u{0301}"
        #expect(composed == decomposed)
        let first = cache.attributes(for: run, family: composed)
        let second = cache.attributes(for: run, family: decomposed)
        #expect(!first.utf8.elementsEqual(second.utf8))
        #expect(second.utf8.elementsEqual(" font-size=\"18\" fill=\"#123456\" font-family=\"\(decomposed), sans-serif\"".utf8))
    }

    @Test func repeatedAndRevisitedStylesMatchUncachedSerializationByteForByte() {
        let base = ResolvedTextRun(text: "office café", fontFamily: nil, fontSize: 18,
            bold: false, italic: false, color: "#123456", tracking: 0)
        var variants: [(ResolvedTextRun, String?, Bool)] = [(base, "Café", false)]
        let changes: [(inout ResolvedTextRun) -> Void] = [
            { $0.fontSize = 31 }, { $0.bold = true }, { $0.italic = true },
            { $0.color = "#ABCDEF" }, { $0.tracking = -0.25 },
            { $0.decoration = " underline line-through" }, { $0.baselineShift = 30 },
            { $0.explicitlyDisablesKerning = true }, { $0.usesStandardLigatures = false },
        ]
        for change in changes {
            var run = base; change(&run)
            variants.append((run, "Café", false))
        }
        variants += [(base, "Cafe\u{0301}", false), (base, nil, false),
                     (base, "", false), (base, "A&B", false), (base, "Café", true)]
        let expected = variants.map { run, family, inherited in
            RenderTextAttributes().attributes(for: run, family: family,
                inheritsDisabledStandardLigatures: inherited)
        }
        let cache = RenderTextAttributes()
        // Repeat neighbors, then revisit older entries after different styles.
        for index in Array(variants.indices) + Array(variants.indices.reversed()) {
            let (run, family, inherited) = variants[index]
            for _ in 0..<2 {
                let result = cache.attributes(for: run, family: family,
                    inheritsDisabledStandardLigatures: inherited)
                #expect(result.utf8.elementsEqual(expected[index].utf8))
            }
        }
    }

    @Test func refusedStylesCannotReturnRecentValuesAndResetReadmitsTheLastStyle() {
        let cache = RenderTextAttributes()
        var run = ResolvedTextRun(text: "", fontFamily: nil, fontSize: 18,
            bold: false, italic: false, color: "#123456", tracking: 0)
        for index in 0..<128 { _ = cache.attributes(for: run, family: "Face \(index)") }
        let retained = cache.retainedBytes
        let large = String(repeating: "x", count: 100_000)
        run.fontSize = 42
        let expected = " font-size=\"42\" fill=\"#123456\" font-family=\"\(large), sans-serif\""
        for _ in 0..<2 {
            #expect(cache.attributes(for: run, family: large).utf8.elementsEqual(expected.utf8))
        }
        #expect(cache.count == 128 && cache.retainedBytes == retained)
        run.fontSize = 18
        let admitted = cache.attributes(for: run, family: "Face 127")
        cache.reset()
        #expect(cache.count == 0 && cache.retainedBytes == 0)
        #expect(cache.attributes(for: run, family: "Face 127") == admitted)
        #expect(cache.count == 1 && cache.retainedBytes > 0)
    }

    @Test func cachedTextStylesDoNotHideChangesOrPerShapeDiagnostics() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        for index in 0..<2 {
            let shape = try slide.shapes.addTextBox(Rect(x: .inches(Double(index)), y: .zero,
                width: .inches(2), height: .inches(1)))
            shape.textFrame?.text = "Text & <markup> café 中文"
            shape.textFrame?.paragraphs[0].runs[0].fontName = "Missing & Face"
        }
        let renderer = SVGRenderer(slidePart: slide.part, slideSize: deck.slideSize,
            theme: slide.resolvedTheme, package: deck.package, fonts: deck.fonts, slideNumber: 1)
        let first = try renderer.render(pixelWidth: 640)
        #expect(first.problems.fidelityIssues.filter { $0.code == .viewerFontDependency }.count == 2)
        #expect(first.svg.contains("Missing &amp; Face"))
        _ = try XML.parse(Data(first.svg.utf8))
        let text = try #require(slide.shapes[0].textFrame)
        text.paragraphs[0].runs[0].bold = true
        text.paragraphs[0].runs[0].fontSize = 31
        let before = try deck.serializedData()
        let changed = try renderer.render(pixelWidth: 640)
        let fresh = try deck.renderSVGReportingProblems(slideAt: 0, pixelWidth: 640)
        #expect(changed.svg != first.svg)
        #expect(changed.svg == fresh.svg && changed.problems == fresh.problems)
        #expect(try deck.serializedData() == before)
    }
}
