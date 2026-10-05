import Foundation
import Testing
@testable import Rostrum

@Suite struct ShapeImageOwnerTests {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/NativeShapeImageOwners") }
    private func image(_ name: String) throws -> Data { try Data(contentsOf: root.appendingPathComponent(name + ".png")) }
    private func deck(_ name: String) throws -> Presentation { try Presentation(data: Data(contentsOf: root.appendingPathComponent(name + ".pptx"))) }
    private func images(_ svg: String) throws -> [Data] {
        let xml = try XML.parse(Data(svg.utf8))
        var result: [Data] = []
        func visit(_ node: XML.Element) {
            if node.name == "image", let href = node[attribute: "href"], let comma = href.firstIndex(of: ","),
               let bytes = Data(base64Encoded: String(href[href.index(after: comma)...])) { result.append(bytes) }
            for child in node.childElements { visit(child) }
        }
        visit(xml); return result
    }
    @Test func selectedThemeAndInheritedDirectResourcesRetainTheirOwners() throws {
        let red = try image("theme-red"), blue = try image("slide-blue")
        let cases: [(String, [Data])] = [("theme-collision", [red]), ("theme-missing-slide-id", [red]),
            ("direct-slide-control", [blue]), ("native-theme-image-owners-v1", [blue, blue, red, red])]
        for (name, expected) in cases {
            let deck = try deck(name), saved = try deck.serializedData()
            let first = try deck.renderSVGReportingProblems(slideAt: 0), second = try deck.renderSVGReportingProblems(slideAt: 0)
            #expect(try images(first.svg) == expected, "Selected resources: \(name)")
            #expect(first.svg == second.svg && first.problems == second.problems)
            #expect(first.problems.fidelityIssues.isEmpty)
            #expect(try deck.serializedData() == saved)
            let reopened = try Presentation(data: saved).renderSVGReportingProblems(slideAt: 0)
            #expect(reopened.svg == first.svg && reopened.problems == first.problems)
        }
    }
    @Test func selectedThemeImageDiagnosticsUseThemeOwnerAndIgnoreUnusedEntries() throws {
        for mode in ["missing", "external", "unsupported"] {
            let deck = try deck("theme-collision"), slide = try deck.slides[0], theme = deck.theme.part
            let original = try #require(theme.rels.relationship(withId: "rIdOwnerProbe"))
            if mode == "unsupported" {
                let part = try deck.package.part(at: PackURI.resolve(target: original.target, relativeTo: theme.uri.baseURI))
                part.replaceBlob(Data([1, 2, 3]))
            } else {
                theme.rels.setItems(theme.rels.items.filter { $0.rId != original.rId } + (mode == "external" ? [Relationship(rId: original.rId, type: RelType.image, target: "https://example.invalid/image.png", isExternal: true)] : []))
            }
            let saved = try deck.serializedData(), result = try deck.renderSVGReportingProblems(slideAt: 0)
            #expect(try images(result.svg).isEmpty)
            let issues = result.problems.fidelityIssues.filter { $0.code == (mode == "unsupported" ? .unsupportedImage : .unavailableImage) }
            #expect(issues.count == 1)
            #expect(issues.first?.location.partURI == theme.uri.value)
            #expect(issues.first?.location.path.contains("fillRef") == true)
            #expect(try deck.serializedData() == saved)
            let shape = try #require(slide.shapes.all.first)
            shape.element.firstChild(named: "p:spPr")?.appendElement(XML.Element("a:noFill")); slide.part.markDirty()
            let suppressed = try deck.renderSVGReportingProblems(slideAt: 0)
            #expect(try images(suppressed.svg).isEmpty && suppressed.problems.fidelityIssues.isEmpty)
        }
    }
    @Test func reusedRendererObservesThemeRetargetingAndDirectOverrides() throws {
        let deck = try deck("theme-collision"), slide = try deck.slides[0]
        let red = try image("theme-red"), blue = try image("slide-blue")
        let renderer = SVGRenderer(slidePart: slide.part, slideSize: deck.slideSize,
            theme: slide.resolvedTheme, package: deck.package, fonts: deck.fonts, slideNumber: 1)
        let original = try renderer.render(pixelWidth: 640)
        #expect(try images(original.svg) == [red])
        let theme = deck.theme.part, relationships = theme.rels.items
        theme.rels.setItems(relationships.map { relationship in
            relationship.rId == "rIdOwnerProbe" ? Relationship(rId: relationship.rId, type: RelType.image, target: "../media/probe-blue.png", isExternal: false) : relationship
        })
        #expect(try images(renderer.render(pixelWidth: 640).svg) == [blue])
        theme.rels.setItems(relationships)
        let shape = try #require(slide.shapes.all.first)
        let properties = try #require(shape.element.firstChild(named: "p:spPr"))
        properties.appendElement(XML.Element("a:noFill")); slide.part.markDirty()
        #expect(try images(renderer.render(pixelWidth: 640).svg).isEmpty)
        properties.removeChildren(named: "a:noFill")
        properties.appendElement(Fill.blipFill(rId: "rIdOwnerProbe", fit: .stretch)); slide.part.markDirty()
        #expect(try images(renderer.render(pixelWidth: 640).svg) == [blue])
        properties.removeChildren(named: "a:blipFill"); slide.part.markDirty()
        let restored = try renderer.render(pixelWidth: 640)
        #expect(restored.svg == original.svg && restored.problems == original.problems)
        let before = try deck.serializedData()
        let reference = try #require(shape.element.firstChild(named: "p:style")?.firstChild(named: "a:fillRef"))
        for value in ["0", "1000", "999999", "invalid"] {
            reference[attribute: "idx"] = value
            #expect(try images(renderer.render(pixelWidth: 640).svg).isEmpty)
        }
        reference[attribute: "idx"] = "1"
        #expect(try deck.serializedData() == before)
    }

    @Test func inheritedFurnitureThemeSelectionDoesNotUseItsDirectOwner() throws {
        let deck = try deck("native-theme-image-owners-v1"), slide = try deck.slides[0]
        let red = try image("theme-red")
        for owner in slide.inheritanceParts.dropFirst() {
            for shape in try Slide.spTree(of: owner).children(named: "p:sp") {
                shape.firstChild(named: "p:spPr")?.removeChildren(named: "a:blipFill")
            }
            owner.markDirty()
        }
        let saved = try deck.serializedData(), result = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(try images(result.svg) == [red, red, red, red])
        #expect(result.problems.fidelityIssues.isEmpty)
        #expect(try deck.serializedData() == saved)
        #expect(try Presentation(data: saved).renderSVG(slideAt: 0) == result.svg)
    }

    private struct NativeReference: Decodable {
        struct Paint: Decodable { let frame: [Double]; let rgb: [Int]; let pixels: [Int] }
        let imagePaint: [Paint]
    }
    @Test func nativeImagePayloadsAndFinitePlacementMatchEveryCapturedRectangle() throws {
        let sources = [("theme-collision", "theme-collision"), ("theme-missing-slide-id", "theme-missing-slide-id"),
            ("direct-slide-control", "direct-slide-control"), ("native-theme-image-owners-v1", "background-and-inherited")]
        for (source, reference) in sources {
            let native = try JSONDecoder().decode(NativeReference.self,
                from: Data(contentsOf: root.appendingPathComponent(reference + "/native-images.json")))
            let rendered = try deck(source).renderSVGReportingProblems(slideAt: 0)
            let svg = try XML.parse(Data(rendered.svg.utf8))
            let patterns = try #require(svg.firstChild(named: "defs")).children(named: "pattern")
            #expect(patterns.count == native.imagePaint.count)
            for (pattern, expected) in zip(patterns, native.imagePaint) {
                #expect(expected.frame.count == 4 && expected.pixels == [2, 2])
                let x = try #require(pattern[attribute: "x"].flatMap(Double.init)) / 12700
                let y = try #require(pattern[attribute: "y"].flatMap(Double.init)) / 12700
                let w = try #require(pattern[attribute: "width"].flatMap(Double.init)) / 12700
                let h = try #require(pattern[attribute: "height"].flatMap(Double.init)) / 12700
                let bounds = [x, y, x + w, y + h]
                for (actual, target) in zip(bounds, expected.frame) { #expect(abs(actual - target) < 0.001) }
                let content = try #require(pattern.firstChild(named: "g")?.firstChild(named: "image"))
                #expect(content[attribute: "x"].flatMap(Double.init) == 0 && content[attribute: "y"].flatMap(Double.init) == 0)
                #expect(content[attribute: "width"].flatMap(Double.init) == w * 12700)
                #expect(content[attribute: "height"].flatMap(Double.init) == h * 12700)
                let payload = try image(expected.rgb == [255, 0, 0] ? "theme-red" : "slide-blue")
                #expect(expected.rgb == [255, 0, 0] || expected.rgb == [0, 0, 255])
                #expect(content[attribute: "href"] == "data:image/png;base64," + payload.base64EncodedString())
                let id = try #require(pattern[attribute: "id"])
                let painted = svg.children(named: "rect").filter { $0[attribute: "fill"] == "url(#" + id + ")" }
                #expect(painted.count == 1)
                if let rect = painted.first {
                    for key in ["x", "y", "width", "height"] { #expect(rect[attribute: key] == pattern[attribute: key]) }
                }
            }
            #expect(rendered.problems.fidelityIssues.isEmpty)
        }
    }

}
