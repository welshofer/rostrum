import Foundation

/// A direct byte-level parser for the XML that OOXML parts actually contain.
///
/// `XMLParser` costs a delegate callback, an attribute dictionary and several
/// bridged strings per element, which made parsing the slowest step of
/// opening a deck. This parser builds the same tree in one pass over the
/// bytes — but only for the plain subset it can reproduce exactly:
///
/// - UTF-8 without a byte-order mark;
/// - an optional `<?xml version="1.0" …?>` declaration naming UTF-8;
/// - elements, attributes and character data with ASCII names;
/// - the five predefined entities and numeric character references.
///
/// Anything else returns `nil` and the caller parses with `XMLParser` as
/// before: comments, processing instructions, CDATA, document types,
/// tabs and line breaks inside attribute values (attribute normalization),
/// namespace-declaration edge cases and every malformed document. Line ends
/// in character data are normalized as XML requires (CRLF and CR become LF). So this parser never reports an error and never
/// decides what is well-formed on its own; `XMLParser` still owns both.
///
/// The result must be indistinguishable from `XMLParser`'s for every accepted
/// document. `XMLFastParserTests` checks that over the fixture corpus and
/// over mutations of it.
enum XMLFastParser {
    static func parse(_ data: Data) -> XML.Document? {
        data.withUnsafeBytes { raw -> XML.Document? in
            let bytes = raw.bindMemory(to: UInt8.self)
            guard !bytes.isEmpty, isPlainUTF8(bytes) else { return nil }
            var parser = Parser(bytes: bytes)
            return parser.document()
        }
    }

    /// Well-formed UTF-8 whose scalars are all XML 1.0 `Char`s. Mirrors `XML.isXMLChar` on decoded scalars.
    private static func isPlainUTF8(_ bytes: UnsafeBufferPointer<UInt8>) -> Bool {
        let count = bytes.count
        var i = 0
        while i < count {
            let byte = bytes[i]
            if byte < 0x80 {
                guard byte >= 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D else { return false }
                i += 1
                continue
            }
            func continuation(_ offset: Int) -> Bool {
                i + offset < count && bytes[i + offset] & 0xC0 == 0x80
            }
            switch byte {
            case 0xC2...0xDF:
                guard continuation(1) else { return false }
                i += 2
            case 0xE0...0xEF:
                guard continuation(1), continuation(2) else { return false }
                let second = bytes[i + 1]
                if byte == 0xE0 && second < 0xA0 { return false }   // overlong
                if byte == 0xED && second > 0x9F { return false }   // surrogates
                // U+FFFE and U+FFFF are not XML characters.
                if byte == 0xEF && second == 0xBF && bytes[i + 2] >= 0xBE { return false }
                i += 3
            case 0xF0...0xF4:
                guard continuation(1), continuation(2), continuation(3) else { return false }
                let second = bytes[i + 1]
                if byte == 0xF0 && second < 0x90 { return false }   // overlong
                if byte == 0xF4 && second > 0x8F { return false }   // past U+10FFFF
                i += 4
            default:
                return false
            }
        }
        return true
    }

    private struct Parser {
        let bytes: UnsafeBufferPointer<UInt8>
        let count: Int
        var i = 0

        init(bytes: UnsafeBufferPointer<UInt8>) {
            self.bytes = bytes
            count = bytes.count
        }

        @inline(__always) private func isSpace(_ byte: UInt8) -> Bool {
            byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
        }

        @inline(__always) private mutating func skipSpace() {
            while i < count, isSpace(bytes[i]) { i += 1 }
        }

        @inline(__always) private func string(_ start: Int, _ end: Int) -> String {
            String(decoding: UnsafeBufferPointer(rebasing: bytes[start..<end]), as: UTF8.self)
        }

        private func matches(_ literal: StaticString, at index: Int) -> Bool {
            let length = literal.utf8CodeUnitCount
            guard index + length <= count else { return false }
            return memcmp(bytes.baseAddress! + index, literal.utf8Start, length) == 0
        }

        /// An ASCII name: `[A-Za-z_][A-Za-z0-9_.-]*`, optionally one
        /// `prefix:local` pair. Returns the end index, or nil.
        private func nameEnd(from start: Int) -> Int? {
            var index = start
            var colons = 0
            var segmentStart = true
            while index < count {
                let byte = bytes[index]
                let isLetter = (byte | 0x20) >= 0x61 && (byte | 0x20) <= 0x7A || byte == 0x5F
                if isLetter {
                    segmentStart = false
                } else if !segmentStart, (byte >= 0x30 && byte <= 0x39) || byte == 0x2D || byte == 0x2E {
                    // digits, '-' and '.' may continue a name but not start one
                } else if byte == 0x3A, !segmentStart, colons == 0 {
                    colons = 1
                    segmentStart = true
                } else {
                    break
                }
                index += 1
            }
            // Non-ASCII names are legal XML but rare; XMLParser handles them.
            if index < count, bytes[index] >= 0x80 { return nil }
            return index > start && !segmentStart ? index : nil
        }

        /// Decode the entity or character reference at `i` (which is at `&`),
        /// appending its UTF-8 to `out`. Anything unrecognized returns false.
        private mutating func reference(into out: inout [UInt8]) -> Bool {
            if matches("&lt;", at: i) { out.append(0x3C); i += 4; return true }
            if matches("&gt;", at: i) { out.append(0x3E); i += 4; return true }
            if matches("&amp;", at: i) { out.append(0x26); i += 5; return true }
            if matches("&quot;", at: i) { out.append(0x22); i += 6; return true }
            if matches("&apos;", at: i) { out.append(0x27); i += 6; return true }
            guard matches("&#", at: i) else { return false }
            var index = i + 2
            var value: UInt32 = 0
            var digits = 0
            let hexadecimal = index < count && bytes[index] == 0x78   // 'x' only; "&#X" is malformed
            if hexadecimal { index += 1 }
            while index < count, bytes[index] != 0x3B {
                let byte = bytes[index]
                let digit: UInt32
                switch byte {
                case 0x30...0x39: digit = UInt32(byte - 0x30)
                case 0x41...0x46 where hexadecimal: digit = UInt32(byte - 0x41 + 10)
                case 0x61...0x66 where hexadecimal: digit = UInt32(byte - 0x61 + 10)
                default: return false
                }
                value = value * (hexadecimal ? 16 : 10) + digit
                guard value <= 0x10FFFF else { return false }
                digits += 1
                index += 1
            }
            guard index < count, digits > 0, XML.isXMLChar(value), let scalar = Unicode.Scalar(value) else { return false }
            out.append(contentsOf: Array(String(scalar).utf8))
            i = index + 1
            return true
        }

        /// Character data from `i` up to the next `<`. Returns nil text for an
        /// empty run; returns false when the run needs `XMLParser`.
        private mutating func characterData(_ text: inout String?) -> Bool {
            let start = i
            guard let found = memchr(bytes.baseAddress! + start, 0x3C, count - start) else { return false }
            let end = bytes.baseAddress!.distance(to: found.assumingMemoryBound(to: UInt8.self))
            text = nil
            if end == start { return true }
            // "]]>" may not appear in character data; '&' needs decoding.
            var needsDecoding = false
            var index = start
            while index < end {
                let byte = bytes[index]
                if byte == 0x26 || byte == 0x0D {
                    needsDecoding = true
                } else if byte == 0x3E, index >= start + 2, bytes[index - 1] == 0x5D, bytes[index - 2] == 0x5D {
                    return false
                }
                index += 1
            }
            if !needsDecoding {
                text = string(start, end)
                i = end
                return true
            }
            var decoded: [UInt8] = []
            decoded.reserveCapacity(end - start)
            while i < end {
                if bytes[i] == 0x26 {
                    guard reference(into: &decoded) else { return false }
                } else if bytes[i] == 0x0D {
                    // Line-end normalization: CRLF and a lone CR are one LF.
                    // (A CR written as `&#13;` is data and stays, above.)
                    decoded.append(0x0A)
                    i += i + 1 < end && bytes[i + 1] == 0x0A ? 2 : 1
                } else {
                    decoded.append(bytes[i])
                    i += 1
                }
            }
            guard i == end else { return false }
            text = String(decoding: decoded, as: UTF8.self)
            return true
        }

        /// A quoted attribute value starting at `i`. Whitespace other than a
        /// plain space would be normalized by XMLParser, so it is refused.
        private mutating func attributeValue() -> String? {
            guard i < count, bytes[i] == 0x22 || bytes[i] == 0x27 else { return nil }
            let quote = bytes[i]
            i += 1
            let start = i
            var decoded: [UInt8]? = nil
            while i < count {
                let byte = bytes[i]
                if byte == quote {
                    let value = decoded.map { String(decoding: $0, as: UTF8.self) } ?? string(start, i)
                    i += 1
                    return value
                }
                if byte == 0x3C || byte == 0x09 || byte == 0x0A || byte == 0x0D { return nil }
                if byte == 0x26 {
                    if decoded == nil { decoded = Array(bytes[start..<i]) }
                    guard reference(into: &decoded!) else { return nil }
                    continue
                }
                decoded?.append(byte)
                i += 1
            }
            return nil
        }

        /// `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` in its
        /// usual spellings. Any other declaration is left to XMLParser.
        private mutating func declaration() -> Bool {
            guard matches("<?xml", at: 0), 5 < count, isSpace(bytes[5]) else { return true }
            i = 5
            var seen: [String] = []
            while true {
                let hadSpace = i < count && isSpace(bytes[i])
                skipSpace()
                if matches("?>", at: i) { i += 2; break }
                guard hadSpace, let end = nameEnd(from: i) else { return false }
                let name = string(i, end)
                i = end
                guard i < count, bytes[i] == 0x3D else { return false }
                i += 1
                guard let value = attributeValue() else { return false }
                switch (name, seen.count) {
                case ("version", 0): guard value == "1.0" else { return false }
                case ("encoding", 1): guard value.lowercased() == "utf-8" else { return false }
                case ("standalone", 1), ("standalone", 2):
                    guard seen.last != "standalone", value == "yes" || value == "no" else { return false }
                default: return false
                }
                seen.append(name)
            }
            return seen.first == "version"
        }

        mutating func document() -> XML.Document? {
            guard declaration() else { return nil }
            skipSpace()
            var root: XML.Element?
            var stack: [XML.Element] = []
            // Start-tag name ranges, to match end tags without building strings.
            var names: [(start: Int, end: Int)] = []
            var namespaces: [(name: String, value: String)] = []
            var others: [(name: String, value: String)] = []

            while true {
                guard i + 1 < count, bytes[i] == 0x3C else { return nil }
                if bytes[i + 1] == 0x2F {
                    // End tag.
                    guard let open = names.last else { return nil }
                    let length = open.end - open.start
                    let start = i + 2
                    guard start + length <= count,
                          memcmp(bytes.baseAddress! + start, bytes.baseAddress! + open.start, length) == 0 else { return nil }
                    i = start + length
                    skipSpace()
                    guard i < count, bytes[i] == 0x3E else { return nil }
                    i += 1
                    stack.removeLast()
                    names.removeLast()
                    if stack.isEmpty { break }
                } else {
                    // Start tag. '!' and '?' (comments, CDATA, instructions,
                    // document types) fail the name check and fall back.
                    let nameStart = i + 1
                    guard let end = nameEnd(from: nameStart) else { return nil }
                    i = end
                    namespaces.removeAll(keepingCapacity: true)
                    others.removeAll(keepingCapacity: true)
                    var selfClosing = false
                    while true {
                        guard i < count else { return nil }
                        let hadSpace = isSpace(bytes[i])
                        skipSpace()
                        guard i < count else { return nil }
                        if bytes[i] == 0x3E { i += 1; break }
                        if bytes[i] == 0x2F {
                            guard i + 1 < count, bytes[i + 1] == 0x3E else { return nil }
                            i += 2
                            selfClosing = true
                            break
                        }
                        guard hadSpace, let attributeEnd = nameEnd(from: i) else { return nil }
                        let attributeStart = i
                        i = attributeEnd
                        skipSpace()
                        guard i < count, bytes[i] == 0x3D else { return nil }
                        i += 1
                        skipSpace()
                        guard let value = attributeValue() else { return nil }
                        let isNamespace = matches("xmlns", at: attributeStart)
                            && (attributeEnd == attributeStart + 5 || bytes[attributeStart + 5] == 0x3A)
                        if isNamespace {
                            // Declaring the empty namespace for a prefix, or
                            // touching the reserved xml/xmlns prefixes, has
                            // rules XMLParser enforces; leave those to it.
                            let prefixed = attributeEnd > attributeStart + 5
                            if prefixed && value.isEmpty { return nil }
                            if matches("xmlns:xml", at: attributeStart) { return nil }
                            namespaces.append((string(attributeStart, attributeEnd), value))
                        } else {
                            if matches("xml:", at: attributeStart) {
                                // xml:space in its two defined values is an
                                // ordinary attribute; other xml: names are not.
                                guard attributeEnd - attributeStart == 9, matches("xml:space", at: attributeStart),
                                      value == "preserve" || value == "default" else { return nil }
                            }
                            others.append((string(attributeStart, attributeEnd), value))
                        }
                    }
                    if matches("xml:", at: nameStart) || matches("xmlns:", at: nameStart) { return nil }
                    guard stack.count < XML.maxDepth else { return nil }
                    // The order XMLParser's attribute dictionary is given:
                    // namespace declarations, then the rest, each sorted.
                    if namespaces.count > 1 { namespaces.sort { $0.name < $1.name } }
                    if others.count > 1 { others.sort { $0.name < $1.name } }
                    for list in [namespaces, others] where list.count > 1 {
                        for index in 1..<list.count where list[index].name == list[index - 1].name { return nil }
                    }
                    let element = XML.Element(string(nameStart, end), attributes: namespaces + others)
                    if let parent = stack.last {
                        parent.children.append(.element(element))
                    } else {
                        root = element
                    }
                    if selfClosing {
                        if stack.isEmpty { break }
                    } else {
                        stack.append(element)
                        names.append((nameStart, end))
                    }
                }
                var text: String?
                guard characterData(&text) else { return nil }
                if let text, let parent = stack.last { parent.children.append(.text(text)) }
            }
            // Only whitespace may follow the root.
            skipSpace()
            guard i == count, let root else { return nil }
            return XML.Document(root: root)
        }
    }
}
