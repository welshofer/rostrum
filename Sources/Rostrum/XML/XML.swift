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
public enum XML {
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
        public var textContent: String {
            var out = ""
            collectText(into: &out)
            return out
        }

        private func collectText(into out: inout String) {
            for node in children {
                switch node {
                case .text(let text):
                    out += text
                case .element(let element):
                    element.collectText(into: &out)
                }
            }
        }

        public func append(_ node: Node) {
            children.append(node)
        }

        public func appendElement(_ element: Element) {
            children.append(.element(element))
        }

        /// Serialize this element (and subtree) without an XML declaration.
        public func serialized() -> String {
            var out = ""
            serialize(into: &out)
            return out
        }

        private func serialize(into out: inout String) {
            out += "<"
            out += name
            for attribute in attributes {
                out += " "
                out += attribute.name
                out += "=\""
                out += XML.escapeAttributeValue(attribute.value)
                out += "\""
            }
            if children.isEmpty {
                out += "/>"
                return
            }
            out += ">"
            for node in children {
                switch node {
                case .element(let element):
                    element.serialize(into: &out)
                case .text(let text):
                    out += XML.escapeText(text)
                }
            }
            out += "</"
            out += name
            out += ">"
        }
    }

    /// Parse a complete XML document; returns the root element.
    public static func parse(_ data: Data) throws -> Element {
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        let builder = TreeBuilder()
        parser.delegate = builder
        let ok = parser.parse()
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

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String]
        ) {
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
