import Foundation

/// Resolves style regions and explicit cell formatting without modifying XML.
/// Construct a fresh resolver for each operation so theme/style edits are live.
public struct TableStyleResolver {
    let table: Table
    let theme: Theme
    let grid: TableGridSnapshot
    let definition: XML.Element?
    let stylePart: Part?

    public init(table: Table, theme: Theme) {
        self.table = table; self.theme = theme
        grid = TableGridSnapshot(table.tbl)
        let found = Self.definition(for: table.tbl, package: table.package)
        definition = found.0; stylePart = found.1
    }

    /// False for an unresolved native style ID. Such a style is preserved, but
    /// its appearance needs an embedded definition before it can be previewed.
    public var hasStyleDefinition: Bool { definition != nil || table.styleID == Table.noStyleGUID }

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
        if let background = definition?.firstChild(named: "a:tblBg"),
           let fill = background.firstChild(named: "a:fill")?.childElements.first ?? referenceFill(background) {
            setFill(fill, on: properties)
        }
        if let direct = table.tbl.firstChild(named: "a:tblPr")?.childElements.first(where: { Fill.choiceNames.contains($0.name) }) {
            setFill(direct, on: properties); owner = table.part
        }
        resolveColors(in: properties)
        return (properties, owner)
    }

    struct Effective {
        let properties: XML.Element
        let text: XML.Element
        let fillOwner: Part
    }

    func effective(row: Int, column: Int) -> Effective {
        let properties = XML.Element("a:tcPr"), text = XML.Element("a:defRPr")
        var fillOwner = stylePart ?? table.part
        let flags = table.tbl.firstChild(named: "a:tblPr")
        func enabled(_ flag: String) -> Bool { flags.map { TableMergeTopology.flag($0, flag) } ?? false }
        let lastRow = grid.rows.count - 1, lastColumn = grid.columns.count - 1
        let leftColumn = enabled("rtl") ? lastColumn : 0
        let rightColumn = enabled("rtl") ? 0 : lastColumn
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
        for name in regions {
            guard let region = definition?.firstChild(named: "a:\(name)") else { continue }
            if let style = region.firstChild(named: "a:tcStyle") {
                if let fill = style.firstChild(named: "a:fill")?.childElements.first ?? referenceFill(style) {
                    setFill(fill, on: properties)
                }
                if let borders = style.firstChild(named: "a:tcBdr") {
                    for (edge, regionName, applies) in [
                        (TableCellBorder.left, "left", column == leftColumn || name != "wholeTbl"),
                        (.right, "right", column == rightColumn || name != "wholeTbl"),
                        (.top, "top", row == 0 || name != "wholeTbl"),
                        (.bottom, "bottom", row == lastRow || name != "wholeTbl"),
                        (.left, "insideV", column != leftColumn), (.right, "insideV", column != rightColumn),
                        (.top, "insideH", row > 0), (.bottom, "insideH", row < lastRow),
                        (.diagonalDown, "tl2br", true), (.diagonalUp, "tr2bl", true)
                    ] where applies {
                        guard let wrapper = borders.firstChild(named: "a:\(regionName)"),
                              let line = wrapper.firstChild(named: "a:ln") ?? referenceLine(wrapper) else { continue }
                        let copy = line.deepCopy(); copy.name = edge.rawValue
                        properties.removeChildren(named: edge.rawValue); properties.appendElement(copy)
                    }
                }
            }
            if let tx = region.firstChild(named: "a:tcTxStyle") { mergeText(tx, into: text) }
        }
        if grid.cells.indices.contains(row), grid.cells[row].indices.contains(column),
           let direct = grid.cells[row][column].firstChild(named: "a:tcPr") {
            for attribute in direct.attributes { properties[attribute: attribute.name] = attribute.value }
            for child in direct.childElements {
                if Fill.choiceNames.contains(child.name) {
                    setFill(child, on: properties); fillOwner = table.part
                } else {
                    properties.removeChildren(named: child.name); properties.appendElement(child.deepCopy())
                }
            }
        }
        resolveColors(in: properties)
        resolveColors(in: text)
        return Effective(properties: properties, text: text, fillOwner: fillOwner)
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
            let transforms: [ColorTransform] = node.childElements.compactMap { child in
                guard let value = child.boundedInt("val", in: -1_000_000...1_000_000) else { return nil }
                let fraction = Double(value) / 100_000
                switch child.name {
                case "a:tint": return .tint(fraction)
                case "a:shade": return .shade(fraction)
                case "a:lumMod": return .lumMod(fraction)
                case "a:lumOff": return .lumOff(fraction)
                case "a:satMod": return .satMod(fraction)
                default: return nil
                }
            }
            var resolved: Color?
            if node.name == "a:schemeClr", let raw = node[attribute: "val"], let scheme = SchemeColor(rawValue: raw) {
                resolved = theme.resolve(scheme, transforms: transforms)
            } else if node.name == "a:srgbClr", let raw = node[attribute: "val"], let color = Color(validating: raw) {
                var rgb = RGB(color)
                for transform in transforms { rgb = rgb.applying(transform) }
                resolved = rgb.color
            } else if node.name == "a:sysClr", let raw = node[attribute: "lastClr"] { resolved = Color(validating: raw) }
            if let resolved {
                node.name = "a:srgbClr"; node.attributes = [("val", resolved.hex)]
                node.children = node.children.filter { if case .element(let child) = $0 { return child.name == "a:alpha" }; return true }
            } else { stack.append(contentsOf: node.childElements) }
        }
    }

    static func definition(for table: XML.Element, package: OPCPackage?) -> (XML.Element?, Part?) {
        let properties = table.firstChild(named: "a:tblPr")
        if let inline = properties?.firstChild(named: "a:tableStyle") { return (inline, nil) }
        let id = properties?.firstChild(named: "a:tableStyleId")?.textContent
        if let package, let presentation = try? package.mainDocumentPart(),
           let styles = try? presentation.related(by: RelType.tableStyles, in: package), let root = try? styles.dom() {
            let desired = id ?? root[attribute: "def"]
            if let definition = root.children(named: "a:tblStyle").first(where: { $0[attribute: "styleId"]?.lowercased() == desired?.lowercased() }) { return (definition, styles) }
        }
        return (nil, nil)
    }
}
