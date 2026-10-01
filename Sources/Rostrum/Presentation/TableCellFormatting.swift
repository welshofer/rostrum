import Foundation

/// Physical cell edges, including both diagonals. Left/right remain physical
/// edges even when the table's visual column order is right-to-left.
public enum TableCellBorder: String, CaseIterable, Sendable {
    case left = "a:lnL", right = "a:lnR", top = "a:lnT", bottom = "a:lnB"
    case diagonalDown = "a:lnTlToBr", diagonalUp = "a:lnBlToTr"
}

public enum TableTextDirection: String, Sendable {
    case horizontal = "horz", vertical = "vert", vertical270 = "vert270"
    case wordArtVertical = "wordArtVert", eastAsianVertical = "eaVert"
    case mongolianVertical = "mongolianVert", wordArtVerticalRTL = "wordArtVertRtl"
}

public extension TableCell {
    /// The explicit border, or nil when inherited from the table style.
    func border(_ edge: TableCellBorder) -> ReadLine? {
        tc.firstChild(named: "a:tcPr")?.firstChild(named: edge.rawValue).map(ReadLine.init(element:))
    }

    /// Set an explicit border. A nil line suppresses this border; use
    /// `clearBorder` to restore inheritance from the table style.
    @discardableResult
    func setBorder(_ edge: TableCellBorder, line: Line?) -> TableCell {
        let element = Line.makeElement(line)
        element.name = edge.rawValue
        let property = tcPr
        if let existing = property.firstChild(named: edge.rawValue) {
            // Replace modeled line properties, retaining extension data.
            existing[attribute: "w"] = element[attribute: "w"]
            for name in Fill.choiceNames { existing.removeChildren(named: name) }
            if let fill = element.childElements.first {
                existing.insertChild(fill, beforeAnyOf: ["a:prstDash", "a:custDash", "a:round", "a:bevel", "a:miter", "a:headEnd", "a:tailEnd", "a:extLst"])
            }
        } else {
            let edges = TableCellBorder.allCases.map(\.rawValue)
            let index = edges.firstIndex(of: edge.rawValue)!
            property.insertChild(element, beforeAnyOf: Array(edges.dropFirst(index + 1)) + ["a:cell3D"] + Fill.choiceNames + ["a:headers", "a:extLst"])
        }
        part.markDirty()
        return self
    }

    @discardableResult
    func setBorders(_ line: Line?) -> TableCell {
        for edge in [TableCellBorder.left, .right, .top, .bottom] { setBorder(edge, line: line) }
        return self
    }

    @discardableResult
    func clearBorder(_ edge: TableCellBorder) -> TableCell {
        tc.firstChild(named: "a:tcPr")?.removeChildren(named: edge.rawValue)
        part.markDirty()
        return self
    }

    var textDirection: TableTextDirection {
        get { tc.firstChild(named: "a:tcPr")?[attribute: "vert"].flatMap(TableTextDirection.init(rawValue:)) ?? .horizontal }
        set { tcPr[attribute: "vert"] = newValue.rawValue; part.markDirty() }
    }
}

public extension Table {
    var styleID: String? {
        get { tbl.firstChild(named: "a:tblPr")?.firstChild(named: "a:tableStyleId")?.textContent }
        set {
            let properties = tbl.getOrAddChild("a:tblPr", beforeAnyOf: ["a:tblGrid"])
            properties.removeChildren(named: "a:tableStyle")
            if let newValue {
                properties.getOrAddChild("a:tableStyleId", beforeAnyOf: ["a:extLst"]).children = [.text(newValue)]
            } else { properties.removeChildren(named: "a:tableStyleId") }
            part.markDirty()
        }
    }

    var lastRowFooter: Bool {
        get { tableFlag("lastRow") } set { setTableFlag("lastRow", newValue) }
    }
    var firstColumnHeader: Bool {
        get { tableFlag("firstCol") } set { setTableFlag("firstCol", newValue) }
    }
    var lastColumnFooter: Bool {
        get { tableFlag("lastCol") } set { setTableFlag("lastCol", newValue) }
    }
    var bandedColumns: Bool {
        get { tableFlag("bandCol") } set { setTableFlag("bandCol", newValue) }
    }
    var rightToLeft: Bool {
        get { tableFlag("rtl") } set { setTableFlag("rtl", newValue) }
    }

    private func tableFlag(_ name: String) -> Bool {
        guard let properties = tbl.firstChild(named: "a:tblPr") else { return false }
        return TableMergeTopology.flag(properties, name)
    }
    private func setTableFlag(_ name: String, _ value: Bool) {
        tbl.getOrAddChild("a:tblPr", beforeAnyOf: ["a:tblGrid"])[attribute: name] = value ? "1" : nil
        part.markDirty()
    }

    /// Install a standalone custom table style in this presentation. The XML
    /// is copied, including unknown extensions. Relationship-bearing styles
    /// need a source part/package and are rejected before any modification.
    func setStyleDefinition(_ definition: XML.Element) throws {
        guard definition.name == "a:tblStyle", let id = definition[attribute: "styleId"], !id.isEmpty,
              let package else { throw RostrumError.packageInvalid("table style requires tblStyle/styleId and a package") }
        var stack = [definition]
        while let node = stack.popLast() {
            guard !node.attributes.contains(where: { $0.name.hasPrefix("r:") }) else {
                throw RostrumError.packageInvalid("standalone table style contains unresolved relationships")
            }
            stack.append(contentsOf: node.childElements)
        }
        let presentation = try package.mainDocumentPart()
        let existing = try presentation.rels.first(ofType: RelType.tableStyles).map {
            try package.part(at: PackURI.resolve(target: $0.target, relativeTo: presentation.uri.baseURI))
        }
        let root: XML.Element
        let stylePart: Part
        if let existing {
            root = try existing.dom()
            guard root.name == "a:tblStyleLst" else { throw RostrumError.packageInvalid("invalid table style list") }
            stylePart = existing
        } else {
            root = XML.Element("a:tblStyleLst", attributes: [("xmlns:a", "http://schemas.openxmlformats.org/drawingml/2006/main"), ("def", id)])
            var suffix = 1
            var uri = PackURI("/ppt/tableStyles.xml")
            while package.parts[uri] != nil { suffix += 1; uri = PackURI("/ppt/tableStyles\(suffix).xml") }
            stylePart = package.addPart(uri: uri, contentType: ContentType.tableStyles, blob: Data(root.serialized().utf8))
            package.contentTypes.setOverride(partName: uri, contentType: ContentType.tableStyles)
            presentation.rels.add(type: RelType.tableStyles, target: presentation.uri.relativeReference(to: uri))
        }
        // dom() above is already validated for existing parts. A new part is
        // constructed from valid XML before it is connected to the table.
        let targetRoot = existing == nil ? try stylePart.dom() : root
        let replacement = definition.deepCopy()
        if let old = targetRoot.children.firstIndex(where: {
            if case .element(let element) = $0 { return element.name == "a:tblStyle" && element[attribute: "styleId"] == id }
            return false
        }) { targetRoot.children[old] = .element(replacement) }
        else { targetRoot.insertChild(replacement, beforeAnyOf: ["a:extLst"]) }
        stylePart.markDirty()
        styleID = id
    }
}
