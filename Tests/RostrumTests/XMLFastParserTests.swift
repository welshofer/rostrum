import Foundation
import Testing
@testable import Rostrum

/// `XMLFastParser` must build exactly the tree `XMLParser` builds, and must
/// decline every document `XMLParser` would reject or treat differently.
@Suite struct XMLFastParserTests {
    private func describe(_ node: XML.Node, into out: inout String) {
        switch node {
        case .element(let element):
            out += "E(\(element.name.debugDescription)"
            for attribute in element.attributes { out += " \(attribute.name.debugDescription)=\(attribute.value.debugDescription)" }
            out += "){"
            for child in element.children { describe(child, into: &out) }
            out += "}"
        case .text(let text): out += "T(\(text.debugDescription))"
        case .comment(let body): out += "C(\(body.debugDescription))"
        case .processingInstruction(let target, let data): out += "P(\(target.debugDescription),\(String(describing: data)))"
        }
    }

    /// A structural dump: node kinds, names, attribute order and exact text.
    private func describe(_ document: XML.Document) -> String {
        var out = ""
        for markup in document.prologue { describe(markup.node, into: &out) }
        describe(.element(document.root), into: &out)
        for markup in document.epilogue { describe(markup.node, into: &out) }
        return out
    }

    /// Fast result must equal the reference result whenever it is offered.
    private func check(_ data: Data, _ label: @autoclosure () -> String) -> Bool {
        guard let fast = XMLFastParser.parse(data) else { return false }
        guard let reference = try? XML.parseDocumentWithXMLParser(data) else {
            Issue.record("fast parser accepted a document XMLParser rejects: \(label())")
            return true
        }
        if describe(fast) != describe(reference) {
            Issue.record("fast parser built a different tree: \(label())")
        }
        return true
    }

    private func xmlParts() throws -> [(name: String, data: Data)] {
        var parts: [(String, Data)] = []
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/RealDecks")
        for url in try FileManager.default.contentsOfDirectory(at: fixtures, includingPropertiesForKeys: nil)
        where url.pathExtension == "pptx" {
            let zip = try ZipReader(data: Data(contentsOf: url))
            for name in zip.entryNames.sorted() where name.hasSuffix(".xml") || name.hasSuffix(".rels") {
                parts.append(("\(url.lastPathComponent)/\(name)", try zip.data(forEntry: name)))
            }
        }
        let generated = try Presentation()
        let zip = try ZipReader(data: generated.serializedData())
        for name in zip.entryNames.sorted() where name.hasSuffix(".xml") || name.hasSuffix(".rels") {
            parts.append(("generated/\(name)", try zip.data(forEntry: name)))
        }
        return parts
    }

    @Test func realPartsParseIdenticallyAndMostTakeTheFastPath() throws {
        let parts = try xmlParts()
        #expect(parts.count > 100)
        var accepted = 0
        for part in parts where check(part.data, part.name) { accepted += 1 }
        // Comments, processing instructions and xml: attributes are the
        // reasons a real part falls back; the rest must take the fast path.
        #expect(accepted * 10 >= parts.count * 9, "only \(accepted) of \(parts.count) parts took the fast path")
    }

    @Test func acceptedConstructsMatchTheReference() {
        let documents = [
            "<a/>", "<a></a>", "<a> </a>", "<a>\n\t</a>", "  <a/>\n",
            "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<p:sld xmlns:p=\"urn:p\" xmlns:a=\"urn:a\"><a:t>x</a:t></p:sld>",
            "<?xml version='1.0' encoding='utf-8'?><a/>",
            "<?xml version=\"1.0\"?><a/>",
            "<a z=\"1\" b=\"2\" xmlns:z=\"urn:z\" xmlns=\"urn:d\" xmlns:b=\"urn:b\" A=\"3\"/>",
            "<a b='single \"quoted\"' c=\"it's\"/>",
            "<a b = \"1\"  c\n=\n'2' />",
            "<a b=\"&lt;&gt;&amp;&quot;&apos;&#65;&#x42;&#x1F600;&#10;&#13;&#9;\"/>",
            "<a>&lt;&gt;&amp;&quot;&apos;&#65;&#x42;&#x1F600;&#13;&#10;</a>",
            "<a>one<b/>two<c>three</c> four </a>",
            "<a>caf\u{E9} \u{4E2D}\u{6587} \u{1F600} \u{80}\u{FFFD}</a>",
            "<a>]] > ]>  >></a>",
            "<a xml:space=\"preserve\"> x </a>",
            "<a-b.c_d1 e-f.g_h2=\"\"/>",
            "<a><b><c><d/></c></b></a >",
            "<a\n>\n</a\n>",
            "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\r\n<a b=\"1\"\r\n c=\"2\">\r\n</a>\r\n",
            "<a>one\r\ntwo\rthree\n\rfour\r</a>", "<a>\r</a>", "<a>&#13;\r&#13;\n</a>",
        ]
        for document in documents {
            #expect(check(Data(document.utf8), document), "expected the fast path for \(document.debugDescription)")
        }
    }

    @Test func everythingElseFallsBack() {
        let documents = [
            "", " ", "<a>", "<a></b>", "<a/><b/>", "<a/>x", "x<a/>", "<a b=\"1\" b=\"2\"/>",
            "<a b=1/>", "<a b/>", "<a b=\"<\"/>", "<a b=\"1\"c=\"2\"/>", "<a>&nbsp;</a>", "<a>&#0;</a>", "<a>&#xD800;</a>",
            "<a>&#X41;</a>", "<a>&amp</a>", "<a>&#;</a>", "<a>]]></a>", "<1a/>", "<a:/>", "<:a/>", "<a:b:c/>", "<-a/>",
            "<!-- c --><a/>", "<a><!-- c --></a>", "<a><![CDATA[x]]></a>", "<a><?pi data?></a>", "<?pi?><a/>",
            "<!DOCTYPE a><a/>", "<a b=\"x\ry\"/>", "<a b=\"x\ty\"/>", "<a b=\"x\ny\"/>", "\u{FEFF}<a/>",
            "<?xml version=\"1.1\"?><a/>", "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><a/>", "<?xml encoding=\"UTF-8\"?><a/>",
            "<a xmlns:b=\"\"/>", "<a xml:lang=\"en\"/>", "<a xml:space=\"keep\"/>", "<xml:a/>", "<a xmlns:xml=\"urn:x\"/>",
            "<caf\u{E9}/>", "<a caf\u{E9}=\"1\"/>", "<a>\u{1}</a>", "<a>\u{FFFE}</a>",
        ]
        for document in documents {
            #expect(XMLFastParser.parse(Data(document.utf8)) == nil, "expected a fallback for \(document.debugDescription)")
        }
        #expect(XMLFastParser.parse(Data([0x3C, 0x61, 0x3E, 0xC3, 0x28, 0x3C, 0x2F, 0x61, 0x3E])) == nil)   // invalid UTF-8
        #expect(XMLFastParser.parse(Data([0x3C, 0x61, 0x3E, 0xED, 0xA0, 0x80, 0x3C, 0x2F, 0x61, 0x3E])) == nil)   // surrogate
        let deep = String(repeating: "<a>", count: XML.maxDepth + 1) + String(repeating: "</a>", count: XML.maxDepth + 1)
        #expect(XMLFastParser.parse(Data(deep.utf8)) == nil)
        let allowed = String(repeating: "<a>", count: XML.maxDepth) + String(repeating: "</a>", count: XML.maxDepth)
        #expect(XMLFastParser.parse(Data(allowed.utf8)) != nil)
    }

    @Test func mutatedPartsNeverDisagreeWithTheReference() throws {
        // Deterministic mutations of real parts: whatever the fast parser
        // still accepts, XMLParser must accept and build identically.
        let insertions: [[UInt8]] = ["<", ">", "&", "\"", "'", "=", "/", ":", " ", "]]>", "&amp;", "&#x41;", "&#0;", "x",
                                     "</a>", "<b c=\"d\">", "xmlns:q=\"u\" ", "q:", "\u{E9}", "-", ".", "\r", "\r\n", "\n", "\t"].map { Array($0.utf8) }
        var state: UInt64 = 0x9E3779B97F4A7C15
        func next(_ bound: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) % UInt64(bound))
        }
        var accepted = 0, mutations = 0
        for part in try xmlParts() where part.data.count < 200_000 {
            let original = [UInt8](part.data)
            for round in 0..<48 {
                var bytes = original
                // Stay on character boundaries so the input remains UTF-8.
                func boundary() -> Int {
                    var index = next(bytes.count)
                    while index > 0, bytes[index] & 0xC0 == 0x80 { index -= 1 }
                    return index
                }
                switch round % 4 {
                case 0: bytes.insert(contentsOf: insertions[next(insertions.count)], at: boundary())
                case 1:
                    let index = boundary()
                    var end = index + 1
                    while end < bytes.count, bytes[end] & 0xC0 == 0x80 { end += 1 }
                    bytes.removeSubrange(index..<end)
                case 2: bytes.removeSubrange(boundary()...)
                default:
                    let index = boundary()
                    if bytes[index] < 0x80 { bytes[index] = insertions[next(insertions.count)][0] }
                }
                mutations += 1
                if check(Data(bytes), "\(part.name) mutation \(round)") { accepted += 1 }
            }
        }
        #expect(mutations > 1000)
        #expect(accepted > mutations / 20, "mutations should still exercise the fast path (\(accepted) of \(mutations))")
    }
}
