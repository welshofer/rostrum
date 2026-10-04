import Foundation

/// Resolves style regions and explicit cell formatting without modifying XML.
/// Construct a fresh resolver for each operation so theme/style edits are live.
public struct TableStyleResolver {
    let table: Table
    let theme: Theme
    let grid: TableGridSnapshot
    let definition: XML.Element?
    let stylePart: Part?
    private let enabledFlags: Set<String>

    public init(table: Table, theme: Theme) {
        self.table = table; self.theme = theme
        grid = TableGridSnapshot(table.tbl)
        let flags = table.tbl.firstChild(named: "a:tblPr")
        enabledFlags = Set(["rtl", "firstRow", "lastRow", "firstCol", "lastCol", "bandRow", "bandCol"].filter { name in
            flags.map { TableMergeTopology.flag($0, name) } ?? false
        })
        let found = Self.definition(for: table.tbl, package: table.package)
        definition = found.0.map { TableStyleXML.drawingView($0, root: found.1.flatMap { try? $0.dom() }) }; stylePart = found.1
    }

    /// True when an inline, package-owned or recognized native style is resolved.
    public var hasStyleDefinition: Bool { definition != nil }

    public func fill(row: Int, column: Int) throws -> ReadFill? {
        _ = try grid.cell(row, column)
        return ReadFill(container: effective(row: row, column: column).properties)
    }

    public func border(_ edge: TableCellBorder, row: Int, column: Int) throws -> ReadLine? {
        _ = try grid.cell(row, column)
        return effective(row: row, column: column).properties.firstChild(named: edge.rawValue).map(ReadLine.init(element:))
    }

    func background() -> (properties: XML.Element, owner: Part) {
        let properties = XML.Element("a:tcPr")
        var owner = stylePart ?? table.part
        if let background = definition?.firstChild(named: "a:tblBg") {
            if let fill = background.firstChild(named: "a:fill")?.childElements.first {
                setFill(fill, on: properties)
            } else if let fill = referenceFill(background) {
                setFill(fill, on: properties); owner = theme.part
            }
        }
        if let direct = table.tbl.firstChild(named: "a:tblPr")?.childElements.first(where: { Fill.choiceNames.contains($0.name) }) {
            setFill(direct, on: properties); owner = table.part
        }
        resolveColors(in: properties)
        return (properties, owner)
    }

    /// A bounded approximation of a table-background outer shadow. The source
    /// XML stays untouched; unsupported effect chains retain omission reports.
    struct BackgroundShadow {
        let color: Color
        let alpha: Double
        let blurRadius: Double
        let dx: Double
        let dy: Double
        let fromTheme: Bool
    }

    func backgroundShadow() -> BackgroundShadow? {
        guard let background = definition?.firstChild(named: "a:tblBg") else { return nil }
        let effect: XML.Element
        let fromTheme: Bool
        if let direct = background.firstChild(named: "a:effect") {
            effect = direct; fromTheme = false
        } else {
            guard let reference = background.firstChild(named: "a:effectRef"),
                  let index = reference[attribute: "idx"].flatMap(Int.init), index > 0,
                  let definitions = try? theme.part.dom().firstChild(named: "a:themeElements")?
                    .firstChild(named: "a:fmtScheme")?.firstChild(named: "a:effectStyleLst")?.childElements,
                  definitions.indices.contains(index - 1) else { return nil }
            effect = definitions[index - 1].deepCopy(); fromTheme = true
            replacePlaceholderColors(effect, reference: reference)
        }
        guard effect.childElements.count == 1,
              let list = effect.firstChild(named: "a:effectLst"), list.childElements.count == 1,
              let shadow = list.firstChild(named: "a:outerShdw") else { return nil }
        // Scaling, skew and multi-effect composition need independent geometry
        // evidence. With unit scale and zero skew the alignment origin cancels.
        let allowed: Set<String> = ["blurRad", "dist", "dir", "sx", "sy", "kx", "ky", "algn", "rotWithShape"]
        guard shadow.attributes.allSatisfy({ allowed.contains($0.name) || $0.name == "xmlns" || $0.name.hasPrefix("xmlns:") }),
              ["sx", "sy"].allSatisfy({ shadow[attribute: $0] == nil || ["100000", "100%"].contains(shadow[attribute: $0]!) }),
              ["kx", "ky"].allSatisfy({ shadow[attribute: $0] == nil || shadow[attribute: $0] == "0" }) else { return nil }
        func nonnegative(_ name: String) -> Int? {
            guard shadow[attribute: name] != nil else { return 0 }
            guard let value = shadow.coordinate(name), value >= 0 else { return nil }
            return value
        }
        guard let blur = nonnegative("blurRad"), let distance = nonnegative("dist"),
              let direction = shadow[attribute: "dir"] == nil ? 0 : shadow.boundedInt("dir", in: 0...21_599_999),
              let color = DrawingColor.resolve(in: shadow, theme: theme) else { return nil }
        let angle = Double(direction) / 60_000 * .pi / 180
        return BackgroundShadow(color: color.color, alpha: color.alpha, blurRadius: Double(blur),
            dx: cos(angle) * Double(distance), dy: sin(angle) * Double(distance), fromTheme: fromTheme)
    }

    struct Effective {
        let properties: XML.Element
        let text: XML.Element
        let fillOwner: Part
    }

    private func regionNames(row: Int, column: Int) -> [String] {
        func enabled(_ flag: String) -> Bool { enabledFlags.contains(flag) }
        let lastRow = grid.rows.count - 1, lastColumn = grid.columns.count - 1
        let firstR = enabled("firstRow"), lastR = enabled("lastRow")
        let firstC = enabled("firstCol"), lastC = enabled("lastCol")
        var regions = ["wholeTbl"]
        // Banding excludes the explicitly styled first/last edge. Row regions
        // override column regions; edge regions then override banding.
        if enabled("bandCol"), !(firstC && column == 0), !(lastC && column == lastColumn) {
            regions.append((column - (firstC ? 1 : 0)) % 2 == 0 ? "band1V" : "band2V")
        }
        if enabled("bandRow"), !(firstR && row == 0), !(lastR && row == lastRow) {
            regions.append((row - (firstR ? 1 : 0)) % 2 == 0 ? "band1H" : "band2H")
        }
        if lastC && column == lastColumn { regions.append("lastCol") }
        if firstC && column == 0 { regions.append("firstCol") }
        if lastR && row == lastRow { regions.append("lastRow") }
        if firstR && row == 0 { regions.append("firstRow") }
        if firstR && firstC && row == 0 && column == 0 { regions.append("nwCell") }
        if firstR && lastC && row == 0 && column == lastColumn { regions.append("neCell") }
        if lastR && firstC && row == lastRow && column == 0 { regions.append("swCell") }
        if lastR && lastC && row == lastRow && column == lastColumn { regions.append("seCell") }
        return regions
    }

    /// A detached view of regions enabled for this grid, used by preview
    /// diagnostics. Edge and parity samples cover every region without a full
    /// cell traversal. Disabled regions remain preserved in the source style.
    func activeDefinition() -> XML.Element? {
        guard let definition else { return nil }
        let copy = definition.deepCopy()
        func samples(_ count: Int) -> [Int] {
            Array(Set([0, 1, 2, count - 2, count - 1].filter { $0 >= 0 && $0 < count })).sorted()
        }
        var active: Set<String> = ["a:tblBg"]
        for row in samples(grid.rows.count) {
            for column in samples(grid.columns.count) {
                active.formUnion(regionNames(row: row, column: column).map { "a:" + $0 })
            }
        }
        copy.children = copy.children.filter { child in
            guard case .element(let element) = child else { return true }
            return active.contains(element.name)
        }
        return copy
    }

    /// Diagnostic views retain the owning theme part for relationship lookup.
    /// The source style and its direct resources keep their own owner.
    func themeReferences(in active: XML.Element) -> [(root: XML.Element, path: String, backgroundEffect: Bool)] {
        guard let scheme = try? theme.part.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme") else { return [] }
        var result: [(XML.Element, String, Bool)] = []
        var pending = [active]
        while let node = pending.popLast() {
            pending.append(contentsOf: node.childElements.reversed())
            for (name, list) in [("a:fillRef", "a:fillStyleLst"), ("a:lnRef", "a:lnStyleLst"), ("a:effectRef", "a:effectStyleLst")] {
                guard let reference = node.firstChild(named: name),
                      let index = reference[attribute: "idx"].flatMap(Int.init), index > 0 else { continue }
                let actualList = name == "a:fillRef" && index >= 1001 ? "a:bgFillStyleLst" : list
                let offset = actualList == "a:bgFillStyleLst" ? index - 1001 : index - 1
                guard let definitions = scheme.firstChild(named: actualList)?.childElements,
                      definitions.indices.contains(offset) else { continue }
                let copy = definitions[offset].deepCopy()
                replacePlaceholderColors(copy, reference: reference)
                let occurrence = definitions.prefix(offset + 1).filter { $0.name == copy.name }.count
                result.append((copy, "/a:theme/a:themeElements/a:fmtScheme/\(actualList)/\(copy.name)[\(occurrence)]",
                    name == "a:effectRef" && node === active.firstChild(named: "a:tblBg")))
            }
        }
        return result
    }

    func effective(row: Int, column: Int) -> Effective {
        let base = styleProperties(row: row, column: column)
        return applyingCell(row: row, column: column, to: base)
    }

    private func styleProperties(row: Int, column: Int) -> Effective {
        let properties = XML.Element("a:tcPr"), text = XML.Element("a:defRPr")
        var fillOwner = stylePart ?? table.part
        var borderRanks: [String: Int] = [:]
        func rank(_ name: String) -> Int {
            switch name {
            case "wholeTbl": 0
            case "band1V", "band2V": 1
            case "band1H", "band2H": 2
            case "lastCol": 3
            case "firstCol": 4
            case "lastRow": 5
            case "firstRow": 6
            default: 7
            }
        }
        func contains(_ name: String, row: Int, column: Int) -> Bool {
            grid.cells.indices.contains(row) && grid.cells[row].indices.contains(column)
                && regionNames(row: row, column: column).contains(name)
        }
        func wrapper(_ borders: XML.Element, region name: String,
                     row: Int, column: Int, edge: TableCellBorder) -> XML.Element? {
            let part: String
            switch edge {
            case .left: part = contains(name, row: row, column: column - 1) ? "insideV" : "left"
            case .right: part = contains(name, row: row, column: column + 1) ? "insideV" : "right"
            case .top: part = contains(name, row: row - 1, column: column) ? "insideH" : "top"
            case .bottom: part = contains(name, row: row + 1, column: column) ? "insideH" : "bottom"
            case .diagonalDown: part = "tl2br"
            case .diagonalUp: part = "tr2bl"
            }
            return borders.firstChild(named: "a:\(part)")
        }
        for name in regionNames(row: row, column: column) {
            guard let region = definition?.firstChild(named: "a:\(name)") else { continue }
            if let style = region.firstChild(named: "a:tcStyle") {
                if let fill = style.firstChild(named: "a:fill")?.childElements.first {
                    setFill(fill, on: properties); fillOwner = stylePart ?? table.part
                } else if let fill = referenceFill(style) {
                    setFill(fill, on: properties); fillOwner = theme.part
                }
                if let borders = style.firstChild(named: "a:tcBdr") {
                    for edge in TableCellBorder.allCases {
                        guard let wrapper = wrapper(borders, region: name, row: row, column: column, edge: edge),
                              let line = wrapper.firstChild(named: "a:ln") ?? referenceLine(wrapper) else { continue }
                        let copy = line.deepCopy(); copy.name = edge.rawValue
                        properties.removeChildren(named: edge.rawValue); properties.appendElement(copy)
                        borderRanks[edge.rawValue] = rank(name)
                    }
                }
            }
            if let tx = region.firstChild(named: "a:tcTxStyle") { mergeText(tx, into: text) }
        }
        // A style region owns both sides of its boundary. Office's native
        // lastRow/top separator therefore styles the preceding row's
        // bottom edge too. Propagate style-only values before the donor
        // cell's direct overlay; the neighboring direct edge is not used.
        for (neighborRow, neighborColumn, edge, opposite) in [
            (row - 1, column, TableCellBorder.top, TableCellBorder.bottom),
            (row + 1, column, .bottom, .top),
            (row, column - 1, .left, .right),
            (row, column + 1, .right, .left)
        ] where grid.cells.indices.contains(neighborRow)
            && grid.cells[neighborRow].indices.contains(neighborColumn) {
            for name in regionNames(row: neighborRow, column: neighborColumn) {
                guard rank(name) > (borderRanks[edge.rawValue] ?? -1),
                      let borders = definition?.firstChild(named: "a:\(name)")?
                        .firstChild(named: "a:tcStyle")?.firstChild(named: "a:tcBdr") else { continue }
                guard let wrapper = wrapper(borders, region: name, row: neighborRow, column: neighborColumn, edge: opposite),
                      let line = wrapper.firstChild(named: "a:ln") ?? referenceLine(wrapper) else { continue }
                let copy = line.deepCopy(); copy.name = edge.rawValue
                properties.removeChildren(named: edge.rawValue); properties.appendElement(copy)
                borderRanks[edge.rawValue] = rank(name)
            }
        }
        return Effective(properties: properties, text: text, fillOwner: fillOwner)
    }

    private func applyingCell(row: Int, column: Int, to base: Effective, resolvedBase: Bool = false) -> Effective {
        let properties = base.properties, text = base.text
        var fillOwner = base.fillOwner
        if grid.cells.indices.contains(row), grid.cells[row].indices.contains(column),
           let direct = grid.cells[row][column].firstChild(named: "a:tcPr") {
            for attribute in direct.attributes { properties[attribute: attribute.name] = attribute.value }
            for child in direct.childElements {
                let copy = child.deepCopy()
                if resolvedBase { resolveColors(in: copy) }
                if Fill.choiceNames.contains(child.name) {
                    for name in Fill.choiceNames { properties.removeChildren(named: name) }
                    properties.appendElement(copy); fillOwner = table.part
                } else {
                    properties.removeChildren(named: child.name); properties.appendElement(copy)
                }
            }
        }
        if !resolvedBase {
            resolveColors(in: properties)
            resolveColors(in: text)
        }
        return Effective(properties: properties, text: text, fillOwner: fillOwner)
    }

    /// A single synchronous table render may reuse style-only templates. Public
    /// resolution remains uncached because callers can edit exposed XML/themes.
    /// Entries are read-only to the renderer and expire at the end of renderTable.
    struct RenderSession {
        private let resolver: TableStyleResolver
        private var templates: [Int: Effective] = [:]
        private var remainingCost = 1_048_576

        init(_ resolver: TableStyleResolver) { self.resolver = resolver }

        mutating func effective(row: Int, column: Int) -> Effective {
            // Region membership and whole-table edge selection depend only on
            // first/last/adjacent position and parity: at most 6 x 6 variants, regardless
            // of table size. Flags, theme and style are constant in this session.
            func category(_ index: Int, _ count: Int) -> Int {
                (index == 0 ? 1 : 0) | (index == count - 1 ? 2 : 0)
                    | (index == 1 ? 4 : 0) | (index == count - 2 ? 8 : 0) | ((index & 1) << 4)
            }
            let key = category(row, resolver.grid.rows.count) | (category(column, resolver.grid.columns.count) << 5)
            let base: Effective
            if let cached = templates[key] { base = cached }
            else {
                base = resolver.styleProperties(row: row, column: column)
                resolver.resolveColors(in: base.properties)
                resolver.resolveColors(in: base.text)
                // Bound estimated retained nodes/strings as well as the variant count.
                // A large custom style still renders normally without caching.
                if let cost = Self.cost(of: [base.properties, base.text], limit: remainingCost) {
                    templates[key] = base; remainingCost -= cost
                }
            }
            if let direct = resolver.grid.cells[row][column].firstChild(named: "a:tcPr"),
               !direct.attributes.isEmpty || !direct.childElements.isEmpty {
                // Overlay only replaces root attributes/children. Resolve copied
                // direct children separately; cached descendants stay read-only.
                return resolver.applyingCell(row: row, column: column,
                    to: Effective(properties: XML.Element(base.properties.name,
                        attributes: base.properties.attributes, children: base.properties.children),
                        text: base.text, fillOwner: base.fillOwner), resolvedBase: true)
            }
            return base
        }

        private static func cost(of roots: [XML.Element], limit: Int) -> Int? {
            var pending = roots, total = 0
            while let node = pending.popLast() {
                total += 128 + node.name.utf8.count
                for attribute in node.attributes { total += 64 + attribute.name.utf8.count + attribute.value.utf8.count }
                // Serialized non-element content is uncommon in style templates;
                // count it too without constructing a second full XML string.
                for child in node.children {
                    total += 32
                    switch child {
                    case .element(let element): pending.append(element)
                    case .text(let value), .comment(let value): total += value.utf8.count
                    case .processingInstruction(let target, let data): total += 64 + target.utf8.count + (data?.utf8.count ?? 0)
                    }
                }
                if total > limit { return nil }
            }
            return total
        }
    }

    private func setFill(_ fill: XML.Element, on properties: XML.Element) {
        for name in Fill.choiceNames { properties.removeChildren(named: name) }
        properties.appendElement(fill.deepCopy())
    }

    private func mergeText(_ source: XML.Element, into target: XML.Element) {
        for name in ["b", "i"] {
            if let value = source[attribute: name], value != "def" { target[attribute: name] = value == "on" ? "1" : value == "off" ? "0" : value }
        }
        if let color = source.childElements.first(where: { $0.name.hasSuffix("Clr") }) {
            let fill = XML.Element("a:solidFill", children: [.element(color.deepCopy())])
            target.removeChildren(named: "a:solidFill"); target.appendElement(fill)
        }
        if let font = source.firstChild(named: "a:font") {
            for child in font.childElements { target.removeChildren(named: child.name); target.appendElement(child.deepCopy()) }
        } else if let font = source.firstChild(named: "a:fontRef"), let index = font[attribute: "idx"] {
            let name = index == "major" ? theme.majorFont : theme.minorFont
            if let name { target.removeChildren(named: "a:latin"); target.appendElement(XML.Element("a:latin", attributes: [("typeface", name)])) }
        }
    }

    private func referenceFill(_ style: XML.Element) -> XML.Element? {
        guard let reference = style.firstChild(named: "a:fillRef"),
              let index = reference[attribute: "idx"].flatMap(Int.init), index > 0,
              let scheme = try? theme.part.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme") else { return nil }
        let fills = scheme.firstChild(named: index >= 1001 ? "a:bgFillStyleLst" : "a:fillStyleLst")?.childElements ?? []
        let offset = index >= 1001 ? index - 1001 : index - 1
        guard fills.indices.contains(offset) else { return nil }
        let copy = fills[offset].deepCopy(); replacePlaceholderColors(copy, reference: reference)
        return copy
    }

    private func referenceLine(_ wrapper: XML.Element) -> XML.Element? {
        guard let reference = wrapper.firstChild(named: "a:lnRef"),
              let index = reference[attribute: "idx"].flatMap(Int.init), index > 0,
              let scheme = try? theme.part.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme") else { return nil }
        let lines = scheme.firstChild(named: "a:lnStyleLst")?.childElements ?? []
        guard lines.indices.contains(index - 1) else { return nil }
        let copy = lines[index - 1].deepCopy(); replacePlaceholderColors(copy, reference: reference)
        return copy
    }

    private func replacePlaceholderColors(_ root: XML.Element, reference: XML.Element) {
        guard let color = reference.childElements.first(where: { $0.name.hasSuffix("Clr") }) else { return }
        var stack = [root]
        while let node = stack.popLast() {
            if node.name == "a:schemeClr", node[attribute: "val"] == "phClr" {
                let transforms = node.children
                node.name = color.name; node.attributes = color.attributes
                node.children = color.deepCopy().children + transforms
            }
            stack.append(contentsOf: node.childElements)
        }
    }

    private func resolveColors(in root: XML.Element) {
        var stack = [root]
        while let node = stack.popLast() {
            if node.name == "a:srgbClr", node.childElements.isEmpty { continue }
            guard ["a:srgbClr", "a:schemeClr", "a:sysClr", "a:scrgbClr", "a:prstClr"].contains(node.name) else {
                stack.append(contentsOf: node.childElements)
                continue
            }
            let wrapper = XML.Element("color", children: [.element(node)])
            let result = DrawingColor.resolve(in: wrapper, theme: theme)
            let resolved = result?.color
            if let resolved {
                node.name = "a:srgbClr"; node.attributes = [("val", resolved.hex)]
                node.children = node.children.filter { if case .element = $0 { return false }; return true }
                if let alpha = result?.alpha, alpha < 1 {
                    node.appendElement(XML.Element("a:alpha", attributes: [("val", String(Int((alpha * 100_000).rounded())))]))
                }
            } else { stack.append(contentsOf: node.childElements) }
        }
    }

    static func definition(for table: XML.Element, package: OPCPackage?) -> (XML.Element?, Part?) {
        let properties = table.firstChild(named: "a:tblPr")
        if let inline = properties?.firstChild(named: "a:tableStyle") { return (inline, nil) }
        var desired = properties?.firstChild(named: "a:tableStyleId")?.textContent
        if let package, let presentation = try? package.mainDocumentPart(),
           let styles = try? presentation.related(by: RelType.tableStyles, in: package), let root = try? styles.dom() {
            desired = desired ?? root[attribute: "def"]
            if let definition = TableStyleXML.definitions(in: root).first(where: { $0[attribute: "styleId"]?.lowercased() == desired?.lowercased() }) { return (definition, styles) }
        }
        if let package {
            for part in package.parts.values.sorted(by: { $0.uri.value < $1.uri.value }) where part.contentType == ContentType.tableStyles {
                if let root = try? part.dom(), let definition = TableStyleXML.definitions(in: root).first(where: { $0[attribute: "styleId"]?.lowercased() == desired?.lowercased() }) { return (definition, part) }
            }
        }
        return (desired.flatMap(BuiltInTableStyle.init(id:))?.definition(), nil)
    }
}
