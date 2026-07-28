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

/// How a picture maps its source pixels onto its frame.
public enum PictureFit: Sendable {
    /// Scale the whole image to the frame, distorting if the aspect differs
    /// (the default; matches a bare `a:stretch/a:fillRect`).
    case stretch
    /// Cover: scale to fill the frame with no distortion, cropping the
    /// overflowing edges into the fill via `a:srcRect`. The picture shape
    /// stays exactly on `frame` — nothing bleeds off-slide.
    case fill
}

extension ShapeCollection {
    /// Add a picture at an explicit frame. With `fit: .fill`, the image covers
    /// the frame with no distortion by cropping (source-rect), so the shape
    /// never extends past its frame.
    @discardableResult
    public func addPicture(_ data: Data, frame: Rect, fit: PictureFit = .stretch) throws -> Picture {
        guard let info = ImageSniffer.sniff(data) else {
            throw RostrumError.packageInvalid("unrecognized image format (PNG, JPEG and GIF are supported)")
        }
        return try insertPicture(data, info: info, frame: frame, crop: coverCrop(info: info, frame: frame, fit: fit))
    }

    /// The `a:srcRect` edge insets (fractions 0…1) that make `info` cover
    /// `frame` without distortion, or nil for `.stretch`.
    ///
    /// The insets themselves come from `SrcCrop.cover`, shared with the fill
    /// path — a picture and a background covering the same region must crop
    /// identically, and two copies of this arithmetic is how they came not to.
    private func coverCrop(info: ImageInfo, frame: Rect, fit: PictureFit) -> SrcCrop? {
        guard fit == .fill, info.pixelHeight > 0, let regionAspect = frame.aspect else { return nil }
        return SrcCrop.cover(imageAspect: Double(info.pixelWidth) / Double(info.pixelHeight),
                             regionAspect: regionAspect)
    }

    /// Add a picture at its natural size (pixels ÷ dpi), top-left at (x, y).
    @discardableResult
    public func addPicture(_ data: Data, x: EMU, y: EMU) throws -> Picture {
        guard let info = ImageSniffer.sniff(data) else {
            throw RostrumError.packageInvalid("unrecognized image format (PNG, JPEG and GIF are supported)")
        }
        let natural = info.nativeSize
        return try insertPicture(
            data, info: info,
            frame: Rect(x: x, y: y, width: natural.width, height: natural.height))
    }

    private func insertPicture(_ data: Data, info: ImageInfo, frame: Rect, crop: SrcCrop? = nil) throws -> Picture {
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
        // srcRect trims a fraction (in 1000ths of a percent) off each edge of
        // the source image before it is stretched to the frame.
        if let crop { blipFill.appendElement(crop.makeElement()) }
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
        return Picture(element: pic, part: part, package: package)
    }
}
