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
}
