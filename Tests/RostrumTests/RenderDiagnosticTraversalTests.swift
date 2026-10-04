import Foundation
import Testing
@testable import Rostrum

@Suite struct RenderDiagnosticTraversalTests {
    @Test func markupDoesNotChangeOrderedPathsOrHideMalformedDescendants() throws {
        let deck = try Presentation(), owner = try deck.slides[0].part
        let shape = XML.Element("p:sp", children: [
            .element(XML.Element("p:nvSpPr", children: [
                .element(XML.Element("p:cNvPr", attributes: [("id", "42")]))
            ])),
            // Even a nominal text leaf must expose malformed nested elements.
            .element(XML.Element("unknown", children: [
                .element(XML.Element("a:t", children: [
                    .element(XML.Element("a:pattFill"))
                ]))
            ])),
            .element(XML.Element("unknown", children: [
                // Each leaf reports its own issue before its single opaque
                // child is ignored. Repeated names retain distinct indices.
                .element(XML.Element("a:pattFill", children: [.text("payload")])),
                .element(XML.Element("a:pattFill", children: [.comment("preserved")])),
                .element(XML.Element("a:pattFill", children: [
                    .processingInstruction(target: "keep", data: "value")
                ]))
            ])),
            // Inline styles are inspected separately after region selection;
            // this subtree must stay excluded in both child-count branches.
            .element(XML.Element("a:tblPr", children: [
                .element(XML.Element("a:tableStyle", children: [
                    .element(XML.Element("a:pattFill"))
                ]))
            ]))
        ])
        let interleaved = shape.deepCopy()
        var pending = [interleaved]
        while let element = pending.popLast() {
            pending.append(contentsOf: element.childElements)
            var children: [XML.Node] = [.text("before"), .comment("leading")]
            for child in element.children {
                children.append(child)
                children.append(.processingInstruction(target: "keep", data: nil))
                children.append(.text("between"))
                children.append(.comment("trailing"))
            }
            element.children = children
        }

        let expectedPaths = [
            "/p:sp[3]/unknown[1]/a:t[1]/a:pattFill[1]",
            "/p:sp[3]/unknown[2]/a:pattFill[1]",
            "/p:sp[3]/unknown[2]/a:pattFill[2]",
            "/p:sp[3]/unknown[2]/a:pattFill[3]",
        ]
        let expected = expectedPaths.map { path in
            FidelityIssue(code: .unsupportedFill, impact: .omission,
                location: FidelityLocation(slideIndex: 2, partURI: owner.uri.description,
                    shapeID: "42", path: path),
                message: "Pattern fill is not rendered in this shape path.")
        }
        var reports: [[FidelityIssue]] = []
        for variant in [shape, interleaved] {
            let before = XML.document(variant)
            let collector = RenderDiagnosticCollector()
            collector.inspect(variant, owner: owner, slideIndex: 2, path: "/p:sp[3]", package: deck.package)
            #expect(collector.issues == expected)
            #expect(collector.issues.map(\.location.path) == expectedPaths)
            #expect(XML.document(variant) == before)
            reports.append(collector.issues)
        }
        #expect(reports[0] == reports[1])
    }
}
