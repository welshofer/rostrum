import Foundation

/// A PresentationML document — Rostrum's counterpart to python-pptx's
/// `Presentation`.
///
/// Phase-0 surface: create a new deck, open an existing one, inspect/set the
/// slide size, count slides, save. The slide/shape object model arrives next.
public final class Presentation {
    /// The underlying OPC package. Public on purpose: power users get the
    /// escape hatch python-pptx only half-exposes.
    public let package: OPCPackage

    let presentationPart: Part
    let presentationXML: XML.Element

    /// A new presentation from Rostrum's built-in minimal template
    /// (one blank 16:9 slide).
    public init() throws {
        package = try MinimalTemplate.makePackage()
        presentationPart = try package.mainDocumentPart()
        presentationXML = try presentationPart.xml()
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
        presentationXML = try main.xml()
    }

    public convenience init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    // MARK: - Properties

    /// Number of slides, from `p:sldIdLst`.
    public var slideCount: Int {
        presentationXML.firstChild(named: "p:sldIdLst")?.childElements.count ?? 0
    }

    /// Slide dimensions from `p:sldSz`. The setter is the first mutation
    /// Rostrum supports.
    public var slideSize: (width: EMU, height: EMU) {
        get {
            guard let sldSz = presentationXML.firstChild(named: "p:sldSz"),
                  let cx = sldSz[attribute: "cx"].flatMap({ Int($0) }),
                  let cy = sldSz[attribute: "cy"].flatMap({ Int($0) }) else {
                return (MinimalTemplate.defaultSlideWidth, MinimalTemplate.defaultSlideHeight)
            }
            return (EMU(cx), EMU(cy))
        }
        set {
            let sldSz: XML.Element
            if let existing = presentationXML.firstChild(named: "p:sldSz") {
                sldSz = existing
            } else {
                // p:sldSz is optional in a valid file; create it at its
                // schema-mandated position (immediately before p:notesSz).
                sldSz = XML.Element("p:sldSz")
                if let notesIndex = presentationXML.children.firstIndex(where: {
                    if case .element(let e) = $0 { return e.name == "p:notesSz" }
                    return false
                }) {
                    presentationXML.children.insert(.element(sldSz), at: notesIndex)
                } else {
                    presentationXML.appendElement(sldSz)
                }
            }
            sldSz[attribute: "cx"] = String(newValue.width.rawValue)
            sldSz[attribute: "cy"] = String(newValue.height.rawValue)
        }
    }

    // MARK: - Saving

    /// The complete .pptx file bytes.
    public func serializedData() throws -> Data {
        presentationPart.blob = XML.document(presentationXML)
        return try package.serialize()
    }

    public func save(to url: URL) throws {
        try serializedData().write(to: url)
    }
}
