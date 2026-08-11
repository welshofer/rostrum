import Foundation

/// Schema-ordering helpers for building OOXML element trees. When no explicit
/// successor list is given, the ordering is driven by `OOXMLSchema`, whose
/// tables `rostrum-gen` extracts mechanically from python-pptx's descriptor
/// declarations — so insertion is schema-correct without hand-maintained lists.
extension XML.Element {
    /// Insert `child` before the first existing child whose name appears in
    /// `successors` (the XSD-sequence elements that must follow it), else
    /// append. If `successors` is empty, the authoritative successor list for
    /// (this element, `child`) is looked up in the generated `OOXMLSchema`.
    /// This is how python-pptx's `insert_element_before` keeps optional
    /// children at their schema-mandated position.
    func insertChild(_ child: XML.Element, beforeAnyOf successors: [String] = []) {
        let succ = successors.isEmpty
            ? (OOXMLSchema.childSuccessors[name]?[child.name] ?? [])
            : successors
        if !succ.isEmpty, let index = children.firstIndex(where: {
            if case .element(let e) = $0 { return succ.contains(e.name) }
            return false
        }) {
            children.insert(.element(child), at: index)
        } else {
            appendElement(child)
        }
    }

    /// The get-or-add pattern for ZeroOrOne children.
    func getOrAddChild(_ name: String, beforeAnyOf successors: [String] = []) -> XML.Element {
        if let existing = firstChild(named: name) { return existing }
        let element = XML.Element(name)
        insertChild(element, beforeAnyOf: successors)
        return element
    }

    func removeChildren(named name: String) {
        children.removeAll {
            if case .element(let e) = $0 { return e.name == name }
            return false
        }
    }

    /// Remove a specific child element (by identity).
    func removeChild(_ element: XML.Element) {
        children.removeAll {
            if case .element(let e) = $0 { return e === element }
            return false
        }
    }

    /// Element children of `sldIdLst`-style order-bearing lists, ignoring any
    /// insignificant whitespace text nodes a parsed file may carry.
    func replaceChildElements(with elements: [XML.Element]) {
        children = elements.map { .element($0) }
    }

    /// An integer attribute parsed from a file, or nil when it is absent,
    /// unparseable, or outside `range`.
    ///
    /// Untrusted input needs the bound, not just the parse: `Int("9223372036854775807")`
    /// succeeds, and the `max + 1` or `x + inset` that follows is an overflow
    /// trap — a crash the caller cannot catch. Bounding here fixes every
    /// consumer at once instead of at each arithmetic site.
    func boundedInt(_ attribute: String, in range: ClosedRange<Int>) -> Int? {
        guard let raw = self[attribute: attribute], let value = Int(raw),
              range.contains(value) else { return nil }
        return value
    }

    /// A coordinate or extent attribute, bounded to `OOXMLBounds.coordinate`.
    func coordinate(_ attribute: String) -> Int? {
        boundedInt(attribute, in: OOXMLBounds.coordinate)
    }

    /// A structural copy, new nodes all the way down. `XML.Element` is a
    /// reference type, so cloning a subtree by hand is the only way to edit
    /// the copy without the edits reaching back into the original.
    func deepCopy() -> XML.Element {
        XML.Element(name, attributes: attributes, children: children.map { node in
            switch node {
            case .text(let text): return .text(text)
            case .element(let element): return .element(element.deepCopy())
            case .comment(let body): return .comment(body)
            case .processingInstruction(let target, let data):
                return .processingInstruction(target: target, data: data)
            }
        })
    }
}

/// Ranges the format defines, or that Rostrum imposes on file-supplied
/// numbers so that arithmetic over them cannot overflow.
///
/// These are read-side guards, not authoring validation: a value outside the
/// range means the file is wrong, and Rostrum's answer is to ignore it rather
/// than to trap on it later.
enum OOXMLBounds {
    /// `ST_SlideId` is 256..<2147483648.
    static let slideID: ClosedRange<Int> = 0...2_147_483_647
    /// `ST_DrawingElementId` is an `xsd:unsignedInt`.
    static let drawingElementID: ClosedRange<Int> = 0...Int(UInt32.max)
    /// A coordinate or extent in EMU. Far beyond any real slide (2^40 EMU is
    /// roughly a million inches), and small enough that summing a few million
    /// of them still cannot overflow `Int`.
    static let coordinate: ClosedRange<Int> = -(1 << 40)...(1 << 40)
}
