import Foundation

public extension Chart {
    /// A missing reference cache rebuilt from the embedded workbook's stored values.
    struct RebuiltCache: Sendable, Equatable {
        public let formula: String
        public let numeric: Bool
        /// Includes blank cells, whose indices remain gaps in the cache.
        public let pointCount: Int
    }

    enum CacheRepairProblem: Error, Equatable, CustomStringConvertible {
        case unsupportedReference(String)
        case invalidWorkbook(String)
        case unsupportedCell(String)
        case limitExceeded

        public var description: String {
            switch self {
            case .unsupportedReference(let detail): "Cannot rebuild chart cache: \(detail)"
            case .invalidWorkbook(let detail): "Cannot read embedded chart workbook: \(detail)"
            case .unsupportedCell(let detail): "Cannot materialize chart cell: \(detail)"
            case .limitExceeded: "Chart cache repair exceeds its bounded read/materialization budget"
            }
        }
    }

    /// Explicitly materialize absent classic `strCache`/`numCache` elements.
    ///
    /// Existing caches (even empty or stale ones), formulas, formatting, workbook
    /// bytes and all other parts are retained. Ordinary reads/saves never call
    /// this operation. All missing references are validated before any mutation;
    /// an unsupported reference or ambiguous/malformed workbook refuses the whole
    /// operation. Calling it again is a byte-preserving no-op.
    ///
    /// Supports local A1 cells and one-dimensional ranges, text and finite numeric
    /// cells, and formula cells with stored results. Numbers must use General
    /// formatting. No formula evaluation, external links, named ranges, multilevel
    /// categories, merged worksheet cells or date/number-format conversion.
    /// Limits: 64 MiB workbook, 1,024 missing references and 100,000 total points.
    /// Native PowerPoint visual acceptance remains separate from cache construction.
    @discardableResult
    func rebuildMissingCachesFromWorkbook() throws -> [RebuiltCache] {
        let root = CacheRepairNode(try part.dom())
        guard root.isNamed("chartSpace", in: CacheRepairNode.chart) else {
            throw CacheRepairProblem.unsupportedReference("expected a classic chartSpace")
        }
        var stack = [(root, "")]
        var missing: [(CacheRepairNode, String, Bool)] = []
        var visited = 0
        var points = 0
        while let (node, parent) = stack.popLast() {
            visited += 1
            guard visited <= 250_000 else { throw CacheRepairProblem.limitExceeded }
            if node.uri == CacheRepairNode.chart {
                if node.local == "multiLvlStrRef", node.children("multiLvlStrCache").isEmpty {
                    throw CacheRepairProblem.unsupportedReference("multilevel category cache")
                }
                if node.local == "strRef" || node.local == "numRef" {
                    let numeric = node.local == "numRef"
                    let cacheName = numeric ? "numCache" : "strCache"
                    if node.children(cacheName).isEmpty {
                        guard ["tx", "cat", "val", "xVal", "yVal", "bubbleSize", "plus", "minus"].contains(parent) else {
                            throw CacheRepairProblem.unsupportedReference("reference outside a supported data slot")
                        }
                        let formulas = node.children("f")
                        guard formulas.count == 1, formulas[0].element.childElements.isEmpty,
                              let range = ChartWorkbookReader.Range(formulas[0].element.textContent),
                              node.children.allSatisfy({ $0.uri == CacheRepairNode.chart && ["f", "extLst"].contains($0.local) }) else {
                            throw CacheRepairProblem.unsupportedReference("invalid or unsupported \(node.local)")
                        }
                        // Range parsing is bounded; one total budget also bounds repeated ranges.
                        guard missing.count < 1_024, points <= 100_000 - range.count else { throw CacheRepairProblem.limitExceeded }
                        points += range.count
                        missing.append((node, formulas[0].element.textContent, numeric))
                    }
                    continue // existing caches are authoritative; extensions are not repaired
                }
                if node.local == "extLst" { continue }
            } else {
                if node.local == "AlternateContent" && node.uri == "http://schemas.openxmlformats.org/markup-compatibility/2006" {
                    // Do not repair only one conditional rendering branch.
                    throw CacheRepairProblem.unsupportedReference("conditional chart markup")
                }
                continue // preserve drawing/foreign extension content without interpreting it
            }
            stack.append(contentsOf: node.children.reversed().map { ($0, node.local) })
        }
        guard !missing.isEmpty else { return [] }
        let external = root.children("externalData")
        guard external.count == 1, let id = external[0].relationshipID,
              part.rels.items.filter({ $0.rId == id }).count == 1,
              let relation = part.rels.relationship(withId: id), !relation.isExternal, relation.type == RelType.package,
              let workbook = try? package.part(at: PackURI.resolve(target: relation.target, relativeTo: part.uri.baseURI)),
              workbook.contentType == ContentType.xlsx else {
            throw CacheRepairProblem.invalidWorkbook("missing or ambiguous internal XLSX relationship")
        }
        let reader = try CacheRepairWorkbook(data: workbook.blob)
        var pending: [(CacheRepairNode, XML.Element)] = []
        var report: [RebuiltCache] = []
        for (reference, formula, numeric) in missing {
            let range = ChartWorkbookReader.Range(formula)!
            let values = try reader.values(for: range, numeric: numeric)
            let cache = XML.Element(numeric ? "c:numCache" : "c:strCache",
                                    attributes: [("xmlns:c", CacheRepairNode.chart)])
            if numeric {
                let format = XML.Element("c:formatCode"); format.append(.text("General")); cache.appendElement(format)
            }
            cache.appendElement(XML.Element("c:ptCount", attributes: [("val", String(values.count))]))
            for (index, value) in values.enumerated() {
                guard let value else { continue }
                let point = XML.Element("c:pt", attributes: [("idx", String(index))])
                let item = XML.Element("c:v"); item.append(.text(value)); point.appendElement(item); cache.appendElement(point)
            }
            pending.append((reference, cache))
            report.append(.init(formula: formula, numeric: numeric, pointCount: values.count))
        }
        // No throwing work follows the first edit. Preserve unknown markup and
        // cache ordering: the cache belongs after f and before extLst.
        for (reference, cache) in pending {
            let extensionElement = reference.children("extLst").first?.element
            let index = reference.element.children.firstIndex {
                if case .element(let child) = $0 { return child === extensionElement }
                return false
            } ?? reference.element.children.count
            reference.element.children.insert(.element(cache), at: index)
        }
        part.markDirty()
        return report
    }
}

/// Namespace-aware views; alias prefixes and local rebinding never become data
/// just because a foreign element happens to have a familiar local name.
struct CacheRepairNode {
    static let chart = "http://schemas.openxmlformats.org/drawingml/2006/chart"
    static let sheet = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    static let relationships = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    let element: XML.Element
    let namespaces: [String: String]
    let local: String
    let uri: String

    init(_ element: XML.Element, inherited: [String: String] = [:]) {
        self.element = element
        var namespaces = inherited
        for (key, value) in element.attributes {
            if key == "xmlns" { namespaces[""] = value }
            else if key.hasPrefix("xmlns:") { namespaces[String(key.dropFirst(6))] = value }
        }
        self.namespaces = namespaces
        let name = element.name.split(separator: ":", maxSplits: 1).map(String.init)
        local = name.last ?? ""
        uri = namespaces[name.count == 2 ? name[0] : ""] ?? ""
    }
    var children: [Self] { element.childElements.map { Self($0, inherited: namespaces) } }
    func children(_ name: String) -> [Self] { children.filter { $0.isNamed(name, in: uri) } }
    func isNamed(_ name: String, in namespace: String) -> Bool { local == name && uri == namespace }
    var relationshipID: String? {
        let matches = element.attributes.filter { key, _ in
            let parts = key.split(separator: ":").map(String.init)
            return parts.count == 2 && parts[1] == "id" && namespaces[parts[0]] == Self.relationships
        }
        return matches.count == 1 ? matches[0].value : nil
    }
}
