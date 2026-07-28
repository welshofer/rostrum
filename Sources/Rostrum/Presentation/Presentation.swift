import Foundation

/// The three shapes a PresentationML document comes in.
///
/// They differ in exactly one byte range — the content type of the main part,
/// `/ppt/presentation.xml` — and in nothing else. PowerPoint reads that, not
/// the file extension, to decide whether double-clicking the file opens it or
/// spawns a new deck from it.
public enum DocumentKind: Hashable, Sendable {
    /// `.pptx` — an ordinary deck.
    case presentation
    /// `.potx` — a template. Opening one in PowerPoint creates a new untitled
    /// presentation from it rather than editing it in place.
    case template
    /// `.ppsx` — a slide show, which opens straight into presenting.
    case slideShow

    /// The content type this kind writes on `/ppt/presentation.xml`.
    public var mainContentType: String {
        switch self {
        case .presentation: ContentType.presentationMain
        case .template: ContentType.presentationTemplateMain
        case .slideShow: ContentType.slideShowMain
        }
    }

    /// The kind a main-part content type denotes, or nil if it denotes no
    /// PresentationML document at all — which is how `Presentation(data:)`
    /// tells a deck from a package that merely happens to be a zip.
    public init?(mainContentType: String) {
        switch mainContentType {
        case ContentType.presentationMain: self = .presentation
        case ContentType.presentationTemplateMain: self = .template
        case ContentType.slideShowMain: self = .slideShow
        default: return nil
        }
    }
}

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

    /// Open a presentation from `.pptx` bytes — or a `.potx` template or
    /// `.ppsx` show, which open as themselves. Their masters, layouts, theme
    /// and fonts are usable exactly as a presentation's are; what differs is
    /// only what the document *is*, and saving preserves it.
    ///
    /// To build an ordinary deck from a template, say so — one line, and the
    /// conversion is yours rather than the library's:
    ///
    ///     let deck = try Presentation(data: templateBytes)
    ///     deck.documentKind = .presentation
    ///
    /// Earlier versions performed that conversion silently on open, which meant
    /// a template could not survive a round trip: opening and saving it with no
    /// edits returned a presentation. See `documentKind`.
    ///
    /// - Parameter limits: ceilings applied to the archive before anything is
    ///   decompressed — see `ZipReader.Limits`. Defaults to `.unlimited`, so
    ///   genuinely large decks keep opening; pass a budget when the bytes came
    ///   from somewhere you do not control.
    public init(data: Data, limits: ZipReader.Limits = .unlimited) throws {
        package = try OPCPackage.read(data: data, limits: limits)
        let main = try package.mainDocumentPart()
        guard DocumentKind(mainContentType: main.contentType) != nil else {
            throw RostrumError.notAPresentation(
                "main document part is \(main.contentType)")
        }
        presentationPart = main
    }

    public convenience init(contentsOf url: URL, limits: ZipReader.Limits = .unlimited) throws {
        try self.init(data: Data(contentsOf: url), limits: limits)
    }

    // MARK: - Document kind

    /// What this document *is* — presentation, template or slide show.
    ///
    /// PowerPoint decides this from the main part's content type, not from the
    /// file extension, and it is the whole difference between the three
    /// formats: a `.potx` is a `.pptx` whose `/ppt/presentation.xml` is typed
    /// as a template. Everything else — masters, layouts, slides, theme — is
    /// identical, which is why a template is fully usable through this API
    /// without converting it.
    ///
    /// Reading is free. Writing retypes the main part and its content-type
    /// override, and writing the value it already has does nothing at all —
    /// which is what lets an untouched package re-emit its original
    /// `[Content_Types].xml` bytes rather than a rebuilt, reordered one.
    ///
    ///     let deck = try Presentation(data: templateBytes)   // .template
    ///     deck.documentKind = .presentation                  // now a .pptx
    ///
    /// Save the result under the matching extension. A file named `.pptx` whose
    /// main part still says `template` opens in PowerPoint as a template —
    /// it spawns a new untitled deck instead of the file you double-clicked.
    public var documentKind: DocumentKind {
        get { DocumentKind(mainContentType: presentationPart.contentType) ?? .presentation }
        set {
            let contentType = newValue.mainContentType
            // No-op when unchanged: touching the map at all would cost the
            // package its pristine content-types bytes.
            guard presentationPart.contentType != contentType else { return }
            presentationPart.contentType = contentType
            package.contentTypes.setOverride(
                partName: presentationPart.uri, contentType: contentType)
        }
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
