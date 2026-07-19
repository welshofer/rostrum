import Foundation

extension Presentation {
    /// A schema-rule violation found by `validate()`.
    public struct ValidationIssue: Sendable, CustomStringConvertible {
        public let part: String
        public let element: String
        public let message: String
        public var description: String { "\(part): <\(element)> \(message)" }
    }

    /// Check every XML part against the generated schema's required-attribute
    /// rules (extracted from python-pptx's descriptors). An empty result means
    /// no required attribute is missing anywhere in the deck. This is a lint,
    /// not a full XSD validation, and it does not mutate the document.
    public func validate() throws -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for (uri, part) in package.parts.sorted(by: { $0.key.value < $1.key.value }) where uri.ext == "xml" {
            guard let dom = try? part.dom() else { continue }
            var stack: [XML.Element] = [dom]
            while let el = stack.popLast() {
                if let required = OOXMLSchema.requiredAttributes[el.name],
                   !isHomonymException(el) {
                    for attr in required where el[attribute: attr] == nil {
                        issues.append(ValidationIssue(
                            part: uri.value, element: el.name,
                            message: "missing required attribute \"\(attr)\""))
                    }
                }
                stack.append(contentsOf: el.childElements)
            }
        }
        return issues
    }

    /// Some element names are shared by two unrelated schema types, so a
    /// name-keyed required-attribute rule over-applies. `c:chart` is the case:
    /// the CT_RelId *reference* in a slide (`<c:chart r:id="…"/>`, always a leaf)
    /// requires `r:id`, but the CT_Chart *definition* in a chart part (always has
    /// children) does not. Distinguish by structure to avoid a false positive.
    private func isHomonymException(_ el: XML.Element) -> Bool {
        el.name == "c:chart" && !el.childElements.isEmpty
    }
}
