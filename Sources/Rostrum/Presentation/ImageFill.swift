import Foundation

// The package-aware fill resolver lives in the Presentation layer (not Drawing)
// so `Fill`/`makeElement()` stay free of any OPC/Part dependency — dependencies
// still point strictly downward. Only image fills need package context; every
// other fill defers to the pure `makeElement()`.

extension SrcCrop {
    /// The crop as an `a:srcRect` element (insets in 1000ths of a percent).
    ///
    /// Lives here rather than beside the type: `Drawing/Geometry.swift` is pure
    /// EMU math that emits no OOXML, which is what makes it round-trip-risk-free.
    func makeElement() -> XML.Element {
        func pct(_ v: Double) -> String { String(Int((v * 100_000).rounded())) }
        return XML.Element("a:srcRect", attributes: [
            ("l", pct(left)), ("t", pct(top)), ("r", pct(right)), ("b", pct(bottom)),
        ])
    }
}

extension Fill {
    /// Realize this fill as a DrawingML fill element, embedding a deduplicated
    /// image part + relationship on `part` when the fill is `.image`. Pure fills
    /// ignore `package`; an image fill requires it (throws otherwise).
    ///
    /// - Parameter regionAspect: width ÷ height of the region being filled —
    ///   the slide canvas for a background, the shape frame for a shape fill.
    ///   Only `.cover` reads it, and only to crop; passing `nil` makes `.cover`
    ///   behave as `.stretch` (see `ImageFillMode.cover`).
    func fillElement(embeddingInto part: Part, package: OPCPackage?,
                     regionAspect: Double? = nil) throws -> XML.Element {
        guard case let .image(data, fit) = self else {
            return makeElement()
        }
        guard let package else {
            throw RostrumError.packageInvalid("an image fill needs a package to embed the image")
        }
        guard let info = ImageSniffer.sniff(data) else {
            throw RostrumError.packageInvalid(
                "unrecognized image format (PNG, JPEG and GIF are supported)")
        }
        let image = package.imagePart(for: data, info: info)
        let rId = part.rels.add(
            type: RelType.image, target: part.uri.relativeReference(to: image.uri))
        return Fill.blipFill(rId: rId, fit: fit, crop: Fill.crop(fit, info, regionAspect))
    }

    /// The source crop `fit` calls for on an `info`-shaped image covering a
    /// region of `regionAspect`. Only `.cover` crops, and only when it knows
    /// what it is covering.
    private static func crop(_ fit: ImageFillMode, _ info: ImageInfo,
                             _ regionAspect: Double?) -> SrcCrop? {
        guard case .cover = fit, let regionAspect, info.pixelHeight > 0 else { return nil }
        return SrcCrop.cover(imageAspect: Double(info.pixelWidth) / Double(info.pixelHeight),
                             regionAspect: regionAspect)
    }

    /// A DrawingML `a:blipFill` (EG_FillProperties) — the FILL wrapper. This is
    /// deliberately distinct from a picture's `p:blipFill`: emitting `p:blipFill`
    /// inside `spPr`/`bgPr` triggers a PowerPoint repair.
    static func blipFill(rId: String, fit: ImageFillMode, crop: SrcCrop? = nil) -> XML.Element {
        let blipFill = XML.Element("a:blipFill", attributes: [("rotWithShape", "1")])
        blipFill.appendElement(XML.Element("a:blip", attributes: [("r:embed", rId)]))
        // Schema order (CT_BlipFillProperties): a:blip, a:srcRect, then the
        // fill-mode choice. srcRect after a:stretch is a PowerPoint repair.
        if let crop { blipFill.appendElement(crop.makeElement()) }
        switch fit {
        case .stretch, .cover:
            let stretch = XML.Element("a:stretch")
            stretch.appendElement(XML.Element("a:fillRect"))
            blipFill.appendElement(stretch)
        case .tile(let scale):
            let s = String(Int((scale * 100_000).rounded()))
            blipFill.appendElement(XML.Element("a:tile", attributes: [
                ("sx", s), ("sy", s), ("algn", "tl"),
            ]))
        }
        return blipFill
    }
}
