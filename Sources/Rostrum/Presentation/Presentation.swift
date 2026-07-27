import Foundation

/// A PresentationML document — Rostrum's counterpart to python-pptx's
/// `Presentation`.
public final class Presentation {
    /// The underlying OPC package. Public on purpose: power users get the
    /// escape hatch python-pptx only half-exposes.
    public let package: OPCPackage

    let presentationPart: Part

    /// The `Design` most recently applied via `applyDesign` this session, if any.
    /// In-memory ONLY — never serialized — so `style` can read the type/spacing/
    /// radius tokens that `applyDesign` doesn't persist into the theme DOM.
    public internal(set) var appliedDesign: Design?

    /// Fonts registered for text measurement — the slide builders and the SVG
    /// renderer consult these to measure instead of estimate. Explicit
    /// registration only (see `FontLibrary`); an empty library reproduces the
    /// pre-metrics behavior byte-for-byte.
    public let fonts = FontLibrary()

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

    /// Open a presentation from `.pptx` bytes — or a `.potx` template / `.ppsx`
    /// show, which are normalized in place to an ordinary presentation so you
    /// can add slides and save the result as a `.pptx` PowerPoint opens
    /// directly. The template's masters, layouts, theme, and fonts are carried
    /// through untouched.
    ///
    /// - Parameter limits: ceilings applied to the archive before anything is
    ///   decompressed — see `ZipReader.Limits`. Defaults to `.unlimited`, so
    ///   genuinely large decks keep opening; pass a budget when the bytes came
    ///   from somewhere you do not control.
    public init(data: Data, limits: ZipReader.Limits = .unlimited) throws {
        package = try OPCPackage.read(data: data, limits: limits)
        let main = try package.mainDocumentPart()
        switch main.contentType {
        case ContentType.presentationMain:
            break
        case ContentType.presentationTemplateMain, ContentType.slideShowMain:
            // Retype the main part (both the part and the package's content-type
            // override) so serialization emits a plain presentation.
            main.contentType = ContentType.presentationMain
            package.contentTypes.setOverride(
                partName: main.uri, contentType: ContentType.presentationMain)
        default:
            throw RostrumError.notAPresentation(
                "main document part is \(main.contentType)")
        }
        presentationPart = main
    }

    public convenience init(contentsOf url: URL, limits: ZipReader.Limits = .unlimited) throws {
        try self.init(data: Data(contentsOf: url), limits: limits)
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
