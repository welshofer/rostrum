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
    /// name-keyed required-attribute rule over-applies. Distinguish by
    /// structure to avoid a false positive.
    ///
    /// - `c:chart`: the CT_RelId *reference* in a slide (`<c:chart r:id="…"/>`,
    ///   always a leaf) requires `r:id`; the CT_Chart *definition* in a chart
    ///   part (always has children) does not.
    /// - `a:ext`: DrawingML uses the name twice. Inside `a:xfrm` it is
    ///   CT_PositiveSize2D — an extent, which really does require `cx`/`cy`.
    ///   Inside `a:extLst` it is CT_OfficeArtExtension — an extension keyed by
    ///   `uri`, which has no `cx`/`cy` and never did. `uri` is the
    ///   discriminator: the extent type has no such attribute.
    ///
    ///   This one was worth 1,582 false positives on a single real corporate
    ///   `.potx` — 791 extensions × the two attributes — which was every issue
    ///   the lint reported for that file. A lint that cries wolf on valid
    ///   PowerPoint output is worse than no lint, because the real defect it
    ///   exists to catch is then invisible in the noise.
    private func isHomonymException(_ el: XML.Element) -> Bool {
        if el.name == "c:chart" { return !el.childElements.isEmpty }
        if el.name == "a:ext" { return el[attribute: "uri"] != nil }
        return false
    }
}
