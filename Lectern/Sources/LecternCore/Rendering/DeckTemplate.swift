import Foundation
import Rostrum

/// A validated, immutable snapshot of a PowerPoint template. The selected file
/// can move, change or lose its security scope after this value is created.
/// Template bytes stay in the local renderer and never enter an AI request.
public struct DeckTemplate: Sendable {
    public let name: String
    public let slideCount: Int
    public let layoutCount: Int
    public let widthInches: Double
    public let heightInches: Double
    public let warnings: [String]

    private let data: Data
    static let maximumFileBytes = 100 * 1024 * 1024
    private static let limits = ZipReader.Limits(totalUncompressedBytes: 512 * 1024 * 1024)

    /// The caller owns security-scoped access for the duration of this read.
    public static func load(contentsOf url: URL) throws -> DeckTemplate {
        guard url.isFileURL else { throw DeckTemplateError.invalid("Choose a local PowerPoint file.") }
        let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard attributes.isRegularFile == true else {
            throw DeckTemplateError.invalid("Choose a PowerPoint file, rather than a folder.")
        }
        if let size = attributes.fileSize, size > maximumFileBytes { throw DeckTemplateError.tooLarge }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let bytes = try handle.read(upToCount: maximumFileBytes + 1) ?? Data()
        return try DeckTemplate(data: bytes, name: url.lastPathComponent)
    }

    public init(data: Data, name: String) throws {
        do { self = try Self(validating: data, name: name) }
        catch is CancellationError { throw CancellationError() }
        catch let error as DeckTemplateError { throw error }
        catch { throw DeckTemplateError.invalid("Couldn’t read this PowerPoint file: \(String(describing: error))") }
    }

    private init(validating data: Data, name: String) throws {
        guard data.count <= Self.maximumFileBytes else { throw DeckTemplateError.tooLarge }
        try Task.checkCancellation()
        let deck = try Presentation(data: data, limits: Self.limits)
        guard deck.documentKind != .slideShow else {
            throw DeckTemplateError.invalid("Choose a .potx template or a .pptx presentation.")
        }
        let main = try deck.package.mainDocumentPart()
        guard try main.dom().name == "p:presentation" else {
            throw DeckTemplateError.invalid("The file has no readable PowerPoint presentation.")
        }
        // Parse source XML before provider work begins. Presentation.validate is
        // a required-attribute lint and intentionally skips malformed XML.
        for part in deck.package.parts.values where part.uri.ext == "xml" {
            try Task.checkCancellation()
            _ = try part.dom()
        }
        guard !deck.layouts.isEmpty, let master = deck.slideMasters.first, master.theme != nil else {
            throw DeckTemplateError.invalid("The template needs a readable slide master, layout and theme.")
        }
        let size = deck.slideSize
        if let element = try main.dom().firstChild(named: "p:sldSz") {
            guard element[attribute: "cx"].flatMap(Int.init) != nil,
                  element[attribute: "cy"].flatMap(Int.init) != nil else {
                throw DeckTemplateError.invalid("The template has invalid slide dimensions.")
            }
        }
        // Builders use twelve tracks, each separated by the deck-style gutter.
        // A positive canvas alone is insufficient: the grid preconditions would
        // otherwise terminate the app, or negative tracks would corrupt shapes.
        let style = deck.style
        let gridOverhead = 2 * style.margin.rawValue + 11 * style.gutter.rawValue
        guard size.width.rawValue > gridOverhead, size.height.rawValue > gridOverhead else {
            let minimum = Double(gridOverhead) / 914_400
            throw DeckTemplateError.invalid("Template slides must be larger than \(minimum.formatted()) inches in both dimensions for Lectern's generated layouts.")
        }
        guard size.width.rawValue <= EMU.inches(56).rawValue, size.height.rawValue <= EMU.inches(56).rawValue else {
            throw DeckTemplateError.invalid("Lectern supports template slides up to 56 inches in each dimension.")
        }
        let issues = try deck.validate()
        guard issues.isEmpty else {
            throw DeckTemplateError.invalid("The template has PowerPoint structure errors: "
                + issues.prefix(3).map(\.description).joined(separator: "; "))
        }
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "PowerPoint template" : name
        self.slideCount = deck.slides.count
        self.layoutCount = deck.allLayouts.count
        self.widthInches = Double(size.width.rawValue) / 914_400
        self.heightInches = Double(size.height.rawValue) / 914_400
        var warnings = deck.readWarnings.map { "Template: " + $0 }
        warnings.append("Template colors, fonts, slide size and master artwork are retained. Lectern arranges new content on its own grid; template placeholder positions and inherited backgrounds may differ.")
        if deck.slideMasters.count > 1 {
            warnings.append("The template has \(deck.slideMasters.count) slide masters. Generated slides use the first master's theme and layouts; the other masters are retained.")
        }
        self.warnings = warnings
        self.data = data
        // Exercise the same cleanup and layout allocation used for generation,
        // now, so malformed annotations/sections fail before any paid request.
        try Self.prepare(deck)
        _ = try deck.slides.add()
    }

    func makePresentation() throws -> Presentation {
        let deck = try Presentation(data: data, limits: Self.limits)
        try Self.prepare(deck)
        _ = deck.registerEmbeddedFonts()
        return deck
    }

    private static func prepare(_ deck: Presentation) throws {
        let slideParts = try (0..<deck.slides.count).map { try deck.slides[$0].part.uri }
        let sourceClosure = try reachable(from: Set(slideParts), in: deck.package)
        while deck.sections.count > 0 {
            try Task.checkCancellation()
            try deck.sections.remove(at: deck.sections.count - 1)
        }
        while deck.slides.count > 0 {
            try Task.checkCancellation()
            try deck.slides.remove(at: deck.slides.count - 1)
        }
        let main = try deck.package.mainDocumentPart()
        let dom = try main.dom()
        let shows = dom.children(named: "p:custShowLst")
        dom.children.removeAll { if case .element(let child) = $0 { return child.name == "p:custShowLst" }; return false }
        if !shows.isEmpty { main.markDirty() }
        // Presentation properties can select a custom show or a source slide
        // range. Both selections would refer to content replaced above.
        for part in deck.package.parts.values where part.contentType == ContentType.presProps {
            if let show = try part.dom().firstChild(named: "p:showPr") {
                let selections = show.childElements.filter { ["p:custShow", "p:sldRg"].contains($0.name) }
                if !selections.isEmpty {
                    show.children.removeAll { if case .element(let child) = $0 { return ["p:custShow", "p:sldRg"].contains(child.name) }; return false }
                    if show.firstChild(named: "p:sldAll") == nil {
                        let index = show.children.firstIndex { if case .element(let child) = $0 { return ["p:penClr", "p:extLst"].contains(child.name) }; return false } ?? show.children.count
                        show.children.insert(.element(XML.Element("p:sldAll")), at: index)
                    }
                    part.markDirty()
                }
            }
        }
        // Remove example-only payloads as well as their slides. A chart's
        // workbook or an attachment can contain the old presentation's data.
        // Protect package roots and every part outside the source-slide graph,
        // including orphan/unknown roots that may legitimately share an asset.
        let packageRoots = Set(deck.package.rels.items.filter { !$0.isExternal }.map {
            PackURI.resolve(target: $0.target, relativeTo: "/")
        })
        let retainedRoots = Set(deck.package.parts.keys).subtracting(sourceClosure).union(packageRoots)
        let retained = try reachable(from: retainedRoots, in: deck.package)
        for uri in sourceClosure.subtracting(retained) where deck.package.parts[uri] != nil {
            deck.package.removePart(at: uri)
        }
        deck.documentKind = .presentation
    }

    private static func reachable(from roots: Set<PackURI>, in package: OPCPackage) throws -> Set<PackURI> {
        var pending = Array(roots)
        var visited: Set<PackURI> = []
        while let uri = pending.popLast() {
            try Task.checkCancellation()
            guard visited.insert(uri).inserted, let part = package.parts[uri] else { continue }
            pending.append(contentsOf: part.rels.items.filter { !$0.isExternal }.map {
                PackURI.resolve(target: $0.target, relativeTo: part.uri.baseURI)
            })
        }
        return visited
    }
}

public enum DeckTemplateError: LocalizedError {
    case tooLarge
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .tooLarge: "Choose a template smaller than 100 MB."
        case .invalid(let message): message
        }
    }
}
