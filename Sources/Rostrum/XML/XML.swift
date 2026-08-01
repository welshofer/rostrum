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
///   Comments and processing instructions are dropped (Office never emits
///   meaningful ones inside parts).
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
                        }
                    }
                }
            }
            return out
        }

        /// One unit of pending serialization work. `close` carries the name
        /// rather than the element so the step cannot keep a subtree alive.
        private enum SerializationStep {
            case open(Element)
            case text(String)
            case close(String)
        }
    }

    /// Parse a complete XML document; returns the root element.
    /// The XML 1.0 `Char` production: tab/LF/CR, then the legal scalar ranges.
    /// Control characters (except tab/LF/CR), surrogates, and the U+FFFE/FFFF
    /// non-characters are excluded — feeding them to the Linux parser can crash it.
    private static func isXMLChar(_ v: UInt32) -> Bool {
        v == 0x9 || v == 0xA || v == 0xD
            || (v >= 0x20 && v <= 0xD7FF)
            || (v >= 0xE000 && v <= 0xFFFD)
            || (v >= 0x10000 && v <= 0x10FFFF)
    }

    public static func parse(_ data: Data) throws -> Element {
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
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        let builder = TreeBuilder()
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
        return root
    }

    /// Serialize a root element into a complete UTF-8 document, with the
    /// Office-style XML declaration.
    public static func document(_ root: Element) -> Data {
        let declaration = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\r\n"
        return Data((declaration + root.serialized()).utf8)
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

        // Comments and processing instructions are intentionally dropped:
        // no `foundComment` / `foundProcessingInstruction` handling.

        /// Append character data to the current element, coalescing with an
        /// immediately preceding text node. `foundCharacters` may deliver a
        /// single text run in multiple chunks (libxml2 buffer boundaries,
        /// entity references split runs), so ADJACENT text nodes must merge
        /// into one.
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
            if let lastIndex = current.children.indices.last,
               case .text(let existing) = current.children[lastIndex] {
                current.children[lastIndex] = .text(existing + string)
            } else {
                current.children.append(.text(string))
            }
        }
    }
}
