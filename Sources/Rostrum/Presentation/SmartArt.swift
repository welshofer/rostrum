import Foundation

/// SmartArt (DrawingML diagrams).
///
/// A diagram is a graphicFrame referencing a quadruplet of parts — data,
/// layout, quickStyle, colors — via `dgm:relIds`. Rostrum embeds its own
/// verified Basic Block List layout (a linear vertical list) and generates
/// the data model, including the presentation cache that LibreOffice needs
/// to render (PowerPoint runs the layout algorithm itself and ignores it).
/// The optional drawing-persist part is deliberately not written: PowerPoint
/// regenerates it on save.
public enum SmartArt {
    static let nsDGM = "http://schemas.openxmlformats.org/drawingml/2006/diagram"
    static let layoutURN = "urn:rostrum/basicBlockList"

    static let dataContentType = "application/vnd.openxmlformats-officedocument.drawingml.diagramData+xml"
    static let layoutContentType = "application/vnd.openxmlformats-officedocument.drawingml.diagramLayout+xml"
    /// Note the asymmetry: content type says diagramStyle, rel type says
    /// diagramQuickStyle. Swapping them is the classic hand-authoring bug.
    static let quickStyleContentType = "application/vnd.openxmlformats-officedocument.drawingml.diagramStyle+xml"
    static let colorsContentType = "application/vnd.openxmlformats-officedocument.drawingml.diagramColors+xml"

    static let dataRelType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramData"
    static let layoutRelType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramLayout"
    static let quickStyleRelType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramQuickStyle"
    static let colorsRelType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramColors"

    /// A SmartArt layout family. Each supplies its own `layoutDef` — the algorithm
    /// PowerPoint runs — and its gallery category; the data model, quick style, and
    /// colors are shared across all of them. Every layout is minimal, hand-authored,
    /// and verified to open without repair in PowerPoint + LibreOffice.
    public enum Layout: String, Sendable, CaseIterable {
        case blockList   // a vertical list of blocks (the original)
        case process     // a horizontal chevron sequence (left → right)

        /// Layout uniqueId (`loTypeId`), also the `presId` in the data model.
        public var urn: String {
            switch self {
            case .blockList: return SmartArt.layoutURN
            case .process:   return "urn:rostrum/basicProcess"
            }
        }
        /// Gallery category, and the document point's `loCatId`.
        var category: String {
            switch self {
            case .blockList: return "list"
            case .process:   return "process"
            }
        }
        var layoutXML: String {
            switch self {
            case .blockList: return SmartArt.blockListLayoutXML
            case .process:   return SmartArt.processLayoutXML
            }
        }
    }

    // MARK: - Data model generation

    /// The complete data1.xml for one level of `items` under the document
    /// root: item points, parTrans/sibTrans pairs, parent-of connections,
    /// and the presentation cache mirroring the layout instantiation.
    static func dataModelXML(items: [String], layout: Layout = .blockList) -> String {
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

        return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <dgm:dataModel xmlns:dgm="\(nsDGM)" xmlns:a="\(MinimalTemplate.nsA)"><dgm:ptLst>\(pts)</dgm:ptLst><dgm:cxnLst>\(cxns)</dgm:cxnLst><dgm:bg/><dgm:whole/></dgm:dataModel>
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
        if let nodeColors, !nodeColors.isEmpty {
            let swatches = nodeColors.map { "<a:srgbClr val=\"\($0.hex)\"/>" }.joined()
            fill = "<dgm:fillClrLst meth=\"cycle\">\(swatches)</dgm:fillClrLst>"
            line = "<dgm:linClrLst meth=\"cycle\">\(swatches)</dgm:linClrLst>"
        } else {
            fill = "<dgm:fillClrLst meth=\"repeat\"><a:schemeClr val=\"accent1\"/></dgm:fillClrLst>"
            line = "<dgm:linClrLst meth=\"repeat\"><a:schemeClr val=\"lt1\"/></dgm:linClrLst>"
        }
        return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <dgm:colorsDef xmlns:dgm="\(nsDGM)" xmlns:a="\(MinimalTemplate.nsA)" uniqueId="urn:microsoft.com/office/officeart/2005/8/colors/accent1_2"><dgm:title val=""/><dgm:desc val=""/><dgm:catLst><dgm:cat type="accent1" pri="11200"/></dgm:catLst><dgm:styleLbl name="node0">\(fill)\(line)<dgm:effectClrLst/><dgm:txLinClrLst/><dgm:txFillClrLst/><dgm:txEffectClrLst/></dgm:styleLbl><dgm:styleLbl name="node1">\(fill)\(line)<dgm:effectClrLst/><dgm:txLinClrLst/><dgm:txFillClrLst/><dgm:txEffectClrLst/></dgm:styleLbl><dgm:styleLbl name="sibTrans2D1"><dgm:fillClrLst meth="repeat"><a:schemeClr val="accent1"><a:tint val="60000"/></a:schemeClr></dgm:fillClrLst><dgm:linClrLst meth="repeat"><a:schemeClr val="accent1"><a:tint val="60000"/></a:schemeClr></dgm:linClrLst><dgm:effectClrLst/><dgm:txLinClrLst/><dgm:txFillClrLst/><dgm:txEffectClrLst/></dgm:styleLbl></dgm:colorsDef>
            """
    }
}

extension ShapeCollection {
    /// Add a SmartArt Basic Block List (vertical) with one block per item.
    /// `colors` (optional) brand-colors the blocks, cycling through the list;
    /// omitted, blocks use the theme accent (PowerPoint's default look).
    @discardableResult
    public func addSmartArt(items: [String], frame: Rect, colors: [Color]? = nil,
                            layout: SmartArt.Layout = .blockList) throws -> Shape {
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
        let data = addDiagramPart("data", contentType: SmartArt.dataContentType,
                                  xml: SmartArt.dataModelXML(items: items, layout: layout))
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
        return Shape(element: graphicFrame, part: part)
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
}
