import Foundation

/// A PresentationML document — Rostrum's counterpart to python-pptx's
/// `Presentation`.
public final class Presentation {
    /// The underlying OPC package. Public on purpose: power users get the
    /// escape hatch python-pptx only half-exposes.
    public let package: OPCPackage

    let presentationPart: Part

    /// The slide collection: iterate, index, `add()`, `remove(at:)`,
    /// `move(from:to:)`, `duplicate(at:)`.
    public var slides: Slides {
        Slides(package: package, presentationPart: presentationPart)
    }

    /// A new presentation from Rostrum's built-in minimal template
    /// (one blank 16:9 slide).
    public init() throws {
        package = try MinimalTemplate.makePackage()
        presentationPart = try package.mainDocumentPart()
    }

    /// Open a presentation from .pptx bytes.
    public init(data: Data) throws {
        package = try OPCPackage.read(data: data)
        let main = try package.mainDocumentPart()
        guard main.contentType == ContentType.presentationMain else {
            throw RostrumError.notAPresentation(
                "main document part is \(main.contentType)")
        }
        presentationPart = main
    }

    public convenience init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    // MARK: - Properties

    /// Number of slides, from `p:sldIdLst`.
    public var slideCount: Int {
        slides.count
    }

    /// Slide dimensions from `p:sldSz`.
    public var slideSize: (width: EMU, height: EMU) {
        get {
            guard let dom = try? presentationPart.dom(),
                  let sldSz = dom.firstChild(named: "p:sldSz"),
                  let cx = sldSz[attribute: "cx"].flatMap({ Int($0) }),
                  let cy = sldSz[attribute: "cy"].flatMap({ Int($0) }) else {
                return (MinimalTemplate.defaultSlideWidth, MinimalTemplate.defaultSlideHeight)
            }
            return (EMU(cx), EMU(cy))
        }
        set {
            guard let dom = try? presentationPart.dom() else { return }
            let sldSz: XML.Element
            if let existing = dom.firstChild(named: "p:sldSz") {
                sldSz = existing
            } else {
                // p:sldSz is optional in a valid file; create it at its
                // schema-mandated position (immediately before p:notesSz).
                sldSz = XML.Element("p:sldSz")
                if let notesIndex = dom.children.firstIndex(where: {
                    if case .element(let e) = $0 { return e.name == "p:notesSz" }
                    return false
                }) {
                    dom.children.insert(.element(sldSz), at: notesIndex)
                } else {
                    dom.appendElement(sldSz)
                }
            }
            sldSz[attribute: "cx"] = String(newValue.width.rawValue)
            sldSz[attribute: "cy"] = String(newValue.height.rawValue)
            presentationPart.markDirty()
        }
    }

    // MARK: - Saving

    /// The complete .pptx file bytes. Untouched parts re-emit their original
    /// bytes; only mutated parts are re-serialized.
    public func serializedData() throws -> Data {
        try package.serialize()
    }

    public func save(to url: URL) throws {
        try serializedData().write(to: url)
    }
}
