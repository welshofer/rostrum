import Foundation

extension OPCPackage {
    /// Get-or-add an image part under `/ppt/media/`, deduplicating by content:
    /// identical bytes are stored once no matter how many slides use them
    /// (python-pptx's SHA-1 registry, done with direct comparison).
    func imagePart(for data: Data, info: ImageInfo) -> Part {
        for (uri, part) in parts
        where uri.value.hasPrefix("/ppt/media/") && part.blob == data {
            return part
        }
        var n = 1
        while parts[PackURI("/ppt/media/image\(n).\(info.format.fileExtension)")] != nil { n += 1 }
        let uri = PackURI("/ppt/media/image\(n).\(info.format.fileExtension)")
        contentTypes.setDefault(extension: info.format.fileExtension, contentType: info.format.contentType)
        // Image content types ride on extension Defaults, not per-part
        // Overrides — undo addPart's override to keep [Content_Types].xml lean.
        let part = addPart(uri: uri, contentType: info.format.contentType, blob: data)
        contentTypes.removeOverride(partName: uri)
        return part
    }
}

extension ShapeCollection {
    /// Add a picture at an explicit frame.
    @discardableResult
    public func addPicture(_ data: Data, frame: Rect) throws -> Shape {
        guard let info = ImageSniffer.sniff(data) else {
            throw RostrumError.packageInvalid("unrecognized image format (PNG, JPEG and GIF are supported)")
        }
        return try insertPicture(data, info: info, frame: frame)
    }

    /// Add a picture at its natural size (pixels ÷ dpi), top-left at (x, y).
    @discardableResult
    public func addPicture(_ data: Data, x: EMU, y: EMU) throws -> Shape {
        guard let info = ImageSniffer.sniff(data) else {
            throw RostrumError.packageInvalid("unrecognized image format (PNG, JPEG and GIF are supported)")
        }
        let natural = info.nativeSize
        return try insertPicture(
            data, info: info,
            frame: Rect(x: x, y: y, width: natural.width, height: natural.height))
    }

    private func insertPicture(_ data: Data, info: ImageInfo, frame: Rect) throws -> Shape {
        guard let package else {
            throw RostrumError.packageInvalid("this shape collection has no package attached")
        }
        let image = package.imagePart(for: data, info: info)
        let rId = part.rels.add(
            type: RelType.image,
            target: part.uri.relativeReference(to: image.uri))

        let id = try Slide.nextShapeID(of: part)
        let pic = XML.Element("p:pic")

        let nvPicPr = XML.Element("p:nvPicPr")
        nvPicPr.appendElement(XML.Element("p:cNvPr", attributes: [
            ("id", String(id)), ("name", "Picture \(id)"),
        ]))
        let cNvPicPr = XML.Element("p:cNvPicPr")
        cNvPicPr.appendElement(XML.Element("a:picLocks", attributes: [("noChangeAspect", "1")]))
        nvPicPr.appendElement(cNvPicPr)
        nvPicPr.appendElement(XML.Element("p:nvPr"))
        pic.appendElement(nvPicPr)

        let blipFill = XML.Element("p:blipFill")
        blipFill.appendElement(XML.Element("a:blip", attributes: [("r:embed", rId)]))
        let stretch = XML.Element("a:stretch")
        stretch.appendElement(XML.Element("a:fillRect"))
        blipFill.appendElement(stretch)
        pic.appendElement(blipFill)

        let spPr = XML.Element("p:spPr")
        let xfrm = XML.Element("a:xfrm")
        xfrm.appendElement(XML.Element("a:off", attributes: [
            ("x", String(frame.x.rawValue)), ("y", String(frame.y.rawValue)),
        ]))
        xfrm.appendElement(XML.Element("a:ext", attributes: [
            ("cx", String(frame.width.rawValue)), ("cy", String(frame.height.rawValue)),
        ]))
        spPr.appendElement(xfrm)
        let prstGeom = XML.Element("a:prstGeom", attributes: [("prst", "rect")])
        prstGeom.appendElement(XML.Element("a:avLst"))
        spPr.appendElement(prstGeom)
        pic.appendElement(spPr)

        try Slide.spTree(of: part).appendElement(pic)
        part.markDirty()
        return Shape(element: pic, part: part)
    }
}
