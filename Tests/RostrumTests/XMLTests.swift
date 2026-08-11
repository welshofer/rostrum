import Foundation
import Testing
@testable import Rostrum

@Suite("XMLTests")
struct XMLTests {

    // MARK: - Helpers

    private func parse(_ xml: String) throws -> XML.Element {
        try XML.parse(Data(xml.utf8))
    }

    private func normalized(_ xml: String) throws -> String {
        try parse(xml).serialized()
    }

    private func expectMalformed(_ xml: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(sourceLocation: sourceLocation) {
            try self.parse(xml)
        } throws: { error in
            guard let rostrumError = error as? RostrumError,
                  case .xmlMalformed = rostrumError else { return false }
            return true
        }
    }

    // MARK: - Basic parsing

    @Test func parsesSimpleElement() throws {
        let root = try parse("<a/>")
        #expect(root.name == "a")
        #expect(root.attributes.isEmpty)
        #expect(root.children.isEmpty)
    }

    @Test func parsesNestedElementsAndText() throws {
        let root = try parse("<a><b>hello</b><c/></a>")
        #expect(root.name == "a")
        #expect(root.childElements.count == 2)
        #expect(root.childElements[0].name == "b")
        #expect(root.childElements[0].textContent == "hello")
        #expect(root.childElements[1].name == "c")
    }

    @Test func qualifiedNamesKeptVerbatim() throws {
        let root = try parse(#"<p:sld xmlns:p="urn:p"><p:cSld/></p:sld>"#)
        #expect(root.name == "p:sld")
        #expect(root[attribute: "xmlns:p"] == "urn:p")
        #expect(root.childElements[0].name == "p:cSld")
    }

    @Test func cdataBecomesOrdinaryTextNode() throws {
        let root = try parse("<a><![CDATA[x < y & z]]></a>")
        #expect(root.textContent == "x < y & z")
        #expect(root.serialized() == "<a>x &lt; y &amp; z</a>")
    }

    @Test func commentsSurviveTheRoundTrip() throws {
        // A comment is XML Rostrum does not model, which is exactly the XML
        // the round-trip promise covers. It used to be dropped here.
        let root = try parse("<a><!-- nope --><b/></a>")
        #expect(root.serialized() == "<a><!-- nope --><b/></a>")
        #expect(root.children.count == 2)
        guard case .comment(let body) = root.children[0] else {
            Issue.record("first child is not a comment: \(root.children[0])")
            return
        }
        #expect(body == " nope ")
    }

    @Test func entitiesDecodedOnParse() throws {
        let root = try parse(#"<a b="&quot;&amp;&lt;&gt;">&amp;&lt;&gt;</a>"#)
        #expect(root[attribute: "b"] == "\"&<>")
        #expect(root.textContent == "&<>")
    }

    // MARK: - Round-trip stability

    @Test func roundTripIsIdempotentAfterFirstNormalization() throws {
        let inputs = [
            "<a/>",
            "<a b=\"1\" c=\"2\">text</a>",
            "<a>x &amp; y &lt; z &gt; w</a>",
            "<r><a/> <b/>\t\n<c/></r>",
            "<a><![CDATA[raw < & > stuff]]></a>",
            "<t>café 中文 🎉</t>",
            #"<p:sld xmlns:p="urn:p" xmlns:a="urn:a"><p:cSld><a:t> hi </a:t></p:cSld></p:sld>"#,
            #"<e z="26" a="1" xmlns:p="P" xmlns="D" m="13"/>"#,
            "<a><!--keep me--><b/></a>",
            "<a>one<!--c-->two</a>",
            "<a><?target with data?><?bare?><?spaced ?></a>",
        ]
        for input in inputs {
            let once = try normalized(input)
            let twice = try normalized(once)
            let thrice = try normalized(twice)
            #expect(once == twice, "not idempotent for \(input)")
            #expect(twice == thrice, "not idempotent for \(input)")
        }
    }

    @Test func fullDocumentRoundTrip() throws {
        let root = try parse("<a b=\"1\"><c>x</c></a>")
        let doc = XML.document(root)
        let reparsed = try XML.parse(doc)
        #expect(XML.document(reparsed) == doc)
    }

    // MARK: - Comments and processing instructions

    @Test func processingInstructionSurvivesTheRoundTrip() throws {
        let input = "<a><?target some data?><b/></a>"
        let root = try parse(input)
        #expect(root.serialized() == input)
        guard case .processingInstruction(let target, let data) = root.children[0] else {
            Issue.record("first child is not a processing instruction: \(root.children[0])")
            return
        }
        #expect(target == "target")
        #expect(data == "some data")
    }

    @Test func processingInstructionKeepsItsExactSpelling() throws {
        // `<?t?>`, `<?t ?>` and `<?t d?>` are three different byte sequences,
        // and nil-vs-empty data is what tells the first two apart.
        #expect(try normalized("<a><?t?></a>") == "<a><?t?></a>")
        #expect(try normalized("<a><?t ?></a>") == "<a><?t ?></a>")
        #expect(try normalized("<a><?t d?></a>") == "<a><?t d?></a>")
        guard case .processingInstruction(_, let bare) = try parse("<a><?t?></a>").children[0],
              case .processingInstruction(_, let spaced) = try parse("<a><?t ?></a>").children[0]
        else {
            Issue.record("expected two processing instructions")
            return
        }
        #expect(bare == nil)
        #expect(spaced == "")
    }

    @Test func commentKeepsItsPositionAmongChildren() throws {
        let input = "<r><!--first--><a/><!--between--><b/><!--last--></r>"
        #expect(try normalized(input) == input)
        let root = try parse(input)
        #expect(root.children.count == 5)
        #expect(root.childElements.map(\.name) == ["a", "b"])
    }

    @Test func commentIsNotCharacterData() throws {
        let root = try parse("<a><!--not text-->y<b><!--nor this--></b></a>")
        #expect(root.textContent == "y")
    }

    @Test func emptyAndAdjacentCommentsRoundTrip() throws {
        #expect(try normalized("<a><!----></a>") == "<a><!----></a>")
        #expect(try normalized("<a><!--x--><!--y--></a>") == "<a><!--x--><!--y--></a>")
        // A comment is content: the element is no longer empty, so it cannot
        // collapse to a self-closing tag.
        #expect(try normalized("<a><!--x--></a>") != "<a/>")
    }

    @Test func commentInTheMiddleOfTextDoesNotCorruptTheText() throws {
        let input = "<a>one<!--c-->two</a>"
        let root = try parse(input)
        #expect(root.serialized() == input)
        // The text either side stays separate, in order, and uncoalesced —
        // the pending-text buffer must flush BEFORE the comment lands.
        #expect(root.children.count == 3)
        guard case .text(let before) = root.children[0],
              case .comment(let body) = root.children[1],
              case .text(let after) = root.children[2] else {
            Issue.record("expected text/comment/text, got \(root.children)")
            return
        }
        #expect(before == "one")
        #expect(body == "c")
        #expect(after == "two")
        #expect(root.textContent == "onetwo")
    }

    @Test func commentBetweenEntitySplitTextKeepsOneNodeEitherSide() throws {
        // An entity reference splits a run into several `foundCharacters`
        // chunks; they must still coalesce into one node per side.
        let root = try parse("<a>x&amp;y<!--c-->z&lt;w</a>")
        #expect(root.children.count == 3)
        guard case .text(let before) = root.children[0],
              case .text(let after) = root.children[2] else {
            Issue.record("expected text either side of the comment: \(root.children)")
            return
        }
        #expect(before == "x&y")
        #expect(after == "z<w")
        #expect(root.serialized() == "<a>x&amp;y<!--c-->z&lt;w</a>")
    }

    @Test func commentInsideALongChunkedTextRunKeepsTheRunIntact() throws {
        // Long runs arrive in many chunks (libxml2 buffer boundaries). The
        // comment must not split either side into several text nodes.
        let left = String(repeating: "L", count: 200_000)
        let right = String(repeating: "R", count: 200_000)
        let root = try parse("<a>\(left)<!--c-->\(right)</a>")
        #expect(root.children.count == 3)
        guard case .text(let before) = root.children[0],
              case .text(let after) = root.children[2] else {
            Issue.record("expected exactly one text node either side of the comment")
            return
        }
        #expect(before == left)
        #expect(after == right)
        #expect(root.textContent == left + right)
    }

    @Test func markupSerializationIsByteStable() throws {
        let input = #"""
        <p:sld xmlns:a="urn:a" xmlns:p="urn:p"><!--  banner  --><?mso-app x?>\#
        <p:cSld><a:t>hi<!--in text--> there</a:t></p:cSld><!--tail--></p:sld>
        """#
        let once = try normalized(input)
        #expect(once == input)
        // Same bytes every time, over repeated parses and repeated builds.
        for _ in 0..<8 {
            #expect(try normalized(once) == once)
            #expect(try XML.document(XML.parse(Data(input.utf8)))
                == XML.document(XML.parse(Data(input.utf8))))
        }
    }

    @Test func markupOutsideTheRootSurvivesOnTheDocument() throws {
        let input = Data(#"""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>\#u{0D}
        <?mso-application progid="PowerPoint.Show"?><!--lead--><a><!--in--></a><!--trail-->
        """#.utf8)
        let document = try XML.parseDocument(input)
        #expect(document.prologue.count == 2)
        #expect(document.epilogue.count == 1)
        #expect(document.root.children.count == 1)
        #expect(XML.document(document) == input)
        // The element-only overload cannot express any of that, and says so.
        #expect(try XML.parse(input).serialized() == "<a><!--in--></a>")
    }

    @Test func deepCopyCarriesCommentsAndInstructions() throws {
        let input = "<a><!--c--><?t d?><b>x</b></a>"
        let root = try parse(input)
        let copy = root.deepCopy()
        #expect(copy.serialized() == input)
        copy.appendElement(XML.Element("z"))
        #expect(root.serialized() == input)
    }

    @Test func parsedMarkupIsNeverRewritten() throws {
        // The well-formedness guard below must be the identity on everything
        // the parser can produce: lone dashes, a `?>` inside a comment and a
        // `?` inside instruction data are all legal and must pass untouched.
        for input in [
            "<a><!--a-b-c--></a>",
            "<a><!--?>--></a>",
            "<a><!--\n multi \n line --></a>",
            "<a><?t a?b?></a>",
            "<a><?t a??></a>",
            "<a><!--é–--></a>",
        ] {
            #expect(try normalized(input) == input, "rewrote \(input)")
        }
    }

    @Test func handBuiltCommentCannotEndItselfEarly() throws {
        // XML has no escape mechanism inside a comment, and a parser refuses
        // `--` in one — so a body assembled in code has its terminator broken
        // rather than being emitted as markup nothing can reopen.
        let root = XML.Element("a", children: [.comment("x-->y"), .comment("trailing-")])
        let out = root.serialized()
        #expect(!out.contains("x-->y"))
        let reparsed = try XML.parse(Data(out.utf8))
        #expect(reparsed.children.count == 2)
        #expect(reparsed.name == "a")
        #expect(reparsed.serialized() == out)
    }

    @Test func handBuiltProcessingInstructionCannotEndItselfEarly() throws {
        let root = XML.Element("a", children: [
            .processingInstruction(target: "t", data: "a?><b/>"),
        ])
        let out = root.serialized()
        let reparsed = try XML.parse(Data(out.utf8))
        #expect(reparsed.children.count == 1)
        #expect(reparsed.childElements.isEmpty)
        #expect(reparsed.serialized() == out)
    }

    // MARK: - Escaping

    @Test func escapesSpecialCharactersInText() throws {
        let element = XML.Element("a", children: [.text("a & b < c > d")])
        #expect(element.serialized() == "<a>a &amp; b &lt; c &gt; d</a>")
    }

    @Test func escapesSpecialCharactersInAttributes() throws {
        let element = XML.Element("a", attributes: [(name: "v", value: "he said \"hi\" & <more>")])
        #expect(element.serialized() == #"<a v="he said &quot;hi&quot; &amp; &lt;more&gt;"/>"#)
    }

    @Test func nonASCIIPassesThroughVerbatim() throws {
        let text = "é 中文 🎉👩‍👩‍👧‍👧"
        let element = XML.Element("t", attributes: [(name: "v", value: text)], children: [.text(text)])
        let serialized = element.serialized()
        #expect(serialized == "<t v=\"\(text)\">\(text)</t>")

        // Through a real parse as well.
        let root = try parse(serialized)
        #expect(root[attribute: "v"] == text)
        #expect(root.textContent == text)
        #expect(root.serialized() == serialized)

        // And the full document is valid UTF-8 containing the raw characters.
        let doc = XML.document(root)
        let docString = String(decoding: doc, as: UTF8.self)
        #expect(docString.contains(text))
    }

    @Test func escapedRoundTripThroughParser() throws {
        let expected = #"<a b="&quot;&amp;&lt;&gt;">&amp;&lt;&gt;</a>"#
        #expect(try normalized(expected) == expected)
    }

    // MARK: - PresentationML fragment

    @Test func presentationMLFragment() throws {
        let xml = #"<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree><p:sp><p:txBody><a:bodyPr/><a:p><a:r><a:rPr lang="en-US" dirty="0"/><a:t>Hello, World!</a:t></a:r></a:p></p:txBody></p:sp><p:pic><p:blipFill><a:blip r:embed="rId2"/></p:blipFill></p:pic></p:spTree></p:cSld></p:sld>"#
        let root = try parse(xml)

        // Prefixed names preserved verbatim.
        #expect(root.name == "p:sld")

        // xmlns declarations preserved as ordinary attributes.
        #expect(root[attribute: "xmlns:a"] == "http://schemas.openxmlformats.org/drawingml/2006/main")
        #expect(root[attribute: "xmlns:r"] == "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
        #expect(root[attribute: "xmlns:p"] == "http://schemas.openxmlformats.org/presentationml/2006/main")

        // xmlns declarations sort before other attributes; each group alphabetical.
        #expect(root.attributes.map(\.name) == ["xmlns:a", "xmlns:p", "xmlns:r"])

        // Navigation with qualified names.
        let spTree = try #require(root.firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
        #expect(spTree.childElements.map(\.name) == ["p:sp", "p:pic"])
        let run = try #require(
            spTree.firstChild(named: "p:sp")?
                .firstChild(named: "p:txBody")?
                .firstChild(named: "a:p")?
                .firstChild(named: "a:r")
        )
        #expect(run.firstChild(named: "a:t")?.textContent == "Hello, World!")
        #expect(run.firstChild(named: "a:rPr")?[attribute: "lang"] == "en-US")

        // r: prefixed attribute preserved.
        let blip = try #require(
            spTree.firstChild(named: "p:pic")?
                .firstChild(named: "p:blipFill")?
                .firstChild(named: "a:blip")
        )
        #expect(blip[attribute: "r:embed"] == "rId2")

        // Serialization keeps every declaration and prefix; round-trip is stable.
        let serialized = root.serialized()
        #expect(serialized.contains(#"xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main""#))
        #expect(serialized.contains(#"xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main""#))
        #expect(serialized.contains(#"xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships""#))
        #expect(serialized.contains("<a:t>Hello, World!</a:t>"))
        #expect(serialized.contains(#"<a:blip r:embed="rId2"/>"#))
        #expect(try normalized(serialized) == serialized)
    }

    @Test func parsedAttributeOrderIsDeterministic() throws {
        let xml = #"<e z="26" a="1" xmlns:p="P" xmlns="D" m="13"/>"#
        let root = try parse(xml)
        #expect(root.attributes.map(\.name) == ["xmlns", "xmlns:p", "a", "m", "z"])
        #expect(root.serialized() == #"<e xmlns="D" xmlns:p="P" a="1" m="13" z="26"/>"#)
    }

    // MARK: - Whitespace

    @Test func whitespaceOnlyTextNodesPreserved() throws {
        let xml = "<r><a/> <b/>\t\n<c/></r>"
        let root = try parse(xml)
        #expect(root.children.count == 5)
        guard case .element(let a) = root.children[0],
              case .text(let ws1) = root.children[1],
              case .element(let b) = root.children[2],
              case .text(let ws2) = root.children[3],
              case .element(let c) = root.children[4] else {
            Issue.record("unexpected child node shapes")
            return
        }
        #expect(a.name == "a")
        #expect(ws1 == " ")
        #expect(b.name == "b")
        #expect(ws2 == "\t\n")
        #expect(c.name == "c")
        #expect(root.serialized() == xml)
    }

    @Test func significantWhitespaceInsideTextRunPreserved() throws {
        let root = try parse("<a:t>  leading and trailing  </a:t>")
        #expect(root.textContent == "  leading and trailing  ")
        #expect(root.serialized() == "<a:t>  leading and trailing  </a:t>")
    }

    // MARK: - textContent

    @Test func textContentConcatenatesAcrossNestedElements() throws {
        let root = try parse("<a>one<b>two<c>three</c></b>four<d/>five</a>")
        #expect(root.textContent == "onetwothreefourfive")
    }

    @Test func textContentOfEmptyElementIsEmpty() throws {
        let root = try parse("<a><b/><c/></a>")
        #expect(root.textContent == "")
    }

    // MARK: - Attribute subscript

    @Test func attributeSubscriptGet() throws {
        let root = try parse(#"<a x="1" y="2"/>"#)
        #expect(root[attribute: "x"] == "1")
        #expect(root[attribute: "y"] == "2")
        #expect(root[attribute: "z"] == nil)
    }

    @Test func attributeSubscriptSetPreservesPositionOnUpdate() {
        let element = XML.Element("e", attributes: [
            (name: "a", value: "1"),
            (name: "b", value: "2"),
            (name: "c", value: "3"),
        ])
        element[attribute: "b"] = "TWO"
        #expect(element.attributes.map(\.name) == ["a", "b", "c"])
        #expect(element.attributes.map(\.value) == ["1", "TWO", "3"])
        #expect(element.serialized() == #"<e a="1" b="TWO" c="3"/>"#)
    }

    @Test func attributeSubscriptSetAppendsNewAttribute() {
        let element = XML.Element("e", attributes: [(name: "a", value: "1")])
        element[attribute: "z"] = "26"
        #expect(element.attributes.map(\.name) == ["a", "z"])
        #expect(element[attribute: "z"] == "26")
    }

    @Test func attributeSubscriptSetNilRemoves() {
        let element = XML.Element("e", attributes: [
            (name: "a", value: "1"),
            (name: "b", value: "2"),
            (name: "c", value: "3"),
        ])
        element[attribute: "b"] = nil
        #expect(element.attributes.map(\.name) == ["a", "c"])
        #expect(element[attribute: "b"] == nil)
        // Removing a nonexistent attribute is a no-op.
        element[attribute: "nope"] = nil
        #expect(element.attributes.map(\.name) == ["a", "c"])
    }

    // MARK: - Child navigation

    @Test func firstChildNamed() throws {
        let root = try parse("<a><x i=\"1\"/><y/><x i=\"2\"/></a>")
        #expect(root.firstChild(named: "x")?[attribute: "i"] == "1")
        #expect(root.firstChild(named: "y") != nil)
        #expect(root.firstChild(named: "z") == nil)
    }

    @Test func childrenNamed() throws {
        let root = try parse("<a>t1<x i=\"1\"/><y/><x i=\"2\"/>t2<x i=\"3\"/></a>")
        let xs = root.children(named: "x")
        #expect(xs.map { $0[attribute: "i"] } == ["1", "2", "3"])
        #expect(root.children(named: "y").count == 1)
        #expect(root.children(named: "z").isEmpty)
    }

    @Test func childElementsSkipsTextNodes() throws {
        let root = try parse("<a>text<b/>more<c/></a>")
        #expect(root.childElements.map(\.name) == ["b", "c"])
    }

    @Test func firstChildDoesNotRecurse() throws {
        let root = try parse("<a><b><deep/></b></a>")
        #expect(root.firstChild(named: "deep") == nil)
        #expect(root.firstChild(named: "b")?.firstChild(named: "deep") != nil)
    }

    // MARK: - Malformed XML

    @Test func malformedXMLThrows() {
        expectMalformed("")
        expectMalformed("not xml at all")
        expectMalformed("<a><b></a>")
        expectMalformed("<a")
        expectMalformed("<a>unclosed")
        expectMalformed("<a x=1/>")
        // Content after the root element. libxml (Apple platforms) reports it
        // and we reject it; swift-corelibs-foundation (Linux) silently returns
        // the first root without reporting the trailing element through the
        // delegate, so it cannot be detected structurally there. Asserted only
        // where the underlying parser surfaces it — real .pptx parts are always
        // single-root, so this divergence never affects genuine input.
        #if canImport(Darwin)
        expectMalformed("<a></a><b></b>")
        #endif
    }

    @Test func malformedErrorMentionsLineNumber() {
        do {
            _ = try parse("<a>\n<b>\n</a>")
            Issue.record("expected a throw")
        } catch let error as RostrumError {
            guard case .xmlMalformed(let message) = error else {
                Issue.record("expected xmlMalformed, got \(error)")
                return
            }
            #expect(message.contains("line"))
        } catch {
            Issue.record("expected RostrumError, got \(error)")
        }
    }

    // MARK: - Serialization forms

    @Test func emptyElementsSerializeSelfClosing() throws {
        #expect(XML.Element("a").serialized() == "<a/>")
        #expect(XML.Element("a", attributes: [(name: "x", value: "1")]).serialized() == #"<a x="1"/>"#)
        #expect(try normalized("<a></a>") == "<a/>")
        #expect(try normalized("<r><a></a><b/></r>") == "<r><a/><b/></r>")
    }

    @Test func elementWithEmptyTextNodeIsNotSelfClosing() {
        let element = XML.Element("a", children: [.text("")])
        #expect(element.serialized() == "<a></a>")
    }

    @Test func noAddedIndentationOrNewlines() throws {
        let serialized = try normalized("<a><b><c>x</c></b></a>")
        #expect(serialized == "<a><b><c>x</c></b></a>")
        #expect(!serialized.contains("\n"))
    }

    @Test func attributesUseDoubleQuotes() throws {
        let root = try parse("<a b='single'/>")  // single quotes valid on input
        #expect(root.serialized() == #"<a b="single"/>"#)  // never on output
    }

    @Test func documentPrependsOfficeDeclaration() throws {
        let root = XML.Element("p:presentation", attributes: [(name: "xmlns:p", value: "urn:p")])
        let doc = XML.document(root)
        let text = String(decoding: doc, as: UTF8.self)
        #expect(text == "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\r\n<p:presentation xmlns:p=\"urn:p\"/>")
    }

    @Test func documentIsParseable() throws {
        let root = XML.Element("a", children: [.text("hi")])
        let reparsed = try XML.parse(XML.document(root))
        #expect(reparsed.serialized() == "<a>hi</a>")
    }

    // MARK: - Text coalescing

    @Test func multiChunkTextCoalescesIntoSingleNode() throws {
        // Build a text run well over 1KB, salted with entities: libxml2 splits
        // character callbacks at entity boundaries (and at internal buffer
        // boundaries), so this run is guaranteed to arrive in many chunks.
        let piece = "lorem ipsum dolor sit amet &amp; consectetur &lt;adipiscing&gt; elit "
        let repeated = String(repeating: piece, count: 40)  // ~2.7KB of source text
        let expected = String(repeating: "lorem ipsum dolor sit amet & consectetur <adipiscing> elit ", count: 40)
        #expect(expected.utf8.count > 1024)

        let root = try parse("<a:t>\(repeated)</a:t>")
        #expect(root.children.count == 1)
        guard case .text(let text) = root.children[0] else {
            Issue.record("expected a single coalesced text node")
            return
        }
        #expect(text == expected)
        #expect(root.textContent == expected)
    }

    @Test func cdataAdjacentToTextCoalesces() throws {
        let root = try parse("<a>before<![CDATA[ middle ]]>after</a>")
        #expect(root.children.count == 1)
        guard case .text(let text) = root.children[0] else {
            Issue.record("expected a single coalesced text node")
            return
        }
        #expect(text == "before middle after")
    }

    @Test func textSeparatedByElementDoesNotCoalesce() throws {
        let root = try parse("<a>one<b/>two</a>")
        #expect(root.children.count == 3)
        #expect(root.textContent == "onetwo")
        #expect(root.serialized() == "<a>one<b/>two</a>")
    }

    @Test func rejectsXMLForbiddenCharactersInsteadOfCrashing() throws {
        // These crash swift-corelibs-foundation's parser on Linux; we reject
        // them (invalid UTF-8, NUL, control chars, non-characters) as throws.
        expectMalformed("<a>\u{0}</a>")
        expectMalformed("<a>\u{1}</a>")
        expectMalformed("<a>\u{FFFF}</a>")
        expectMalformed("<a x=\"\u{0}\"/>")
        #expect(throws: RostrumError.self) { try XML.parse(Data([0xFF, 0xFE, 0x00])) }
        // Tab/LF/CR remain valid.
        #expect((try? XML.parse(Data("<a>ok\ttab\nline</a>".utf8))) != nil)
    }

    @Test func rejectsDocumentTypeDeclarations() {
        // An internal DTD subset is the entity-expansion vector that
        // `shouldResolveExternalEntities = false` does not cover ("billion
        // laughs"), and libxml2's own ceilings differ between Apple and
        // corelibs Foundation. No OOXML part carries a DTD, so the construct
        // itself is rejected — before the parser ever sees it.
        expectMalformed("<!DOCTYPE lol [<!ENTITY a \"aaaa\"><!ENTITY b \"&a;&a;&a;\">]><r>&b;</r>")
        expectMalformed("<!DOCTYPE r SYSTEM \"http://example.com/evil.dtd\"><r/>")
        expectMalformed("<!DOCTYPE r><r/>")
    }

    // MARK: - Nesting depth

    /// `depth` nested `<a>` elements around a single text node.
    private func nested(depth: Int) -> Data {
        var xml = ""
        for _ in 0..<depth { xml += "<a>" }
        xml += "x"
        for _ in 0..<depth { xml += "</a>" }
        return Data(xml.utf8)
    }

    /// A chain of `depth` elements built in code, which no parser limit gates.
    private func deepTree(depth: Int) -> XML.Element {
        let root = XML.Element("a")
        var current = root
        for _ in 1..<depth {
            let child = XML.Element("a")
            current.appendElement(child)
            current = child
        }
        current.append(.text("x"))
        return root
    }

    @Test func nestingAtTheCeilingParsesAndRoundTrips() throws {
        let root = try XML.parse(nested(depth: XML.maxDepth))
        #expect(root.name == "a")
        #expect(root.textContent == "x")
        #expect(root.serialized() == String(decoding: nested(depth: XML.maxDepth), as: UTF8.self))
    }

    @Test func nestingPastTheCeilingThrowsRatherThanCrashing() {
        // The regression this exists for: 40,000 nested elements deflate to
        // about a kilobyte, so no uncompressed-size budget refuses the file,
        // and the tree it builds used to take the process down with SIGSEGV
        // when it deallocated. It has to be an error, not a crash.
        #expect(throws: RostrumError.self) {
            try XML.parse(self.nested(depth: XML.maxDepth + 1))
        }
        #expect(throws: RostrumError.self) {
            try XML.parse(self.nested(depth: 40_000))
        }
    }

    @Test func deepTreeBuiltInCodeDeallocatesWithoutOverflowingTheStack() {
        // Well past the ~20,000 level where the recursive teardown died.
        do {
            let root = deepTree(depth: 100_000)
            #expect(root.name == "a")
        }
        // Reaching here at all is the assertion: the tree released iteratively.
        #expect(Bool(true))
    }

    @Test func deepTreeSerializesAndReadsTextWithoutOverflowingTheStack() {
        let root = deepTree(depth: 100_000)
        #expect(root.textContent == "x")
        let serialized = root.serialized()
        #expect(serialized.hasPrefix("<a><a><a>"))
        #expect(serialized.hasSuffix("</a></a></a>"))
        #expect(serialized.contains(">x<"))
    }

    @Test func teardownLeavesASharedSubtreeIntact() {
        // Nodes are aliasable — `deepCopy()` exists because callers share them
        // — so the iterative teardown must dismantle only what it owns.
        let shared = XML.Element("shared", children: [.text("keep me")])
        do {
            let parent = XML.Element("parent", children: [.element(XML.Element("mid"))])
            parent.childElements[0].appendElement(shared)
            #expect(parent.serialized() == "<parent><mid><shared>keep me</shared></mid></parent>")
        }
        // `parent` and the `mid` it exclusively owned are gone; `shared` was
        // referenced from out here, so it must have survived whole.
        #expect(shared.children.count == 1)
        #expect(shared.textContent == "keep me")
        #expect(shared.serialized() == "<shared>keep me</shared>")
    }

}
