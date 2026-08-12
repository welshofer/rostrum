import Foundation
// On Linux, XMLParser (and XMLParserDelegate) live in FoundationXML, not the
// core Foundation module. On Apple platforms this import is unavailable and
// unneeded, so it is guarded by canImport.
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Rostrum's lightweight XML DOM.
///
/// Why a custom DOM: Foundation's `XMLDocument`/`XMLNode` do not exist on iOS,
/// and Office XML demands byte-level control over serialization (attribute
/// order, namespace prefixes, no reformatting) that convenience APIs don't
/// guarantee. `XMLParser` (SAX) *is* available on every platform, so the parser
/// side bridges through it.
///
/// Design contract for the implementer:
/// - Names are stored as written in the document — qualified, prefix and all
///   (e.g. "p:sld", "a:off"). Namespaces are NOT resolved: `xmlns`/`xmlns:p`
///   declarations are kept verbatim as ordinary attributes. OOXML uses a fixed,
///   well-known prefix vocabulary, and preserving it verbatim is what makes
///   open→save round-trips byte-faithful. (Configure `XMLParser` with
///   `shouldProcessNamespaces = false`.)
/// - Attribute order is preserved (array, not dictionary). The subscript
///   updates an existing attribute in place or appends a new one at the end;
///   setting nil removes it.
/// - Text nodes are preserved exactly as parsed, including whitespace-only
///   runs (significant inside `a:t`). CDATA becomes an ordinary text node.
///   Comments and processing instructions are carried through as opaque
///   nodes, in their original position: they are precisely the XML Rostrum
///   does not model, which is the XML the round-trip promise is about. Ones
///   outside the root element live on `XML.Document`, which is what
///   `parseDocument(_:)` returns.
/// - Serialization: single-quotes never; attributes double-quoted; escape
///   `& < > "` in attribute values and `& < >` in text; no added indentation
///   or newlines anywhere (byte fidelity beats prettiness — Office files are
///   single-line). `XML.document(_:)` prepends the standalone UTF-8
///   declaration Office writes:
///   `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\r\n`.
/// - Parse errors throw `RostrumError.xmlMalformed` with the parser's message
///   and line number.
/// - Nesting is bounded by `maxDepth`; see that property for why a DOM of
///   reference types needs a depth ceiling that no byte budget can supply.
public enum XML {
    /// The deepest element nesting `parse(_:)` will accept.
    ///
    /// Real OOXML is shallow: a slide part runs about fifteen levels, and the
    /// only construct that nests without bound is a group shape inside a group
    /// shape, which PowerPoint gives up on long before this.
    ///
    /// The ceiling exists because the tree is built from reference types, and
    /// every natural way to walk one — releasing it, serializing it, reading
    /// its text — costs a stack frame per level. Past roughly twenty thousand
    /// levels that is a SIGSEGV rather than an error, and the document that
    /// does it is a few hundred kilobytes of `<a>` that deflates to about one
    /// kilobyte. No uncompressed-size budget can catch that, so the depth has
    /// to be refused directly. `Element` also tears down, serializes and reads
    /// its text iteratively, so this ceiling is a policy about what counts as
    /// a real document rather than the only thing standing between the parser
    /// and a crash.
    ///
    /// 1,000 is roughly fifty times the deepest part Office produces.
    public static let maxDepth = 1_000

    public enum Node {
        case element(Element)
        case text(String)
        /// An XML comment. The payload is the body between `<!--` and `-->`,
        /// verbatim and unescaped — XML defines no escaping inside a comment,
        /// which also means a CR in the body cannot survive a reparse: line
        /// endings are normalized inside a comment and there is no character
        /// reference to hide one behind.
        case comment(String)
        /// A processing instruction, `<?target data?>`. `data` is nil for the
        /// dataless form `<?target?>`, and distinct from `""`, which is
        /// `<?target ?>` — the space is part of the original bytes.
        ///
        /// `indirect` because this is the only case with a two-word payload,
        /// and without the box it sets the size of every node in every
        /// element's `children` array — a stride of 40 bytes instead of 24,
        /// paid on every child of every element in the document, to inline a
        /// case that almost no file contains. Boxing costs an allocation on
        /// the rare processing instruction and gives back a third of the
        /// memory of every tree Rostrum builds.
        indirect case processingInstruction(target: String, data: String?)
    }

    /// What may legally appear outside the root element: comments and
    /// processing instructions (the XML spec's `Misc`, minus whitespace).
    ///
    /// A separate type from `Node` because outside the root the other two node
    /// kinds are not merely unusual but forbidden — text is malformed, and a
    /// second element is a second root. Modelling the prologue as `[Node]`
    /// would leave `document(_:)` a choice between emitting XML nothing can
    /// reopen and silently dropping content, and this type has neither.
    public enum Markup {
        case comment(String)
        case processingInstruction(target: String, data: String?)

        /// The same markup as an element child, for code that walks both.
        public var node: Node {
            switch self {
            case .comment(let body): return .comment(body)
            case .processingInstruction(let target, let data):
                return .processingInstruction(target: target, data: data)
            }
        }
    }

    /// A whole XML document: the root element, plus the comments and
    /// processing instructions that sit outside it.
    ///
    /// `Element` alone cannot express a leading `<?mso-application?>` or a
    /// producer's copyright banner ahead of the root, so re-serializing from a
    /// bare root drops them. Parts parse through this type instead, which is
    /// what lets those survive a save.
    public struct Document {
        /// Markup between the XML declaration and the root element.
        public var prologue: [Markup]
        public var root: Element
        /// Markup after the root element's closing tag.
        public var epilogue: [Markup]

        public init(root: Element, prologue: [Markup] = [], epilogue: [Markup] = []) {
            self.root = root
            self.prologue = prologue
            self.epilogue = epilogue
        }
    }

    public final class Element {
        public var name: String
        public var attributes: [(name: String, value: String)]
        public var children: [Node]

        public init(_ name: String, attributes: [(name: String, value: String)] = [], children: [Node] = []) {
            self.name = name
            self.attributes = attributes
            self.children = children
        }

        /// Get/set an attribute by name. Setting preserves position of an
        /// existing attribute; new attributes append. Setting nil removes.
        public subscript(attribute name: String) -> String? {
            get {
                attributes.first(where: { $0.name == name })?.value
            }
            set {
                if let index = attributes.firstIndex(where: { $0.name == name }) {
                    if let newValue {
                        attributes[index].value = newValue
                    } else {
                        attributes.remove(at: index)
                    }
                } else if let newValue {
                    attributes.append((name: name, value: newValue))
                }
            }
        }

        /// Child elements only (text nodes skipped), in document order.
        public var childElements: [Element] {
            children.compactMap { node in
                if case .element(let element) = node { return element }
                return nil
            }
        }

        /// First child element with the given qualified name.
        public func firstChild(named name: String) -> Element? {
            for node in children {
                if case .element(let element) = node, element.name == name {
                    return element
                }
            }
            return nil
        }

        /// All child elements with the given qualified name, in order.
        public func children(named name: String) -> [Element] {
            var result: [Element] = []
            for node in children {
                if case .element(let element) = node, element.name == name {
                    result.append(element)
                }
            }
            return result
        }

        /// Concatenation of all descendant text nodes, in document order.
        ///
        /// Iterative for the reason given on `deinit`: a walk that recurses
        /// once per level turns a deep tree into a stack overflow.
        public var textContent: String {
            var out = ""
            var stack: [Node] = children.reversed()
            while let node = stack.popLast() {
                switch node {
                case .text(let text):
                    out += text
                case .element(let element):
                    stack.append(contentsOf: element.children.reversed())
                case .comment, .processingInstruction:
                    // Markup, not character data: `<a><!--x-->y</a>` is "y".
                    break
                }
            }
            return out
        }

        /// Dismantle the subtree without recursing.
        ///
        /// The synthesized teardown releases `children`, which releases each
        /// child's `children`, one stack frame per level — so a deep enough
        /// tree kills the process instead of throwing. Measured on this type:
        /// fine at 5,000 levels, SIGSEGV at 20,000, and the crash lands *after*
        /// a successful parse, when the tree goes out of scope.
        ///
        /// `parse(_:)` refuses anything past `maxDepth`, so a document can no
        /// longer build one. A tree assembled in code has no such gate, and
        /// teardown is the one path every tree takes, so it is fixed here too
        /// rather than left to the parser's good behaviour.
        ///
        /// Only elements this one exclusively owns are dismantled. Nodes are
        /// shareable — `deepCopy()` exists precisely because callers alias
        /// them — and a subtree someone else still references must come
        /// through this intact.
        deinit {
            guard !children.isEmpty else { return }
            var owned: [Element] = []
            for node in children {
                if case .element(let element) = node { owned.append(element) }
            }
            // Dropping our own children first is what makes the uniqueness
            // test below meaningful: from here, `owned` holds the only
            // reference this tree contributes to each direct child.
            children.removeAll()
            var index = 0
            while index < owned.count {
                if isKnownUniquelyReferenced(&owned[index]) {
                    for node in owned[index].children {
                        if case .element(let element) = node { owned.append(element) }
                    }
                    owned[index].children.removeAll()
                }
                index += 1
            }
            // `owned` dies here. Every element in it that was ours now holds
            // nothing, so releasing the array recurses nowhere.
        }

        public func append(_ node: Node) {
            children.append(node)
        }

        public func appendElement(_ element: Element) {
            children.append(.element(element))
        }

        /// Serialize this element (and subtree) without an XML declaration.
        ///
        /// Iterative for the reason given on `deinit`. Output is byte-for-byte
        /// what the recursive form produced: a `.close` step is pushed beneath
        /// an element's children so it emits after them, and children are
        /// pushed in reverse so they pop in document order.
        public func serialized() -> String {
            var out = ""
            var stack: [SerializationStep] = [.open(self)]
            while let step = stack.popLast() {
                switch step {
                case .text(let text):
                    out += XML.escapeText(text)
                case .verbatim(let markup):
                    out += markup
                case .close(let name):
                    out += "</"
                    out += name
                    out += ">"
                case .open(let element):
                    out += "<"
                    out += element.name
                    for attribute in element.attributes {
                        out += " "
                        out += attribute.name
                        out += "=\""
                        out += XML.escapeAttributeValue(attribute.value)
                        out += "\""
                    }
                    if element.children.isEmpty {
                        out += "/>"
                        continue
                    }
                    out += ">"
                    stack.append(.close(element.name))
                    for node in element.children.reversed() {
                        switch node {
                        case .element(let child): stack.append(.open(child))
                        case .text(let text): stack.append(.text(text))
                        case .comment(let body):
                            stack.append(.verbatim(XML.commentMarkup(body)))
                        case .processingInstruction(let target, let data):
                            stack.append(.verbatim(
                                XML.processingInstructionMarkup(target: target, data: data)))
                        }
                    }
                }
            }
            return out
        }

        /// One unit of pending serialization work. `close` carries the name
        /// rather than the element so the step cannot keep a subtree alive.
        /// `verbatim` carries already-rendered markup (a comment or processing
        /// instruction), which is emitted as-is — XML defines no escaping
        /// inside either, so escaping one would change what it says.
        private enum SerializationStep {
            case open(Element)
            case text(String)
            case verbatim(String)
            case close(String)
        }
    }

    /// The XML 1.0 `Char` production: tab/LF/CR, then the legal scalar ranges.
    /// Control characters (except tab/LF/CR), surrogates, and the U+FFFE/FFFF
    /// non-characters are excluded — feeding them to the Linux parser can crash it.
    private static func isXMLChar(_ v: UInt32) -> Bool {
        v == 0x9 || v == 0xA || v == 0xD
            || (v >= 0x20 && v <= 0xD7FF)
            || (v >= 0xE000 && v <= 0xFFFD)
            || (v >= 0x10000 && v <= 0x10FFFF)
    }

    /// Parse a complete XML document; returns the root element.
    ///
    /// Markup outside the root element is dropped by this overload, because an
    /// `Element` cannot hold it. Callers that re-serialize what they parsed —
    /// every part in a package — must use `parseDocument(_:)` instead.
    public static func parse(_ data: Data) throws -> Element {
        try parseDocument(data).root
    }

    /// Give every dataless processing instruction a payload, so none reaches
    /// `XMLParser` in the spelling that crashes it on Linux.
    ///
    /// Returns `nil` — and copies nothing — when the document has no such
    /// instruction, which is almost every document. When it does, each
    /// `<?target?>` becomes `<?target TOKEN?>`, where the token is generated for
    /// this parse alone. `TreeBuilder` turns that token back into `nil` data, so
    /// the node still remembers it was the dataless spelling and still writes
    /// itself back as `<?target?>`.
    ///
    /// A token rather than counting keeps the mapping local: there is no
    /// positional bookkeeping to drift out of step with whichever instructions
    /// libxml2 decides to report. Comments and CDATA are stepped over rather
    /// than scanned into — a `<?t?>` inside a comment is comment text, and
    /// rewriting it would change bytes the round trip promises to preserve.
    static func neutralizingDatalessInstructions(_ data: Data) -> (data: Data, token: String)? {
        let bytes = [UInt8](data)
        guard Self.containsDatalessInstruction(bytes) else { return nil }

        var token = ""
        repeat {
            // U+E000 is private use: valid XML, and absent from real documents.
            token = "\u{E000}" + String(UInt64.random(in: .min ... .max), radix: 16)
        } while data.range(of: Data(token.utf8)) != nil
        let tokenBytes = [UInt8](token.utf8)

        var out: [UInt8] = []
        out.reserveCapacity(bytes.count + tokenBytes.count * 4)
        Self.scanInstructions(bytes) { span in
            switch span {
            case .verbatim(let range):
                out.append(contentsOf: bytes[range])
            case .datalessInstruction(let range):
                // `<?target` … then the payload that makes it survive the parser.
                out.append(contentsOf: bytes[range.lowerBound..<(range.upperBound - 2)])
                out.append(0x20)
                out.append(contentsOf: tokenBytes)
                out.append(contentsOf: [0x3F, 0x3E])  // ?>
            }
        }
        return (Data(out), token)
    }

    private enum InstructionSpan {
        case verbatim(Range<Int>)
        case datalessInstruction(Range<Int>)
    }

    private static func containsDatalessInstruction(_ bytes: [UInt8]) -> Bool {
        var found = false
        Self.scanInstructions(bytes) { span in
            if case .datalessInstruction = span { found = true }
        }
        return found
    }

    /// Walk the document handing out spans, stepping over comments and CDATA so
    /// only real processing instructions are classified.
    private static func scanInstructions(_ bytes: [UInt8], _ emit: (InstructionSpan) -> Void) {
        let n = bytes.count
        var i = 0
        var copyFrom = 0
        func flush(upTo end: Int) {
            if end > copyFrom { emit(.verbatim(copyFrom..<end)) }
        }
        while i < n {
            guard bytes[i] == 0x3C else { i += 1; continue }  // <
            if Self.matches(bytes, at: i, "<!--") {
                i = Self.index(of: "-->", in: bytes, from: i + 4) ?? n
            } else if Self.matches(bytes, at: i, "<![CDATA[") {
                i = Self.index(of: "]]>", in: bytes, from: i + 9) ?? n
            } else if Self.matches(bytes, at: i, "<?") {
                guard let close = Self.index(of: "?>", in: bytes, from: i + 2) else { i = n; break }
                let content = (i + 2)..<close
                let hasData = bytes[content].contains { $0 == 0x20 || $0 == 0x09 || $0 == 0x0A || $0 == 0x0D }
                if !hasData && !content.isEmpty {
                    flush(upTo: i)
                    emit(.datalessInstruction(i..<(close + 2)))
                    copyFrom = close + 2
                }
                i = close + 2
            } else {
                i += 1
            }
        }
        flush(upTo: n)
    }

    private static func matches(_ bytes: [UInt8], at index: Int, _ literal: String) -> Bool {
        let pattern = [UInt8](literal.utf8)
        guard index + pattern.count <= bytes.count else { return false }
        for (offset, byte) in pattern.enumerated() where bytes[index + offset] != byte { return false }
        return true
    }

    private static func index(of literal: String, in bytes: [UInt8], from start: Int) -> Int? {
        let pattern = [UInt8](literal.utf8)
        guard start >= 0, bytes.count >= pattern.count else { return nil }
        var i = start
        while i + pattern.count <= bytes.count {
            if Self.matches(bytes, at: i, literal) { return i }
            i += 1
        }
        return nil
    }

    /// Parse a complete XML document, keeping the comments and processing
    /// instructions that sit outside the root element.
    public static func parseDocument(_ data: Data) throws -> Document {
        // Reject input that XML forbids BEFORE handing it to XMLParser: on Linux,
        // swift-corelibs-foundation's parser can TRAP (SIGILL, not throw) on
        // invalid UTF-8 or characters outside the XML 1.0 Char production. Real
        // .pptx parts are always clean UTF-8, so this only fails malformed input
        // that had to error anyway — but as a throw, on every platform.
        guard let text = String(data: data, encoding: .utf8) else {
            throw RostrumError.xmlMalformed("input is not valid UTF-8")
        }
        if let bad = text.unicodeScalars.first(where: { !Self.isXMLChar($0.value) }) {
            throw RostrumError.xmlMalformed(
                "input contains U+\(String(format: "%04X", bad.value)), not permitted in XML")
        }
        // No OOXML part legitimately carries a document type declaration, and
        // an internal DTD subset is the one entity-expansion vector that
        // `shouldResolveExternalEntities = false` below does not cover
        // ("billion laughs"). libxml2 has its own expansion ceilings, but they
        // differ between Apple Foundation and swift-corelibs-foundation, so
        // reject the construct itself rather than trusting either.
        if text.contains("<!DOCTYPE") {
            throw RostrumError.xmlMalformed(
                "document type declarations are not permitted in OOXML parts")
        }
        // `<?target?>` — a processing instruction with no data — is a NULL
        // dereference inside libxml2's callback on swift-corelibs-foundation:
        // SIGSEGV, not a throw, so no caller can defend against it. `<?target ?>`
        // and `<?target data?>` are both fine; it is only the dataless spelling.
        // Rostrum opens files it did not write, so a construct that kills the
        // process is a denial of service, and the fix has to be in front of the
        // parser rather than around it.
        let neutralized = Self.neutralizingDatalessInstructions(data)
        let parser = XMLParser(data: neutralized?.data ?? data)
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        let builder = TreeBuilder()
        builder.datalessInstructionToken = neutralized?.token
        parser.delegate = builder
        let ok = parser.parse()
        // Checked before the generic failure path so the reason survives:
        // aborting the parse makes `parserError` report only that a delegate
        // stopped it, which says nothing about why.
        if builder.depthExceeded {
            throw RostrumError.xmlMalformed(
                "element nesting deeper than \(Self.maxDepth) levels")
        }
        guard ok, !builder.extraTopLevelContent, let root = builder.root, builder.stack.isEmpty else {
            let line = parser.lineNumber
            let message: String
            if let error = parser.parserError as NSError? {
                message = error.localizedDescription
            } else if builder.extraTopLevelContent {
                message = "content after the root element"
            } else {
                message = "unknown parse error"
            }
            throw RostrumError.xmlMalformed("line \(line): \(message)")
        }
        return Document(root: root, prologue: builder.prologue, epilogue: builder.epilogue)
    }

    /// Serialize a root element into a complete UTF-8 document, with the
    /// Office-style XML declaration.
    public static func document(_ root: Element) -> Data {
        document(Document(root: root))
    }

    /// Serialize a whole document — prologue markup, root, epilogue markup —
    /// with the Office-style XML declaration.
    public static func document(_ document: Document) -> Data {
        var out = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\r\n"
        for markup in document.prologue { out += self.markup(markup) }
        out += document.root.serialized()
        for markup in document.epilogue { out += self.markup(markup) }
        return Data(out.utf8)
    }

    // MARK: - Comments and processing instructions

    /// Render one piece of markup exactly as it will appear in the output.
    fileprivate static func markup(_ markup: Markup) -> String {
        switch markup {
        case .comment(let body):
            return commentMarkup(body)
        case .processingInstruction(let target, let data):
            return processingInstructionMarkup(target: target, data: data)
        }
    }

    /// `<!--` body `-->`, body verbatim. XML defines no escaping inside a
    /// comment: whatever is between the delimiters is what the comment says,
    /// so escaping it would change it.
    fileprivate static func commentMarkup(_ body: String) -> String {
        "<!--" + breakingUpPairs(in: body, of: "-", and: "-", padTrailing: true) + "-->"
    }

    /// `<?target data?>`, or `<?target?>` when `data` is nil — the dataless
    /// form is a distinct spelling and must come back as it went in.
    fileprivate static func processingInstructionMarkup(target: String, data: String?) -> String {
        let body = data.map { target + " " + $0 } ?? target
        return "<?" + breakingUpPairs(in: body, of: "?", and: ">", padTrailing: false) + "?>"
    }

    /// Separate every `first`+`second` pair in `body` with a space, and (when
    /// `padTrailing`) a trailing `first` as well.
    ///
    /// This is the identity function on anything `parse(_:)` produced: XML
    /// forbids `--` inside a comment and a `-` immediately before its closing
    /// delimiter, forbids `?>` inside a processing instruction, and every
    /// conforming parser refuses all three — so a round-tripped comment or
    /// instruction passes through untouched, byte for byte.
    ///
    /// Markup assembled in code has no such gate, and neither construct has an
    /// escape mechanism to fall back on. Emitting `-->` from inside a comment
    /// body would end the comment early and leave a part PowerPoint can only
    /// offer to repair, so the sequence is separated rather than passed on.
    private static func breakingUpPairs(
        in body: String, of first: Unicode.Scalar, and second: Unicode.Scalar, padTrailing: Bool
    ) -> String {
        // Fast path: without `first` there is no pair to break.
        guard body.unicodeScalars.contains(first) else { return body }
        var out = String.UnicodeScalarView()
        out.reserveCapacity(body.unicodeScalars.count + 8)
        var previousWasFirst = false
        for scalar in body.unicodeScalars {
            if previousWasFirst, scalar == second { out.append(" ") }
            out.append(scalar)
            previousWasFirst = scalar == first
        }
        if padTrailing, previousWasFirst { out.append(" ") }
        return String(out)
    }

    // MARK: - Escaping

    /// Escape `& < >` (and CR, which XML line-ending normalization would turn
    /// into LF on any reparse) for use inside text content. Non-ASCII passes
    /// through verbatim (the output is UTF-8).
    ///
    /// Escaping MUST iterate Unicode scalars, not Characters: a `&` followed by
    /// a combining mark forms a single grapheme cluster that `== "&"` misses,
    /// which would emit a bare ampersand no parser can reopen.
    fileprivate static func escapeText(_ string: String) -> String {
        // Fast path: nothing to escape.
        guard string.utf8.contains(where: {
            $0 == UInt8(ascii: "&") || $0 == UInt8(ascii: "<")
                || $0 == UInt8(ascii: ">") || $0 == 0x0D
        }) else {
            return string
        }
        var out = String.UnicodeScalarView()
        out.reserveCapacity(string.unicodeScalars.count + 16)
        for scalar in string.unicodeScalars {
            switch scalar {
            case "&": out.append(contentsOf: "&amp;".unicodeScalars)
            case "<": out.append(contentsOf: "&lt;".unicodeScalars)
            case ">": out.append(contentsOf: "&gt;".unicodeScalars)
            case "\r": out.append(contentsOf: "&#13;".unicodeScalars)
            default: out.append(scalar)
            }
        }
        return String(out)
    }

    /// Escape `& < > "` plus TAB/LF/CR for use inside a double-quoted attribute
    /// value. The whitespace characters must be character references: XML
    /// attribute-value normalization replaces literal tab/newline bytes with
    /// spaces on every conforming reparse, silently corrupting round-trips
    /// (e.g. multi-line alt text) if written bare.
    fileprivate static func escapeAttributeValue(_ string: String) -> String {
        // Fast path: nothing to escape.
        guard string.utf8.contains(where: {
            $0 == UInt8(ascii: "&") || $0 == UInt8(ascii: "<")
                || $0 == UInt8(ascii: ">") || $0 == UInt8(ascii: "\"")
                || $0 == 0x09 || $0 == 0x0A || $0 == 0x0D
        }) else {
            return string
        }
        var out = String.UnicodeScalarView()
        out.reserveCapacity(string.unicodeScalars.count + 16)
        for scalar in string.unicodeScalars {
            switch scalar {
            case "&": out.append(contentsOf: "&amp;".unicodeScalars)
            case "<": out.append(contentsOf: "&lt;".unicodeScalars)
            case ">": out.append(contentsOf: "&gt;".unicodeScalars)
            case "\"": out.append(contentsOf: "&quot;".unicodeScalars)
            case "\t": out.append(contentsOf: "&#9;".unicodeScalars)
            case "\n": out.append(contentsOf: "&#10;".unicodeScalars)
            case "\r": out.append(contentsOf: "&#13;".unicodeScalars)
            default: out.append(scalar)
            }
        }
        return String(out)
    }

    // MARK: - SAX bridge

    /// Builds an `XML.Element` tree from `XMLParser` (SAX) callbacks.
    ///
    /// CAVEAT: `XMLParser`'s `didStartElement` callback delivers attributes as
    /// a `[String: String]` dictionary, which LOSES the source order of the
    /// attributes. That is acceptable — attribute order is not semantically
    /// significant in XML, and Office tolerates any order — but serialization
    /// must still be deterministic. So for parsed elements we impose a stable
    /// order: `xmlns` / `xmlns:*` namespace declarations first (sorted
    /// alphabetically), then all other attributes alphabetically.
    /// Deterministic output matters more than matching the original order.
    private final class TreeBuilder: NSObject, XMLParserDelegate {
        var root: XML.Element?
        var stack: [XML.Element] = []
        /// Set when content appears after the single root element has closed —
        /// a second root element, or non-whitespace top-level text. libxml
        /// (macOS) reports this as a parse error, but swift-corelibs-foundation
        /// (Linux) silently ignores the trailing content, so we detect it here
        /// for cross-platform parity. See `parse(_:)`.
        var extraTopLevelContent = false
        /// Set when nesting passed `XML.maxDepth`. The parse is aborted at that
        /// point rather than allowed to build the rest of the tree.
        var depthExceeded = false
        /// Set when the document had a dataless processing instruction that had
        /// to be given a payload to survive the Linux parser. See
        /// `neutralizingDatalessInstructions(_:)`.
        var datalessInstructionToken: String?
        /// Comments and processing instructions before the root element opened,
        /// and after it closed. Legal XML, and `Element` cannot hold either.
        var prologue: [XML.Markup] = []
        var epilogue: [XML.Markup] = []

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String]
        ) {
            // `stack.count` is the depth this element would be opened at, so
            // the ceiling is enforced before the element exists.
            guard stack.count < XML.maxDepth else {
                depthExceeded = true
                parser.abortParsing()
                return
            }
            flushPendingText()
            // Stable attribute order: xmlns declarations first, then the rest,
            // each group sorted alphabetically (see class comment).
            var namespaceKeys: [String] = []
            var otherKeys: [String] = []
            for key in attributeDict.keys {
                if key == "xmlns" || key.hasPrefix("xmlns:") {
                    namespaceKeys.append(key)
                } else {
                    otherKeys.append(key)
                }
            }
            namespaceKeys.sort()
            otherKeys.sort()
            var attributes: [(name: String, value: String)] = []
            attributes.reserveCapacity(attributeDict.count)
            for key in namespaceKeys {
                attributes.append((name: key, value: attributeDict[key]!))
            }
            for key in otherKeys {
                attributes.append((name: key, value: attributeDict[key]!))
            }

            let element = XML.Element(elementName, attributes: attributes)
            if let parent = stack.last {
                parent.appendElement(element)
            } else if root == nil {
                root = element
            } else {
                extraTopLevelContent = true  // a second root element is malformed
            }
            stack.append(element)
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            flushPendingText()
            if !stack.isEmpty {
                stack.removeLast()
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            appendText(string)
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            // CDATA becomes an ordinary text node (re-escaped on output).
            appendText(String(decoding: CDATABlock, as: UTF8.self))
        }

        func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) {
            // Only delivered when validating against a DTD, but preserve it as
            // text for safety — whitespace-only runs are significant to us.
            appendText(whitespaceString)
        }

        // NOTE: `parseErrorOccurred` is intentionally NOT implemented. On Linux,
        // swift-corelibs-foundation invokes it for *valid* documents containing
        // entity references, CR characters, or multi-chunk text, so treating it
        // as fatal would reject good XML. Malformedness is detected structurally
        // instead: `parse()`'s return value, an unclosed `stack`, a missing
        // `root`, and `extraTopLevelContent` (a second root / trailing text).

        func parser(_ parser: XMLParser, foundComment comment: String) {
            place(.comment(comment))
        }

        func parser(
            _ parser: XMLParser,
            foundProcessingInstructionWithTarget target: String,
            data: String?
        ) {
            // The token exists only because the dataless spelling crashes the
            // Linux parser; turning it back into `nil` here is what makes that
            // workaround invisible to everything above.
            var payload = data
            if let token = datalessInstructionToken, payload == token { payload = nil }
            place(.processingInstruction(target: target, data: payload))
        }

        /// File a comment or processing instruction where it was found.
        ///
        /// These are the XML Rostrum models least of all, which is exactly why
        /// they are kept: the round-trip promise is about the markup we do not
        /// understand, and a comment is the plainest case of it. Inside an
        /// element they become opaque children in document order; outside one
        /// they go to the document's prologue or epilogue, since an `Element`
        /// has nowhere to put them.
        ///
        /// Flushing pending text FIRST is what keeps a comment inside a text
        /// run from disturbing the run: the characters seen so far materialize
        /// ahead of the comment node, and the characters after it start a new
        /// text node instead of coalescing across it — `<a>one<!--c-->two</a>`
        /// stays three children in that order rather than becoming "onetwo".
        private func place(_ markup: XML.Markup) {
            flushPendingText()
            if let current = stack.last {
                current.children.append(markup.node)
            } else if root == nil {
                prologue.append(markup)
            } else {
                epilogue.append(markup)
            }
        }

        /// Character-data chunks awaiting materialization. `foundCharacters`
        /// may deliver a single text run in many chunks (libxml2 buffer
        /// boundaries, entity references split runs), and coalescing by
        /// re-concatenating onto the stored node re-copies the accumulated
        /// prefix per chunk — quadratic in the run's length. Chunks buffer
        /// here instead and become ONE `.text` node at the next structural
        /// event (child element opens, or the owner closes).
        private var pendingText: [String] = []
        private var pendingOwner: XML.Element?

        private func flushPendingText() {
            guard let owner = pendingOwner else { return }
            pendingOwner = nil
            let text = pendingText.count == 1 ? pendingText[0] : pendingText.joined()
            pendingText.removeAll(keepingCapacity: true)
            if let lastIndex = owner.children.indices.last,
               case .text(let existing) = owner.children[lastIndex] {
                owner.children[lastIndex] = .text(existing + text)
            } else {
                owner.children.append(.text(text))
            }
        }

        /// Append character data to the current element, coalescing with an
        /// immediately preceding text node — ADJACENT text nodes must merge
        /// into one, but via the pending buffer above, not per-chunk copies.
        private func appendText(_ string: String) {
            guard let current = stack.last else {
                // Text outside any element. Whitespace around the root (or a
                // leading BOM/newline) is legal and ignored; non-whitespace
                // text after the root has closed is malformed content.
                if root != nil, string.contains(where: { !$0.isWhitespace }) {
                    extraTopLevelContent = true
                }
                return
            }
            if pendingOwner !== current {
                flushPendingText()
                pendingOwner = current
            }
            pendingText.append(string)
        }
    }
}
