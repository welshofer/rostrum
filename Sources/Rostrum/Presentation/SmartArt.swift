import Foundation

/// SmartArt (DrawingML diagrams).
///
/// A diagram is a graphicFrame referencing a quadruplet of parts — data,
/// layout, quickStyle, colors — via `dgm:relIds`. Rostrum embeds its own
/// verified Basic Block List layout (a linear vertical list) and generates
/// the data model, including the presentation cache that LibreOffice needs
/// to render (PowerPoint runs the layout algorithm itself and ignores it).
/// Callers can also opt into `includeDrawing: true` (or use hierarchical
/// `SmartArt.Node` trees) to persist a `dsp:drawing` snapshot for immediate
/// SVG preview and third-party viewer fidelity.
public enum SmartArt {
    static let nsDGM = "http://schemas.openxmlformats.org/drawingml/2006/diagram"
    static let nsDSP = "http://schemas.microsoft.com/office/drawing/2008/diagram"
    static let layoutURN = "urn:rostrum/basicBlockList"
    static let hierarchyURN = "urn:rostrum/basicHierarchy"

    static let dataContentType = "application/vnd.openxmlformats-officedocument.drawingml.diagramData+xml"
    static let layoutContentType = "application/vnd.openxmlformats-officedocument.drawingml.diagramLayout+xml"
    /// Note the asymmetry: content type says diagramStyle, rel type says
    /// diagramQuickStyle. Swapping them is the classic hand-authoring bug.
    static let quickStyleContentType = "application/vnd.openxmlformats-officedocument.drawingml.diagramStyle+xml"
    static let colorsContentType = "application/vnd.openxmlformats-officedocument.drawingml.diagramColors+xml"
    static let drawingContentType = "application/vnd.ms-office.drawingml.diagramDrawing+xml"

    static let dataRelType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramData"
    static let layoutRelType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramLayout"
    static let quickStyleRelType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramQuickStyle"
    static let colorsRelType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramColors"
    static let drawingRelType = "http://schemas.microsoft.com/office/2007/relationships/diagramDrawing"

    /// A node in a hierarchical SmartArt diagram (e.g. an organization chart or tree).
    public struct Node: Sendable, Equatable {
        public var text: String
        public var children: [Node]

        public init(_ text: String, children: [Node] = []) {
            self.text = text
            self.children = children
        }
    }

    /// A SmartArt layout family. Each supplies its own `layoutDef` — the algorithm
    /// PowerPoint runs — and its gallery category; the data model, quick style, and
    /// colors are shared across all of them. Every layout is minimal, hand-authored,
    /// and verified to open without repair in PowerPoint + LibreOffice.
    public enum Layout: String, Sendable, CaseIterable {
        case blockList   // a vertical list of blocks (the original)
        case process     // a horizontal sequence of arrows (left → right) — PowerPoint-verified
        case cycle       // nodes on a ring with connectors (a loop) — PowerPoint-verified
        /// EXPERIMENTAL: PowerPoint's `pyra` engine renders this as a block grid, not a
        /// pyramid, with this minimal layoutDef (LibreOffice renders it correctly). Needs a
        /// faithful pyra definition; the demo uses the drawn `pyramidSlide` meanwhile.
        case pyramid

        /// Layout uniqueId (`loTypeId`), also the `presId` in the data model.
        public var urn: String {
            switch self {
            case .blockList: return SmartArt.layoutURN
            case .process:   return "urn:rostrum/basicProcess"
            case .pyramid:   return "urn:rostrum/basicPyramid"
            case .cycle:     return "urn:rostrum/basicCycle"
            }
        }
        /// Gallery category, and the document point's `loCatId`.
        var category: String {
            switch self {
            case .blockList: return "list"
            case .process:   return "process"
            case .pyramid:   return "pyramid"
            case .cycle:     return "cycle"
            }
        }
        var layoutXML: String {
            switch self {
            case .blockList: return SmartArt.blockListLayoutXML
            case .process:   return SmartArt.processLayoutXML
            case .pyramid:   return SmartArt.pyramidLayoutXML
            case .cycle:     return SmartArt.cycleLayoutXML
            }
        }
    }

    // MARK: - Data model generation

    /// The complete data1.xml for one level of `items` under the document
    /// root: item points, parTrans/sibTrans pairs, parent-of connections,
    /// and the presentation cache mirroring the layout instantiation.
    static func dataModelXML(items: [String], layout: Layout = .blockList, drawingRelID: String? = nil) -> String {
        let layoutURN = layout.urn   // drives loTypeId + every presId below
        let n = items.count
        var pts = ""
        var cxns = ""

        // Document root with gallery bookkeeping (loTypeId = layout uniqueId).
        pts += """
            <dgm:pt modelId="1" type="doc"><dgm:prSet loTypeId="\(layoutURN)" loCatId="\(layout.category)" qsTypeId="urn:microsoft.com/office/officeart/2005/8/quickstyle/simple1" qsCatId="simple" csTypeId="urn:microsoft.com/office/officeart/2005/8/colors/accent1_2" csCatId="accent1" phldr="1"/><dgm:spPr/>\(emptyT)</dgm:pt>
            """

        for (i, item) in items.enumerated() {
            let itemID = 2 + i
            let parTransID = n + 2 + 2 * i
            let sibTransID = n + 3 + 2 * i
            let cxnID = 3 * n + 2 + i
            pts += """
                <dgm:pt modelId="\(itemID)"><dgm:prSet phldrT="[Text]"/><dgm:spPr/><dgm:t><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US"/><a:t>\(escape(item))</a:t></a:r></a:p></dgm:t></dgm:pt>
                """
            pts += """
                <dgm:pt modelId="\(parTransID)" type="parTrans" cxnId="\(cxnID)"><dgm:prSet/><dgm:spPr/>\(emptyT)</dgm:pt><dgm:pt modelId="\(sibTransID)" type="sibTrans" cxnId="\(cxnID)"><dgm:prSet/><dgm:spPr/>\(emptyT)</dgm:pt>
                """
            cxns += """
                <dgm:cxn modelId="\(cxnID)" srcId="1" destId="\(itemID)" srcOrd="\(i)" destOrd="0" parTransId="\(parTransID)" sibTransId="\(sibTransID)"/>
                """
        }

        // Presentation cache: root, one node per item, spacers between.
        let presRoot = 4 * n + 10
        pts += """
            <dgm:pt modelId="\(presRoot)" type="pres"><dgm:prSet presAssocID="1" presName="diagram" presStyleCnt="0"><dgm:presLayoutVars><dgm:dir/><dgm:resizeHandles val="exact"/></dgm:presLayoutVars></dgm:prSet><dgm:spPr/></dgm:pt>
            """
        cxns += """
            <dgm:cxn modelId="\(6 * n + 20)" type="presOf" srcId="1" destId="\(presRoot)" srcOrd="0" destOrd="0" presId="\(layoutURN)"/>
            """
        var presParOfSeq = 0
        for i in 0..<n {
            let itemID = 2 + i
            let nodePres = 4 * n + 11 + 2 * i
            pts += """
                <dgm:pt modelId="\(nodePres)" type="pres"><dgm:prSet presAssocID="\(itemID)" presName="node" presStyleLbl="node1" presStyleIdx="\(i)" presStyleCnt="\(n)"><dgm:presLayoutVars><dgm:bulletEnabled val="1"/></dgm:presLayoutVars></dgm:prSet><dgm:spPr/></dgm:pt>
                """
            cxns += """
                <dgm:cxn modelId="\(6 * n + 21 + i)" type="presOf" srcId="\(itemID)" destId="\(nodePres)" srcOrd="0" destOrd="0" presId="\(layoutURN)"/>
                """
            cxns += """
                <dgm:cxn modelId="\(8 * n + 30 + presParOfSeq)" type="presParOf" srcId="\(presRoot)" destId="\(nodePres)" srcOrd="\(presParOfSeq)" destOrd="0" presId="\(layoutURN)"/>
                """
            presParOfSeq += 1
            if i < n - 1 {
                let spacerPres = 4 * n + 12 + 2 * i
                let sibTransID = n + 3 + 2 * i
                pts += """
                    <dgm:pt modelId="\(spacerPres)" type="pres"><dgm:prSet presAssocID="\(sibTransID)" presName="sibTrans" presStyleCnt="0"/><dgm:spPr/></dgm:pt>
                    """
                cxns += """
                    <dgm:cxn modelId="\(8 * n + 30 + presParOfSeq)" type="presParOf" srcId="\(presRoot)" destId="\(spacerPres)" srcOrd="\(presParOfSeq)" destOrd="0" presId="\(layoutURN)"/>
                    """
                presParOfSeq += 1
            }
        }

        let ext = drawingRelID.map {
            "<dgm:extLst><a:ext uri=\"{C1C4B2C5-EE94-4FBA-B6DD-F449D9B2D5BA}\"><dsp:dataModelExt xmlns:dsp=\"\(nsDSP)\" relId=\"\($0)\"/></a:ext></dgm:extLst>"
        } ?? ""

        return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <dgm:dataModel xmlns:dgm="\(nsDGM)" xmlns:a="\(MinimalTemplate.nsA)"><dgm:ptLst>\(pts)</dgm:ptLst><dgm:cxnLst>\(cxns)</dgm:cxnLst><dgm:bg/><dgm:whole/>\(ext)</dgm:dataModel>
            """
    }

    /// Multi-level hierarchy `dataModel` XML from a forest of `SmartArt.Node` roots.
    static func hierarchyDataModelXML(nodes: [Node], drawingRelID: String? = nil) -> String {
        var pts = """
            <dgm:pt modelId="1" type="doc"><dgm:prSet loTypeId="\(hierarchyURN)" loCatId="hierarchy" qsTypeId="urn:microsoft.com/office/officeart/2005/8/quickstyle/simple1" qsCatId="simple" csTypeId="urn:microsoft.com/office/officeart/2005/8/colors/accent1_2" csCatId="accent1" phldr="1"/><dgm:spPr/>\(emptyT)</dgm:pt>
            """
        var cxns = ""
        var nextID = 2
        func alloc() -> Int { defer { nextID += 1 }; return nextID }

        var flatNodes: [Int] = []
        func visit(_ list: [Node], parentID: Int) {
            for (ord, node) in list.enumerated() {
                let itemID = alloc()
                let parTransID = alloc()
                let sibTransID = alloc()
                let cxnID = alloc()
                flatNodes.append(itemID)
                pts += "<dgm:pt modelId=\"\(itemID)\"><dgm:prSet phldrT=\"[Text]\"/><dgm:spPr/><dgm:t><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang=\"en-US\"/><a:t>\(escape(node.text))</a:t></a:r></a:p></dgm:t></dgm:pt>"
                pts += "<dgm:pt modelId=\"\(parTransID)\" type=\"parTrans\" cxnId=\"\(cxnID)\"><dgm:prSet/><dgm:spPr/>\(emptyT)</dgm:pt>"
                pts += "<dgm:pt modelId=\"\(sibTransID)\" type=\"sibTrans\" cxnId=\"\(cxnID)\"><dgm:prSet/><dgm:spPr/>\(emptyT)</dgm:pt>"
                cxns += "<dgm:cxn modelId=\"\(cxnID)\" srcId=\"\(parentID)\" destId=\"\(itemID)\" srcOrd=\"\(ord)\" destOrd=\"0\" parTransId=\"\(parTransID)\" sibTransId=\"\(sibTransID)\"/>"
                if !node.children.isEmpty {
                    visit(node.children, parentID: itemID)
                }
            }
        }
        visit(nodes, parentID: 1)

        let presRoot = alloc()
        pts += "<dgm:pt modelId=\"\(presRoot)\" type=\"pres\"><dgm:prSet presAssocID=\"1\" presName=\"diagram\" presStyleCnt=\"0\"><dgm:presLayoutVars><dgm:dir/><dgm:resizeHandles val=\"exact\"/></dgm:presLayoutVars></dgm:prSet><dgm:spPr/></dgm:pt>"
        cxns += "<dgm:cxn modelId=\"\(alloc())\" type=\"presOf\" srcId=\"1\" destId=\"\(presRoot)\" srcOrd=\"0\" destOrd=\"0\" presId=\"\(hierarchyURN)\"/>"
        for (i, itemID) in flatNodes.enumerated() {
            let nodePres = alloc()
            pts += "<dgm:pt modelId=\"\(nodePres)\" type=\"pres\"><dgm:prSet presAssocID=\"\(itemID)\" presName=\"node\" presStyleLbl=\"node1\" presStyleIdx=\"\(i)\" presStyleCnt=\"\(flatNodes.count)\"/><dgm:spPr/></dgm:pt>"
            cxns += "<dgm:cxn modelId=\"\(alloc())\" type=\"presOf\" srcId=\"\(itemID)\" destId=\"\(nodePres)\" srcOrd=\"0\" destOrd=\"0\" presId=\"\(hierarchyURN)\"/>"
            cxns += "<dgm:cxn modelId=\"\(alloc())\" type=\"presParOf\" srcId=\"\(presRoot)\" destId=\"\(nodePres)\" srcOrd=\"\(i)\" destOrd=\"0\" presId=\"\(hierarchyURN)\"/>"
        }

        let ext = drawingRelID.map {
            "<dgm:extLst><a:ext uri=\"{C1C4B2C5-EE94-4FBA-B6DD-F449D9B2D5BA}\"><dsp:dataModelExt xmlns:dsp=\"\(nsDSP)\" relId=\"\($0)\"/></a:ext></dgm:extLst>"
        } ?? ""

        return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <dgm:dataModel xmlns:dgm="\(nsDGM)" xmlns:a="\(MinimalTemplate.nsA)"><dgm:ptLst>\(pts)</dgm:ptLst><dgm:cxnLst>\(cxns)</dgm:cxnLst><dgm:bg/><dgm:whole/>\(ext)</dgm:dataModel>
            """
    }

    // MARK: - Cached Drawing Generation (dsp:drawing)

    static func cachedDrawingXML(items: [String], frame: Rect, colors: [Color]?, layout: Layout) -> String {
        let W = max(1, frame.width.rawValue)
        let H = max(1, frame.height.rawValue)
        let n = max(1, items.count)
        let palette = (colors?.isEmpty == false ? colors! : [Color("4472C4")])
        func fillHex(_ i: Int) -> String { palette[i % palette.count].hex }
        func textHex(_ i: Int) -> String { Color.bestTextColor(on: palette[i % palette.count]).hex }

        var shapes = ""
        var shapeID = 1
        func addShape(preset: String, x: Int, y: Int, w: Int, h: Int, text: String, colorIndex: Int) {
            defer { shapeID += 1 }
            shapes += """
                <dsp:sp modelId="\(shapeID + 1)"><dsp:nvSpPr><dsp:cNvPr id="\(shapeID)" name="Node \(shapeID)"/><dsp:cNvSpPr/></dsp:nvSpPr><dsp:spPr><a:xfrm><a:off x="\(x)" y="\(y)"/><a:ext cx="\(max(1, w))" cy="\(max(1, h))"/></a:xfrm><a:prstGeom prst="\(preset)"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="\(fillHex(colorIndex))"/></a:solidFill></dsp:spPr><dsp:txBody><a:bodyPr anchor="ctr"/><a:lstStyle/><a:p><a:pPr algn="ctr"/><a:r><a:rPr lang="en-US" sz="1600"><a:solidFill><a:srgbClr val="\(textHex(colorIndex))"/></a:solidFill></a:rPr><a:t>\(escape(text))</a:t></a:r></a:p></dsp:txBody></dsp:sp>
                """
        }
        func addConnector(preset: String, x: Int, y: Int, w: Int, h: Int, flipH: Bool = false, flipV: Bool = false) {
            defer { shapeID += 1 }
            var attrs = ""
            if flipH { attrs += " flipH=\"1\"" }
            if flipV { attrs += " flipV=\"1\"" }
            shapes += """
                <dsp:cxnSp modelId="\(shapeID + 100)"><dsp:nvCxnSpPr><dsp:cNvPr id="\(shapeID)" name="Connector \(shapeID)"/><dsp:cNvCxnSpPr/></dsp:nvCxnSpPr><dsp:spPr><a:xfrm\(attrs)><a:off x="\(x)" y="\(y)"/><a:ext cx="\(max(0, w))" cy="\(max(0, h))"/></a:xfrm><a:prstGeom prst="\(preset)"><a:avLst/></a:prstGeom><a:ln w="19050"><a:solidFill><a:srgbClr val="\(fillHex(0))"/></a:solidFill><a:tailEnd type="triangle"/></a:ln></dsp:spPr></dsp:cxnSp>
                """
        }

        switch layout {
        case .blockList:
            let gap = H / max(1, n * 6)
            let itemH = max(1, (H - gap * max(0, n - 1)) / n)
            for (i, item) in items.enumerated() {
                addShape(preset: "roundRect", x: 0, y: i * (itemH + gap), w: W, h: itemH, text: item, colorIndex: i)
            }
        case .process:
            let gap = W / max(1, n * 6)
            let itemW = max(1, (W - gap * max(0, n - 1)) / n)
            let itemH = Int(Double(H) * 0.65)
            let topY = (H - itemH) / 2
            for (i, item) in items.enumerated() {
                let ix = i * (itemW + gap)
                addShape(preset: "homePlate", x: ix, y: topY, w: itemW, h: itemH, text: item, colorIndex: i)
                if i < n - 1 {
                    addConnector(preset: "straightConnector1", x: ix + itemW, y: H / 2, w: gap, h: 0)
                }
            }
        case .pyramid:
            let gap = H / max(1, n * 8)
            let sliceH = max(1, (H - gap * max(0, n - 1)) / n)
            for (i, item) in items.enumerated() {
                let ratio = Double(i + 1) / Double(n)
                let sliceW = max(1, Int(Double(W) * (0.35 + 0.65 * ratio)))
                let ix = (W - sliceW) / 2
                addShape(preset: "trapezoid", x: ix, y: i * (sliceH + gap), w: sliceW, h: sliceH, text: item, colorIndex: i)
            }
        case .cycle:
            let cx = Double(W) / 2, cy = Double(H) / 2
            let rx = Double(W) * 0.34, ry = Double(H) * 0.32
            let nodeW = max(1, Int(Double(W) * 0.24)), nodeH = max(1, Int(Double(H) * 0.24))
            var centers: [(Int, Int)] = []
            for (i, item) in items.enumerated() {
                let angle = -.pi / 2 + 2 * .pi * Double(i) / Double(n)
                let nx = Int((cx + rx * cos(angle)).rounded()) - nodeW / 2
                let ny = Int((cy + ry * sin(angle)).rounded()) - nodeH / 2
                centers.append((nx + nodeW / 2, ny + nodeH / 2))
                addShape(preset: "ellipse", x: nx, y: ny, w: nodeW, h: nodeH, text: item, colorIndex: i)
            }
            if centers.count > 1 {
                for i in 0..<centers.count {
                    let c1 = centers[i], c2 = centers[(i + 1) % centers.count]
                    let minX = min(c1.0, c2.0), minY = min(c1.1, c2.1)
                    addConnector(preset: "curvedConnector2", x: minX, y: minY,
                                 w: abs(c2.0 - c1.0), h: abs(c2.1 - c1.1),
                                 flipH: c2.0 < c1.0, flipV: c2.1 < c1.1)
                }
            }
        }

        return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <dsp:drawing xmlns:dsp="\(nsDSP)" xmlns:a="\(MinimalTemplate.nsA)"><dsp:spTree><dsp:nvGrpSpPr><dsp:cNvPr id="0" name=""/><dsp:cNvGrpSpPr/></dsp:nvGrpSpPr><dsp:grpSpPr/>\(shapes)</dsp:spTree></dsp:drawing>
            """
    }

    static func cachedHierarchyDrawingXML(nodes: [Node], frame: Rect, colors: [Color]?) -> String {
        let W = max(1, frame.width.rawValue)
        let H = max(1, frame.height.rawValue)
        let palette = (colors?.isEmpty == false ? colors! : [Color("4472C4"), Color("ED7D31"), Color("70AD47")])
        func fillHex(_ depth: Int) -> String { palette[depth % palette.count].hex }
        func textHex(_ depth: Int) -> String { Color.bestTextColor(on: palette[depth % palette.count]).hex }

        // Group nodes by depth and track parent-child index pairs.
        var levels: [[(text: String, parentIndex: Int?)]] = []
        func collect(_ list: [Node], depth: Int, parentIndex: Int?) {
            guard !list.isEmpty else { return }
            while levels.count <= depth { levels.append([]) }
            for node in list {
                let myIndex = levels[depth].count
                levels[depth].append((node.text, parentIndex))
                collect(node.children, depth: depth + 1, parentIndex: myIndex)
            }
        }
        collect(nodes, depth: 0, parentIndex: nil)

        let depthCount = max(1, levels.count)
        let vGap = H / max(1, depthCount * 5)
        let boxH = max(1, (H - vGap * max(0, depthCount - 1)) / depthCount)
        var boxFrames: [[(x: Int, y: Int, w: Int, h: Int)]] = []
        var shapes = ""
        var shapeID = 1

        for (depth, row) in levels.enumerated() {
            let count = max(1, row.count)
            let hGap = W / max(1, count * 6)
            let boxW = max(1, min(W / 2, (W - hGap * max(0, count - 1)) / count))
            let totalRowW = count * boxW + max(0, count - 1) * hGap
            let startX = max(0, (W - totalRowW) / 2)
            let y = depth * (boxH + vGap)
            var rowFrames: [(x: Int, y: Int, w: Int, h: Int)] = []
            for (i, item) in row.enumerated() {
                let x = startX + i * (boxW + hGap)
                rowFrames.append((x, y, boxW, boxH))
                shapes += """
                    <dsp:sp modelId="\(shapeID + 1)"><dsp:nvSpPr><dsp:cNvPr id="\(shapeID)" name="Node \(shapeID)"/><dsp:cNvSpPr/></dsp:nvSpPr><dsp:spPr><a:xfrm><a:off x="\(x)" y="\(y)"/><a:ext cx="\(boxW)" cy="\(boxH)"/></a:xfrm><a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="\(fillHex(depth))"/></a:solidFill></dsp:spPr><dsp:txBody><a:bodyPr anchor="ctr"/><a:lstStyle/><a:p><a:pPr algn="ctr"/><a:r><a:rPr lang="en-US" sz="1400"><a:solidFill><a:srgbClr val="\(textHex(depth))"/></a:solidFill></a:rPr><a:t>\(escape(item.text))</a:t></a:r></a:p></dsp:txBody></dsp:sp>
                    """
                shapeID += 1
            }
            boxFrames.append(rowFrames)
        }

        // Emit orthogonal connectors from each parent bottom-center to child top-center.
        for depth in 1..<levels.count {
            for (i, item) in levels[depth].enumerated() {
                guard let pIdx = item.parentIndex, pIdx < boxFrames[depth - 1].count else { continue }
                let parent = boxFrames[depth - 1][pIdx]
                let child = boxFrames[depth][i]
                let x1 = parent.x + parent.w / 2, y1 = parent.y + parent.h
                let x2 = child.x + child.w / 2, y2 = child.y
                let minX = min(x1, x2), minY = min(y1, y2)
                let cw = abs(x2 - x1), ch = abs(y2 - y1)
                let flipH = x2 < x1 ? " flipH=\"1\"" : ""
                shapes += """
                    <dsp:cxnSp modelId="\(shapeID + 100)"><dsp:nvCxnSpPr><dsp:cNvPr id="\(shapeID)" name="Connector \(shapeID)"/><dsp:cNvCxnSpPr/></dsp:nvCxnSpPr><dsp:spPr><a:xfrm\(flipH)><a:off x="\(minX)" y="\(minY)"/><a:ext cx="\(cw)" cy="\(ch)"/></a:xfrm><a:prstGeom prst="bentConnector3"><a:avLst/></a:prstGeom><a:ln w="12700"><a:solidFill><a:srgbClr val="808080"/></a:solidFill></a:ln></dsp:spPr></dsp:cxnSp>
                    """
                shapeID += 1
            }
        }

        return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <dsp:drawing xmlns:dsp="\(nsDSP)" xmlns:a="\(MinimalTemplate.nsA)"><dsp:spTree><dsp:nvGrpSpPr><dsp:cNvPr id="0" name=""/><dsp:cNvGrpSpPr/></dsp:nvGrpSpPr><dsp:grpSpPr/>\(shapes)</dsp:spTree></dsp:drawing>
            """
    }

    private static let emptyT = "<dgm:t><a:bodyPr/><a:lstStyle/><a:p><a:endParaRPr lang=\"en-US\"/></a:p></dgm:t>"

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - Static parts (verified in PowerPoint 16.111 + LibreOffice 26.2)

    static let blockListLayoutXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <dgm:layoutDef xmlns:dgm="\(nsDGM)" xmlns:a="\(MinimalTemplate.nsA)" uniqueId="\(layoutURN)"><dgm:title val="Basic Block List"/><dgm:desc val=""/><dgm:catLst><dgm:cat type="list" pri="1000"/></dgm:catLst><dgm:sampData useDef="1"><dgm:dataModel><dgm:ptLst/><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:sampData><dgm:styleData><dgm:dataModel><dgm:ptLst><dgm:pt modelId="0" type="doc"/><dgm:pt modelId="1"/><dgm:pt modelId="2"/></dgm:ptLst><dgm:cxnLst><dgm:cxn modelId="3" srcId="0" destId="1" srcOrd="0" destOrd="0"/><dgm:cxn modelId="4" srcId="0" destId="2" srcOrd="1" destOrd="0"/></dgm:cxnLst><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:styleData><dgm:clrData><dgm:dataModel><dgm:ptLst><dgm:pt modelId="0" type="doc"/><dgm:pt modelId="1"/><dgm:pt modelId="2"/><dgm:pt modelId="3"/><dgm:pt modelId="4"/></dgm:ptLst><dgm:cxnLst><dgm:cxn modelId="5" srcId="0" destId="1" srcOrd="0" destOrd="0"/><dgm:cxn modelId="6" srcId="0" destId="2" srcOrd="1" destOrd="0"/><dgm:cxn modelId="7" srcId="0" destId="3" srcOrd="2" destOrd="0"/><dgm:cxn modelId="8" srcId="0" destId="4" srcOrd="3" destOrd="0"/></dgm:cxnLst><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:clrData><dgm:layoutNode name="diagram"><dgm:varLst><dgm:dir/><dgm:resizeHandles val="exact"/></dgm:varLst><dgm:alg type="lin"><dgm:param type="linDir" val="fromT"/></dgm:alg><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" r:blip=""><dgm:adjLst/></dgm:shape><dgm:presOf/><dgm:constrLst><dgm:constr type="w" for="ch" ptType="node" refType="w"/><dgm:constr type="h" for="ch" ptType="node" refType="h" fact="0.3"/><dgm:constr type="h" for="ch" forName="sibTrans" refType="h" fact="0.05"/><dgm:constr type="primFontSz" for="ch" ptType="node" op="equ" val="65"/></dgm:constrLst><dgm:ruleLst/><dgm:forEach name="nodesForEach" axis="ch" ptType="node"><dgm:layoutNode name="node" styleLbl="node1"><dgm:varLst><dgm:bulletEnabled val="1"/></dgm:varLst><dgm:alg type="tx"/><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" type="rect" r:blip=""><dgm:adjLst/></dgm:shape><dgm:presOf axis="desOrSelf" ptType="node"/><dgm:constrLst><dgm:constr type="lMarg" refType="primFontSz" fact="0.3"/><dgm:constr type="rMarg" refType="primFontSz" fact="0.3"/><dgm:constr type="tMarg" refType="primFontSz" fact="0.3"/><dgm:constr type="bMarg" refType="primFontSz" fact="0.3"/></dgm:constrLst><dgm:ruleLst><dgm:rule type="primFontSz" val="5" fact="NaN" max="NaN"/></dgm:ruleLst></dgm:layoutNode><dgm:forEach name="sibTransForEach" axis="followSib" ptType="sibTrans" cnt="1"><dgm:layoutNode name="sibTrans"><dgm:alg type="sp"/><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" r:blip=""><dgm:adjLst/></dgm:shape><dgm:presOf/><dgm:constrLst/><dgm:ruleLst/></dgm:layoutNode></dgm:forEach></dgm:forEach></dgm:layoutNode></dgm:layoutDef>
        """

    /// Basic Process: a horizontal (left→right) linear sequence of chevron nodes.
    /// Same data model, quick style, and colors as the block list — only the
    /// algorithm differs: `linDir=fromL` lays the nodes out in a row, each drawn
    /// as a `chevron` so the sequence reads directionally, with a thin spacer
    /// between them. Mirrors the block list's structure so its presentation cache
    /// (and LibreOffice rendering) stays valid.
    static let processLayoutXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <dgm:layoutDef xmlns:dgm="\(nsDGM)" xmlns:a="\(MinimalTemplate.nsA)" uniqueId="\(Layout.process.urn)"><dgm:title val="Basic Process"/><dgm:desc val=""/><dgm:catLst><dgm:cat type="process" pri="2000"/></dgm:catLst><dgm:sampData useDef="1"><dgm:dataModel><dgm:ptLst/><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:sampData><dgm:styleData><dgm:dataModel><dgm:ptLst><dgm:pt modelId="0" type="doc"/><dgm:pt modelId="1"/><dgm:pt modelId="2"/></dgm:ptLst><dgm:cxnLst><dgm:cxn modelId="3" srcId="0" destId="1" srcOrd="0" destOrd="0"/><dgm:cxn modelId="4" srcId="0" destId="2" srcOrd="1" destOrd="0"/></dgm:cxnLst><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:styleData><dgm:clrData><dgm:dataModel><dgm:ptLst><dgm:pt modelId="0" type="doc"/><dgm:pt modelId="1"/><dgm:pt modelId="2"/><dgm:pt modelId="3"/><dgm:pt modelId="4"/></dgm:ptLst><dgm:cxnLst><dgm:cxn modelId="5" srcId="0" destId="1" srcOrd="0" destOrd="0"/><dgm:cxn modelId="6" srcId="0" destId="2" srcOrd="1" destOrd="0"/><dgm:cxn modelId="7" srcId="0" destId="3" srcOrd="2" destOrd="0"/><dgm:cxn modelId="8" srcId="0" destId="4" srcOrd="3" destOrd="0"/></dgm:cxnLst><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:clrData><dgm:layoutNode name="diagram"><dgm:varLst><dgm:dir/><dgm:resizeHandles val="exact"/></dgm:varLst><dgm:alg type="lin"><dgm:param type="linDir" val="fromL"/></dgm:alg><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" r:blip=""><dgm:adjLst/></dgm:shape><dgm:presOf/><dgm:constrLst><dgm:constr type="h" for="ch" ptType="node" refType="h" fact="0.62"/><dgm:constr type="w" for="ch" forName="sibTrans" refType="w" fact="0.04"/><dgm:constr type="primFontSz" for="ch" ptType="node" op="equ" val="65"/></dgm:constrLst><dgm:ruleLst/><dgm:forEach name="nodesForEach" axis="ch" ptType="node"><dgm:layoutNode name="node" styleLbl="node1"><dgm:varLst><dgm:bulletEnabled val="1"/></dgm:varLst><dgm:alg type="tx"/><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" type="homePlate" r:blip=""><dgm:adjLst><dgm:adj idx="1" val="0.2"/></dgm:adjLst></dgm:shape><dgm:presOf axis="desOrSelf" ptType="node"/><dgm:constrLst><dgm:constr type="lMarg" refType="primFontSz" fact="0.4"/><dgm:constr type="rMarg" refType="primFontSz" fact="0.4"/><dgm:constr type="tMarg" refType="primFontSz" fact="0.3"/><dgm:constr type="bMarg" refType="primFontSz" fact="0.3"/></dgm:constrLst><dgm:ruleLst><dgm:rule type="primFontSz" val="5" fact="NaN" max="NaN"/></dgm:ruleLst></dgm:layoutNode><dgm:forEach name="sibTransForEach" axis="followSib" ptType="sibTrans" cnt="1"><dgm:layoutNode name="sibTrans"><dgm:alg type="sp"/><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" r:blip=""><dgm:adjLst/></dgm:shape><dgm:presOf/><dgm:constrLst/><dgm:ruleLst/></dgm:layoutNode></dgm:forEach></dgm:forEach></dgm:layoutNode></dgm:layoutDef>
        """

    /// Basic Pyramid: stacked trapezoid levels, widest at the base (`pyraLvlDir`
    /// fromB). The `pyra` algorithm graduates each slice's width into a triangle;
    /// nodes share the model with a `sibTrans` spacer so the presentation cache
    /// stays consistent with the block list / process.
    static let pyramidLayoutXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <dgm:layoutDef xmlns:dgm="\(nsDGM)" xmlns:a="\(MinimalTemplate.nsA)" uniqueId="\(Layout.pyramid.urn)"><dgm:title val="Basic Pyramid"/><dgm:desc val=""/><dgm:catLst><dgm:cat type="pyramid" pri="3000"/></dgm:catLst><dgm:sampData useDef="1"><dgm:dataModel><dgm:ptLst/><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:sampData><dgm:styleData><dgm:dataModel><dgm:ptLst><dgm:pt modelId="0" type="doc"/><dgm:pt modelId="1"/><dgm:pt modelId="2"/></dgm:ptLst><dgm:cxnLst><dgm:cxn modelId="3" srcId="0" destId="1" srcOrd="0" destOrd="0"/><dgm:cxn modelId="4" srcId="0" destId="2" srcOrd="1" destOrd="0"/></dgm:cxnLst><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:styleData><dgm:clrData><dgm:dataModel><dgm:ptLst><dgm:pt modelId="0" type="doc"/><dgm:pt modelId="1"/><dgm:pt modelId="2"/><dgm:pt modelId="3"/><dgm:pt modelId="4"/></dgm:ptLst><dgm:cxnLst><dgm:cxn modelId="5" srcId="0" destId="1" srcOrd="0" destOrd="0"/><dgm:cxn modelId="6" srcId="0" destId="2" srcOrd="1" destOrd="0"/><dgm:cxn modelId="7" srcId="0" destId="3" srcOrd="2" destOrd="0"/><dgm:cxn modelId="8" srcId="0" destId="4" srcOrd="3" destOrd="0"/></dgm:cxnLst><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:clrData><dgm:layoutNode name="diagram"><dgm:varLst><dgm:dir/><dgm:resizeHandles val="exact"/></dgm:varLst><dgm:alg type="pyra"><dgm:param type="pyraLvlDir" val="fromB"/></dgm:alg><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" type="trapezoid" r:blip=""><dgm:adjLst/></dgm:shape><dgm:presOf/><dgm:constrLst><dgm:constr type="w" for="ch" ptType="node" refType="w"/><dgm:constr type="h" for="ch" ptType="node" refType="h" fact="0.28"/><dgm:constr type="h" for="ch" forName="sibTrans" refType="h" fact="0.04"/><dgm:constr type="primFontSz" for="ch" ptType="node" op="equ" val="65"/></dgm:constrLst><dgm:ruleLst/><dgm:forEach name="nodesForEach" axis="ch" ptType="node"><dgm:layoutNode name="node" styleLbl="node1"><dgm:varLst><dgm:bulletEnabled val="1"/></dgm:varLst><dgm:alg type="tx"/><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" type="trapezoid" r:blip=""><dgm:adjLst/></dgm:shape><dgm:presOf axis="desOrSelf" ptType="node"/><dgm:constrLst><dgm:constr type="lMarg" refType="primFontSz" fact="0.3"/><dgm:constr type="rMarg" refType="primFontSz" fact="0.3"/><dgm:constr type="tMarg" refType="primFontSz" fact="0.3"/><dgm:constr type="bMarg" refType="primFontSz" fact="0.3"/></dgm:constrLst><dgm:ruleLst><dgm:rule type="primFontSz" val="5" fact="NaN" max="NaN"/></dgm:ruleLst></dgm:layoutNode><dgm:forEach name="sibTransForEach" axis="followSib" ptType="sibTrans" cnt="1"><dgm:layoutNode name="sibTrans"><dgm:alg type="sp"/><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" r:blip=""><dgm:adjLst/></dgm:shape><dgm:presOf/><dgm:constrLst/><dgm:ruleLst/></dgm:layoutNode></dgm:forEach></dgm:forEach></dgm:layoutNode></dgm:layoutDef>
        """

    /// Basic Cycle: nodes evenly spaced on a ring (`cycle` algorithm, 360°) as
    /// ellipses, with curved arrow connectors between them. Same model + cache
    /// shape; the `sibTrans` becomes a `conn` connector instead of a spacer.
    static let cycleLayoutXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <dgm:layoutDef xmlns:dgm="\(nsDGM)" xmlns:a="\(MinimalTemplate.nsA)" uniqueId="\(Layout.cycle.urn)"><dgm:title val="Basic Cycle"/><dgm:desc val=""/><dgm:catLst><dgm:cat type="cycle" pri="4000"/></dgm:catLst><dgm:sampData useDef="1"><dgm:dataModel><dgm:ptLst/><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:sampData><dgm:styleData><dgm:dataModel><dgm:ptLst><dgm:pt modelId="0" type="doc"/><dgm:pt modelId="1"/><dgm:pt modelId="2"/></dgm:ptLst><dgm:cxnLst><dgm:cxn modelId="3" srcId="0" destId="1" srcOrd="0" destOrd="0"/><dgm:cxn modelId="4" srcId="0" destId="2" srcOrd="1" destOrd="0"/></dgm:cxnLst><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:styleData><dgm:clrData><dgm:dataModel><dgm:ptLst><dgm:pt modelId="0" type="doc"/><dgm:pt modelId="1"/><dgm:pt modelId="2"/><dgm:pt modelId="3"/><dgm:pt modelId="4"/></dgm:ptLst><dgm:cxnLst><dgm:cxn modelId="5" srcId="0" destId="1" srcOrd="0" destOrd="0"/><dgm:cxn modelId="6" srcId="0" destId="2" srcOrd="1" destOrd="0"/><dgm:cxn modelId="7" srcId="0" destId="3" srcOrd="2" destOrd="0"/><dgm:cxn modelId="8" srcId="0" destId="4" srcOrd="3" destOrd="0"/></dgm:cxnLst><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:clrData><dgm:layoutNode name="diagram"><dgm:varLst><dgm:dir/><dgm:resizeHandles val="exact"/></dgm:varLst><dgm:alg type="cycle"><dgm:param type="stAng" val="0"/><dgm:param type="spanAng" val="360"/></dgm:alg><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" r:blip=""><dgm:adjLst/></dgm:shape><dgm:presOf/><dgm:constrLst><dgm:constr type="w" for="ch" ptType="node" refType="w" fact="0.26"/><dgm:constr type="h" for="ch" ptType="node" refType="h" fact="0.26"/><dgm:constr type="primFontSz" for="ch" ptType="node" op="equ" val="65"/></dgm:constrLst><dgm:ruleLst/><dgm:forEach name="nodesForEach" axis="ch" ptType="node"><dgm:layoutNode name="node" styleLbl="node1"><dgm:varLst><dgm:bulletEnabled val="1"/></dgm:varLst><dgm:alg type="tx"/><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" type="ellipse" r:blip=""><dgm:adjLst/></dgm:shape><dgm:presOf axis="desOrSelf" ptType="node"/><dgm:constrLst><dgm:constr type="lMarg" refType="primFontSz" fact="0.3"/><dgm:constr type="rMarg" refType="primFontSz" fact="0.3"/><dgm:constr type="tMarg" refType="primFontSz" fact="0.3"/><dgm:constr type="bMarg" refType="primFontSz" fact="0.3"/></dgm:constrLst><dgm:ruleLst><dgm:rule type="primFontSz" val="5" fact="NaN" max="NaN"/></dgm:ruleLst></dgm:layoutNode><dgm:forEach name="sibTransForEach" axis="followSib" ptType="sibTrans" cnt="1"><dgm:layoutNode name="sibTrans"><dgm:alg type="conn"><dgm:param type="connRout" val="curve"/><dgm:param type="begPts" val="radial"/><dgm:param type="endPts" val="radial"/><dgm:param type="srcNode" val="node"/><dgm:param type="dstNode" val="node"/><dgm:param type="endSty" val="arr"/></dgm:alg><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" type="conn" r:blip=""><dgm:adjLst/></dgm:shape><dgm:presOf/><dgm:constrLst><dgm:constr type="begPad"/><dgm:constr type="endPad"/></dgm:constrLst><dgm:ruleLst/></dgm:layoutNode></dgm:forEach></dgm:forEach></dgm:layoutNode></dgm:layoutDef>
        """

    static let hierarchyLayoutXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <dgm:layoutDef xmlns:dgm="\(nsDGM)" xmlns:a="\(MinimalTemplate.nsA)" uniqueId="\(hierarchyURN)"><dgm:title val="Hierarchy"/><dgm:desc val=""/><dgm:catLst><dgm:cat type="hierarchy" pri="5000"/></dgm:catLst><dgm:sampData useDef="1"><dgm:dataModel><dgm:ptLst/><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:sampData><dgm:styleData><dgm:dataModel><dgm:ptLst><dgm:pt modelId="0" type="doc"/><dgm:pt modelId="1"/><dgm:pt modelId="2"/></dgm:ptLst><dgm:cxnLst><dgm:cxn modelId="3" srcId="0" destId="1" srcOrd="0" destOrd="0"/><dgm:cxn modelId="4" srcId="1" destId="2" srcOrd="0" destOrd="0"/></dgm:cxnLst><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:styleData><dgm:clrData><dgm:dataModel><dgm:ptLst><dgm:pt modelId="0" type="doc"/><dgm:pt modelId="1"/><dgm:pt modelId="2"/></dgm:ptLst><dgm:cxnLst><dgm:cxn modelId="3" srcId="0" destId="1" srcOrd="0" destOrd="0"/><dgm:cxn modelId="4" srcId="1" destId="2" srcOrd="0" destOrd="0"/></dgm:cxnLst><dgm:bg/><dgm:whole/></dgm:dataModel></dgm:clrData><dgm:layoutNode name="diagram"><dgm:varLst><dgm:dir/><dgm:resizeHandles val="exact"/></dgm:varLst><dgm:alg type="hierRoot"/><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" r:blip=""><dgm:adjLst/></dgm:shape><dgm:presOf/><dgm:constrLst><dgm:constr type="w" for="ch" ptType="node" refType="w" fact="0.3"/><dgm:constr type="h" for="ch" ptType="node" refType="h" fact="0.22"/><dgm:constr type="primFontSz" for="ch" ptType="node" op="equ" val="55"/></dgm:constrLst><dgm:ruleLst/><dgm:forEach name="nodesForEach" axis="des" ptType="node"><dgm:layoutNode name="node" styleLbl="node1"><dgm:alg type="tx"/><dgm:shape xmlns:r="\(MinimalTemplate.nsR)" type="roundRect" r:blip=""><dgm:adjLst/></dgm:shape><dgm:presOf axis="self" ptType="node"/><dgm:constrLst/><dgm:ruleLst/></dgm:layoutNode></dgm:forEach></dgm:layoutNode></dgm:layoutDef>
        """

    static let quickStyleXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <dgm:styleDef xmlns:dgm="\(nsDGM)" xmlns:a="\(MinimalTemplate.nsA)" uniqueId="urn:microsoft.com/office/officeart/2005/8/quickstyle/simple1"><dgm:title val=""/><dgm:desc val=""/><dgm:catLst><dgm:cat type="simple" pri="10100"/></dgm:catLst><dgm:scene3d><a:camera prst="orthographicFront"/><a:lightRig rig="threePt" dir="t"/></dgm:scene3d><dgm:styleLbl name="node0"><dgm:scene3d><a:camera prst="orthographicFront"/><a:lightRig rig="threePt" dir="t"/></dgm:scene3d><dgm:sp3d/><dgm:txPr/><dgm:style><a:lnRef idx="2"><a:scrgbClr r="0" g="0" b="0"/></a:lnRef><a:fillRef idx="1"><a:scrgbClr r="0" g="0" b="0"/></a:fillRef><a:effectRef idx="0"><a:scrgbClr r="0" g="0" b="0"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="lt1"/></a:fontRef></dgm:style></dgm:styleLbl><dgm:styleLbl name="node1"><dgm:scene3d><a:camera prst="orthographicFront"/><a:lightRig rig="threePt" dir="t"/></dgm:scene3d><dgm:sp3d/><dgm:txPr/><dgm:style><a:lnRef idx="2"><a:scrgbClr r="0" g="0" b="0"/></a:lnRef><a:fillRef idx="1"><a:scrgbClr r="0" g="0" b="0"/></a:fillRef><a:effectRef idx="0"><a:scrgbClr r="0" g="0" b="0"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="lt1"/></a:fontRef></dgm:style></dgm:styleLbl><dgm:styleLbl name="sibTrans2D1"><dgm:scene3d><a:camera prst="orthographicFront"/><a:lightRig rig="threePt" dir="t"/></dgm:scene3d><dgm:sp3d/><dgm:txPr/><dgm:style><a:lnRef idx="0"><a:scrgbClr r="0" g="0" b="0"/></a:lnRef><a:fillRef idx="1"><a:scrgbClr r="0" g="0" b="0"/></a:fillRef><a:effectRef idx="0"><a:scrgbClr r="0" g="0" b="0"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="tx1"/></a:fontRef></dgm:style></dgm:styleLbl></dgm:styleDef>
        """

    /// Colors part. With `nodeColors`, node fills CYCLE through the given
    /// brand colors (and outlines match the fills, so no hairline borders);
    /// without, theme accent1 with a light outline — PowerPoint's default look.
    static func colorsXML(nodeColors: [Color]?) -> String {
        let fill: String
        let line: String
        let txFill: String
        if let nodeColors, !nodeColors.isEmpty {
            let swatches = nodeColors.map { "<a:srgbClr val=\"\($0.hex)\"/>" }.joined()
            fill = "<dgm:fillClrLst meth=\"cycle\">\(swatches)</dgm:fillClrLst>"
            line = "<dgm:linClrLst meth=\"cycle\">\(swatches)</dgm:linClrLst>"
            // Text color follows each node's fill — black on a light block, white on
            // a dark one — so a pale brand accent never leaves white-on-pale text.
            let textSwatches = nodeColors
                .map { "<a:srgbClr val=\"\(Color.bestTextColor(on: $0).hex)\"/>" }.joined()
            txFill = "<dgm:txFillClrLst meth=\"cycle\">\(textSwatches)</dgm:txFillClrLst>"
        } else {
            fill = "<dgm:fillClrLst meth=\"repeat\"><a:schemeClr val=\"accent1\"/></dgm:fillClrLst>"
            line = "<dgm:linClrLst meth=\"repeat\"><a:schemeClr val=\"lt1\"/></dgm:linClrLst>"
            txFill = "<dgm:txFillClrLst/>"
        }
        return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <dgm:colorsDef xmlns:dgm="\(nsDGM)" xmlns:a="\(MinimalTemplate.nsA)" uniqueId="urn:microsoft.com/office/officeart/2005/8/colors/accent1_2"><dgm:title val=""/><dgm:desc val=""/><dgm:catLst><dgm:cat type="accent1" pri="11200"/></dgm:catLst><dgm:styleLbl name="node0">\(fill)\(line)<dgm:effectClrLst/><dgm:txLinClrLst/>\(txFill)<dgm:txEffectClrLst/></dgm:styleLbl><dgm:styleLbl name="node1">\(fill)\(line)<dgm:effectClrLst/><dgm:txLinClrLst/>\(txFill)<dgm:txEffectClrLst/></dgm:styleLbl><dgm:styleLbl name="sibTrans2D1"><dgm:fillClrLst meth="repeat"><a:schemeClr val="accent1"><a:tint val="60000"/></a:schemeClr></dgm:fillClrLst><dgm:linClrLst meth="repeat"><a:schemeClr val="accent1"><a:tint val="60000"/></a:schemeClr></dgm:linClrLst><dgm:effectClrLst/><dgm:txLinClrLst/><dgm:txFillClrLst/><dgm:txEffectClrLst/></dgm:styleLbl></dgm:colorsDef>
            """
    }
}

extension ShapeCollection {
    /// Add a SmartArt diagram with one node per item.
    /// `colors` (optional) brand-colors the blocks, cycling through the list;
    /// omitted, blocks use the theme accent (PowerPoint's default look).
    /// When `includeDrawing` is `true`, a cached `dsp:drawing` part is also
    /// embedded so SVG previews and viewers without a SmartArt engine render
    /// the diagram immediately.
    @discardableResult
    public func addSmartArt(items: [String], frame: Rect, colors: [Color]? = nil,
                            layout: SmartArt.Layout = .blockList,
                            includeDrawing: Bool = false) throws -> Shape {
        precondition(!items.isEmpty, "SmartArt needs at least one item")
        guard let package else {
            throw RostrumError.packageInvalid("this shape collection has no package attached")
        }

        var n = 1
        while package.parts[PackURI("/ppt/diagrams/data\(n).xml")] != nil { n += 1 }
        func addDiagramPart(_ name: String, contentType: String, xml: String) -> Part {
            package.addPart(
                uri: PackURI("/ppt/diagrams/\(name)\(n).xml"),
                contentType: contentType, blob: Data(xml.utf8))
        }
        var drawingRelID: String?
        if includeDrawing {
            let drawingPart = addDiagramPart("drawing", contentType: SmartArt.drawingContentType,
                                             xml: SmartArt.cachedDrawingXML(items: items, frame: frame, colors: colors, layout: layout))
            drawingRelID = part.rels.add(type: SmartArt.drawingRelType, target: part.uri.relativeReference(to: drawingPart.uri))
        }
        let data = addDiagramPart("data", contentType: SmartArt.dataContentType,
                                  xml: SmartArt.dataModelXML(items: items, layout: layout, drawingRelID: drawingRelID))
        let layoutPart = addDiagramPart("layout", contentType: SmartArt.layoutContentType,
                                        xml: layout.layoutXML)
        let quickStyle = addDiagramPart("quickStyle", contentType: SmartArt.quickStyleContentType,
                                        xml: SmartArt.quickStyleXML)
        let colorsPart = addDiagramPart("colors", contentType: SmartArt.colorsContentType,
                                        xml: SmartArt.colorsXML(nodeColors: colors))

        // All four relationships hang off the SLIDE part.
        let dmId = part.rels.add(type: SmartArt.dataRelType, target: part.uri.relativeReference(to: data.uri))
        let loId = part.rels.add(type: SmartArt.layoutRelType, target: part.uri.relativeReference(to: layoutPart.uri))
        let qsId = part.rels.add(type: SmartArt.quickStyleRelType, target: part.uri.relativeReference(to: quickStyle.uri))
        let csId = part.rels.add(type: SmartArt.colorsRelType, target: part.uri.relativeReference(to: colorsPart.uri))

        return try appendDiagramGraphicFrame(frame: frame, dmId: dmId, loId: loId, qsId: qsId, csId: csId)
    }

    /// Add a hierarchical (organization chart / tree) SmartArt diagram from a
    /// forest of `SmartArt.Node` roots.
    @discardableResult
    public func addSmartArt(nodes: [SmartArt.Node], frame: Rect, colors: [Color]? = nil,
                            includeDrawing: Bool = true) throws -> Shape {
        precondition(!nodes.isEmpty, "SmartArt needs at least one root node")
        guard let package else {
            throw RostrumError.packageInvalid("this shape collection has no package attached")
        }

        var n = 1
        while package.parts[PackURI("/ppt/diagrams/data\(n).xml")] != nil { n += 1 }
        func addDiagramPart(_ name: String, contentType: String, xml: String) -> Part {
            package.addPart(
                uri: PackURI("/ppt/diagrams/\(name)\(n).xml"),
                contentType: contentType, blob: Data(xml.utf8))
        }
        var drawingRelID: String?
        if includeDrawing {
            let drawingPart = addDiagramPart("drawing", contentType: SmartArt.drawingContentType,
                                             xml: SmartArt.cachedHierarchyDrawingXML(nodes: nodes, frame: frame, colors: colors))
            drawingRelID = part.rels.add(type: SmartArt.drawingRelType, target: part.uri.relativeReference(to: drawingPart.uri))
        }
        let data = addDiagramPart("data", contentType: SmartArt.dataContentType,
                                  xml: SmartArt.hierarchyDataModelXML(nodes: nodes, drawingRelID: drawingRelID))
        let layoutPart = addDiagramPart("layout", contentType: SmartArt.layoutContentType,
                                        xml: SmartArt.hierarchyLayoutXML)
        let quickStyle = addDiagramPart("quickStyle", contentType: SmartArt.quickStyleContentType,
                                        xml: SmartArt.quickStyleXML)
        let colorsPart = addDiagramPart("colors", contentType: SmartArt.colorsContentType,
                                        xml: SmartArt.colorsXML(nodeColors: colors))

        let dmId = part.rels.add(type: SmartArt.dataRelType, target: part.uri.relativeReference(to: data.uri))
        let loId = part.rels.add(type: SmartArt.layoutRelType, target: part.uri.relativeReference(to: layoutPart.uri))
        let qsId = part.rels.add(type: SmartArt.quickStyleRelType, target: part.uri.relativeReference(to: quickStyle.uri))
        let csId = part.rels.add(type: SmartArt.colorsRelType, target: part.uri.relativeReference(to: colorsPart.uri))

        return try appendDiagramGraphicFrame(frame: frame, dmId: dmId, loId: loId, qsId: qsId, csId: csId)
    }

    private func appendDiagramGraphicFrame(frame: Rect, dmId: String, loId: String, qsId: String, csId: String) throws -> Shape {
        let id = try Slide.nextShapeID(of: part)
        let graphicFrame = XML.Element("p:graphicFrame")
        let nvPr = XML.Element("p:nvGraphicFramePr")
        nvPr.appendElement(XML.Element("p:cNvPr", attributes: [
            ("id", String(id)), ("name", "SmartArt \(id)"),
        ]))
        let cNv = XML.Element("p:cNvGraphicFramePr")
        cNv.appendElement(XML.Element("a:graphicFrameLocks", attributes: [("noGrp", "1")]))
        nvPr.appendElement(cNv)
        nvPr.appendElement(XML.Element("p:nvPr"))
        graphicFrame.appendElement(nvPr)

        let xfrm = XML.Element("p:xfrm")
        xfrm.appendElement(XML.Element("a:off", attributes: [
            ("x", String(frame.x.rawValue)), ("y", String(frame.y.rawValue)),
        ]))
        xfrm.appendElement(XML.Element("a:ext", attributes: [
            ("cx", String(frame.width.rawValue)), ("cy", String(frame.height.rawValue)),
        ]))
        graphicFrame.appendElement(xfrm)

        let graphic = XML.Element("a:graphic")
        let graphicData = XML.Element("a:graphicData", attributes: [("uri", SmartArt.nsDGM)])
        graphicData.appendElement(XML.Element("dgm:relIds", attributes: [
            ("xmlns:dgm", SmartArt.nsDGM), ("xmlns:r", MinimalTemplate.nsR),
            ("r:dm", dmId), ("r:lo", loId), ("r:qs", qsId), ("r:cs", csId),
        ]))
        graphic.appendElement(graphicData)
        graphicFrame.appendElement(graphic)

        try Slide.spTree(of: part).appendElement(graphicFrame)
        part.markDirty()
        return DiagramFrame(element: graphicFrame, part: part, package: package)
    }
}

extension Slide {
    /// Text extraction from every SmartArt diagram on this slide (one array
    /// of item strings per diagram, in document order) — including diagrams
    /// authored by PowerPoint. python-pptx returns nothing for these.
    public var smartArtTexts: [[String]] {
        guard let spTree = try? spTree() else { return [] }
        var result: [[String]] = []
        for frame in spTree.children(named: "p:graphicFrame") {
            guard let graphicData = frame.firstChild(named: "a:graphic")?
                .firstChild(named: "a:graphicData"),
                  graphicData[attribute: "uri"] == SmartArt.nsDGM,
                  let relIds = graphicData.firstChild(named: "dgm:relIds"),
                  let dmId = relIds[attribute: "r:dm"],
                  let rel = part.rels.relationship(withId: dmId),
                  let dataPart = try? package.part(
                    at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI)),
                  let model = try? dataPart.dom() else { continue }
            let texts = (model.firstChild(named: "dgm:ptLst")?.children(named: "dgm:pt") ?? [])
                .filter { $0[attribute: "type"] == nil }  // plain nodes only
                .compactMap { pt -> String? in
                    let text = pt.firstChild(named: "dgm:t")?.textContent ?? ""
                    return text.isEmpty ? nil : text
                }
            result.append(texts)
        }
        return result
    }

    /// Hierarchical tree extraction from every SmartArt diagram on this slide,
    /// reconstructed from `dgm:ptLst` and `dgm:cxnLst` parent-child connections.
    public var smartArtTrees: [[SmartArt.Node]] {
        guard let spTree = try? spTree() else { return [] }
        var result: [[SmartArt.Node]] = []
        for frame in spTree.children(named: "p:graphicFrame") {
            guard let graphicData = frame.firstChild(named: "a:graphic")?
                .firstChild(named: "a:graphicData"),
                  graphicData[attribute: "uri"] == SmartArt.nsDGM,
                  let relIds = graphicData.firstChild(named: "dgm:relIds"),
                  let dmId = relIds[attribute: "r:dm"],
                  let rel = part.rels.relationship(withId: dmId),
                  let dataPart = try? package.part(
                    at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI)),
                  let model = try? dataPart.dom() else { continue }
            let pts = model.firstChild(named: "dgm:ptLst")?.children(named: "dgm:pt") ?? []
            var textByID: [String: String] = [:]
            var docID: String?
            for pt in pts {
                guard let id = pt[attribute: "modelId"] else { continue }
                if pt[attribute: "type"] == "doc" { docID = id }
                else if pt[attribute: "type"] == nil {
                    textByID[id] = pt.firstChild(named: "dgm:t")?.textContent ?? ""
                }
            }
            var childrenByParent: [String: [(ord: Int, dest: String)]] = [:]
            for cxn in model.firstChild(named: "dgm:cxnLst")?.children(named: "dgm:cxn") ?? [] {
                let type = cxn[attribute: "type"] ?? "parOf"
                guard type == "parOf",
                      let src = cxn[attribute: "srcId"],
                      let dest = cxn[attribute: "destId"],
                      textByID[dest] != nil else { continue }
                let ord = cxn[attribute: "srcOrd"].flatMap(Int.init) ?? 0
                childrenByParent[src, default: []].append((ord, dest))
            }
            var visited: Set<String> = []
            func buildNodes(from parentID: String, depth: Int = 0) -> [SmartArt.Node] {
                guard depth < 64, let entries = childrenByParent[parentID] else { return [] }
                return entries.sorted { $0.ord < $1.ord }.compactMap { entry in
                    guard visited.insert(entry.dest).inserted,
                          let text = textByID[entry.dest], !text.isEmpty else { return nil }
                    return SmartArt.Node(text, children: buildNodes(from: entry.dest, depth: depth + 1))
                }
            }
            if let docID, let roots = childrenByParent[docID], !roots.isEmpty {
                result.append(buildNodes(from: docID))
            } else {
                let flat = pts.filter { $0[attribute: "type"] == nil }.compactMap { pt -> SmartArt.Node? in
                    let t = pt.firstChild(named: "dgm:t")?.textContent ?? ""
                    return t.isEmpty ? nil : SmartArt.Node(t)
                }
                result.append(flat)
            }
        }
        return result
    }
}
