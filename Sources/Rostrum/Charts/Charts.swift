import Foundation

extension ContentType {
    public static let chart = "application/vnd.openxmlformats-officedocument.drawingml.chart+xml"
    public static let xlsx = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
}

extension RelType {
    public static let chart = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart"
    /// A fully-fledged OPC package embedded as a part (the chart workbook).
    public static let package = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/package"
}

extension ShapeCollection {
    /// Add a native chart. `colors` (optional) styles series — for pie, the
    /// slices — with explicit brand colors; otherwise theme accents apply.
    @discardableResult
    public func addChart(
        _ kind: ChartKind, data: ChartData, frame: Rect,
        colors: [Color]? = nil
    ) throws -> Shape {
        guard let package else {
            throw RostrumError.packageInvalid("this shape collection has no package attached")
        }

        // Package-wide numbering for chart and workbook parts.
        var n = 1
        while package.parts[PackURI("/ppt/charts/chart\(n).xml")] != nil { n += 1 }
        let chartURI = PackURI("/ppt/charts/chart\(n).xml")
        let workbookURI = PackURI("/ppt/embeddings/Microsoft_Excel_Sheet\(n).xlsx")

        let chartPart = package.addPart(
            uri: chartURI, contentType: ContentType.chart,
            blob: ChartXML.chartSpace(kind: kind, data: data, colors: colors))

        // The workbook rides on an xlsx extension Default, and its rId1 is
        // what c:externalData references (chart-part rel scope).
        package.contentTypes.setDefault(extension: "xlsx", contentType: ContentType.xlsx)
        package.addPart(uri: workbookURI, contentType: ContentType.xlsx,
                        blob: ChartWorkbook.make(data: data))
        package.contentTypes.removeOverride(partName: workbookURI)
        chartPart.rels.add(
            type: RelType.package,
            target: chartURI.relativeReference(to: workbookURI))

        // Slide-scope relationship for the graphicFrame's c:chart reference.
        let rId = part.rels.add(
            type: RelType.chart,
            target: part.uri.relativeReference(to: chartURI))

        let id = try Slide.nextShapeID(of: part)
        let graphicFrame = XML.Element("p:graphicFrame")
        let nvPr = XML.Element("p:nvGraphicFramePr")
        nvPr.appendElement(XML.Element("p:cNvPr", attributes: [
            ("id", String(id)), ("name", "Chart \(id)"),
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
        let graphicData = XML.Element("a:graphicData", attributes: [
            ("uri", ChartXML.nsC),
        ])
        graphicData.appendElement(XML.Element("c:chart", attributes: [
            ("xmlns:c", ChartXML.nsC), ("r:id", rId),
        ]))
        graphic.appendElement(graphicData)
        graphicFrame.appendElement(graphic)

        try Slide.spTree(of: part).appendElement(graphicFrame)
        part.markDirty()
        return Shape(element: graphicFrame, part: part)
    }
}
