import Foundation

// The package-aware fill resolver lives in the Presentation layer (not Drawing)
// so `Fill`/`makeElement()` stay free of any OPC/Part dependency — dependencies
// still point strictly downward. Only image fills need package context; every
// other fill defers to the pure `makeElement()`.

extension Fill {
    /// Realize this fill as a DrawingML fill element, embedding a deduplicated
    /// image part + relationship on `part` when the fill is `.image`. Pure fills
    /// ignore `package`; an image fill requires it (throws otherwise).
    func fillElement(embeddingInto part: Part, package: OPCPackage?) throws -> XML.Element {
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
        return Fill.blipFill(rId: rId, fit: fit)
    }

    /// A DrawingML `a:blipFill` (EG_FillProperties) — the FILL wrapper. This is
    /// deliberately distinct from a picture's `p:blipFill`: emitting `p:blipFill`
    /// inside `spPr`/`bgPr` triggers a PowerPoint repair.
    static func blipFill(rId: String, fit: ImageFillMode) -> XML.Element {
        let blipFill = XML.Element("a:blipFill", attributes: [("rotWithShape", "1")])
        blipFill.appendElement(XML.Element("a:blip", attributes: [("r:embed", rId)]))
        switch fit {
        case .stretch:
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
