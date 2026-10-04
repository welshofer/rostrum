import Foundation

/// Stable categories for fidelity gaps observed in the rendered content.
public enum FidelityIssueCode: String, Sendable, Codable {
    case missingFont, missingGlyph, unsupportedShaping, textTruncated, unresolvedInheritance, viewerFontDependency, fontEmbeddingRestricted, unsupportedFontEmbedding
    case unsupportedGeometry, ignoredTransform, omittedEffect, unsupportedFill
    case gradientApproximation, chartApproximation, graphicPlaceholder
    case unresolvedTableStyle, unavailableImage, unsupportedImage
    case unsupportedTextProperty, omittedShape, unsupportedColor, unsupportedBorder
}

public enum FidelityImpact: String, Sendable, Codable { case approximation, omission, missingResource }

/// A deterministic source location. slideIndex is zero-based; inherited
/// furniture names its owning layout/master part while retaining the slide index.
public struct FidelityLocation: Hashable, Sendable, Codable {
    public let slideIndex: Int
    public let partURI: String
    public let shapeID: String?
    public let path: String
    public init(slideIndex: Int, partURI: String, shapeID: String? = nil, path: String) {
        self.slideIndex = slideIndex; self.partURI = partURI; self.shapeID = shapeID; self.path = path
    }
}

public struct FidelityIssue: Hashable, Sendable, Codable {
    public let code: FidelityIssueCode
    public let impact: FidelityImpact
    public let location: FidelityLocation
    public let message: String
    public init(code: FidelityIssueCode, impact: FidelityImpact, location: FidelityLocation, message: String) {
        self.code = code; self.impact = impact; self.location = location; self.message = message
    }
}

/// Strict mode refuses known gaps; passing it is not an Office pixel-match or
/// universal OOXML conformance guarantee. The same source remains available to
/// permissive rendering and lossless save after a rejection.
public struct StrictRenderingError: Error, Sendable, CustomStringConvertible {
    public let problems: SlideRenderProblems
    public var description: String { "Strict rendering refused \(problems.fidelityIssues.count) known fidelity issue(s)." }
}

/// One render owns one collector. It never retains or mutates source XML.
final class RenderDiagnosticCollector {
    /// Namespace declarations locate an effect element; they do not add an
    /// effect to an otherwise empty override or theme component.
    static func hasEffectContent(_ element: XML.Element) -> Bool {
        !element.childElements.isEmpty || element.attributes.contains {
            $0.name != "xmlns" && !$0.name.hasPrefix("xmlns:")
        }
    }
    let images = RenderImageResources()
    let textAttributes = RenderTextAttributes()
    var themeEffectOverrideProblem: String?
    var location = FidelityLocation(slideIndex: 0, partURI: "", path: "/")
    private(set) var issues: [FidelityIssue] = []
    private var seen: Set<FidelityIssue> = []
    private struct RecentIssue: Equatable {
        let code: FidelityIssueCode
        let impact: FidelityImpact
        let message: String
    }
    // Cell text often reports the same missing face thousands of times at one
    // table location. A small lookaside avoids hashing the full location each
    // time; the complete set remains authoritative across location changes.
    private var recentLocation: FidelityLocation?
    private var recentIssues: [RecentIssue] = []
    private static let supportedColorTransforms: Set<String> = [
        "a:tint", "a:shade", "a:lumMod", "a:lumOff", "a:satMod", "a:alpha", "a:alphaMod", "a:alphaOff",
    ]
    private struct EmbeddedFace {
        let data: Data
        let encoded: String
        let bold: Bool
        let italic: Bool
        let family: String
        let format: String
    }
    private var embeddedFaces: [EmbeddedFace] = []
    private var resolvedFaces: [FontFaceKey: String] = [:]
    private var unavailableFaces: [FontFaceKey: (FidelityIssueCode, FidelityImpact, String)] = [:]
    func reset() { images.reset(); textAttributes.reset(); themeEffectOverrideProblem = nil; recentLocation = nil; recentIssues = []; issues = []; seen = []; embeddedFaces = []; resolvedFaces = [:]; unavailableFaces = [:] }

    /// Names point at renderer-owned CSS faces, so aliases use one resource and
    /// the SVG does not accidentally pick a similarly named platform font.
    func embeddedFamily(for face: FontFaceKey, fonts: FontLibrary) -> String? {
        let resourceFace = fonts.previewFace(for: face) ?? face
        if resourceFace.family != face.family {
            record(.missingFont, .missingResource, "Requested font \(face.family) is unavailable; preview uses registered \(resourceFace.family). The document font is unchanged.")
        } else if resourceFace != face {
            record(.viewerFontDependency, .approximation, "Requested style of \(face.family) is unavailable; using its registered regular face with viewer style synthesis.")
        }
        if let existing = resolvedFaces[face] { return existing }
        if let missing = unavailableFaces[face] { record(missing.0, missing.1, missing.2); return nil }
        func unavailable(_ code: FidelityIssueCode, _ impact: FidelityImpact, _ reason: String) -> String? {
            unavailableFaces[face] = (code, impact, reason)
            record(code, impact, reason)
            return nil
        }
        guard let data = fonts.data(for: resourceFace) else {
            return unavailable(.viewerFontDependency, .approximation, "No embeddable registered font resource for \(face.family).")
        }
        if let restriction = EOTLite.fsType(of: data), restriction & 0x0202 != 0 {
            return unavailable(.fontEmbeddingRestricted, .missingResource, "OS/2 embedding restrictions prevent embedding \(face.family) in SVG.")
        }
        let signature = Array(data.prefix(4))
        guard signature != [0x74, 0x74, 0x63, 0x66] else {
            return unavailable(.unsupportedFontEmbedding, .approximation, "Collection-face extraction is required before embedding \(face.family) in SVG.")
        }
        guard fonts.metrics(for: resourceFace)?.hasOutlines == true else {
            return unavailable(.unsupportedFontEmbedding, .missingResource, "Font \(face.family) has metrics but no supported outline tables for SVG.")
        }
        if let shared = embeddedFaces.first(where: { $0.data == data && $0.bold == resourceFace.bold && $0.italic == resourceFace.italic }) {
            resolvedFaces[face] = shared.family
            return shared.family
        }
        let family = "RostrumEmbeddedFace\(embeddedFaces.count + 1)"
        let format = signature == [0x4F, 0x54, 0x54, 0x4F] ? "opentype" : "truetype"
        embeddedFaces.append(EmbeddedFace(data: data, encoded: fonts.encodedSource(for: resourceFace) ?? data.base64EncodedString(), bold: resourceFace.bold, italic: resourceFace.italic, family: family, format: format))
        resolvedFaces[face] = family
        return family
    }

    var fontDefinitions: String {
        guard !embeddedFaces.isEmpty else { return "" }
        let rules = embeddedFaces.map { face in
            "@font-face{font-family:'\(face.family)';font-style:\(face.italic ? "italic" : "normal");font-weight:\(face.bold ? 700 : 400);src:url(data:font/\(face.format == "opentype" ? "otf" : "ttf");base64,\(face.encoded)) format('\(face.format)');}"
        }.joined()
        return "<style type=\"text/css\">" + rules + "</style>"
    }
    func record(_ code: FidelityIssueCode, _ impact: FidelityImpact, _ message: String,
                at location: FidelityLocation? = nil) {
        let resolvedLocation = location ?? self.location
        let recent = RecentIssue(code: code, impact: impact, message: message)
        if recentLocation == resolvedLocation {
            if recentIssues.contains(recent) { return }
        } else {
            recentLocation = resolvedLocation
            recentIssues.removeAll(keepingCapacity: true)
        }
        if recentIssues.count == 4 { recentIssues.removeFirst() }
        recentIssues.append(recent)
        let issue = FidelityIssue(code: code, impact: impact, location: resolvedLocation, message: message)
        if seen.insert(issue).inserted { issues.append(issue) }
    }

    func text(_ layout: RichTextLayout) {
        for diagnostic in layout.diagnostics {
            switch diagnostic {
            case .missingGlyph(let scalar):
                record(.missingGlyph, .missingResource, "No glyph for U+\(String(scalar, radix: 16, uppercase: true)) in the explicit face.")
            case .unsupportedLayoutFeature(let reason) where reason.hasPrefix("Unregistered font face:"):
                record(.missingFont, .missingResource, reason)
            case .unsupportedLayoutFeature(let reason) where reason.hasPrefix("Paragraph alignment") || reason.hasPrefix("Justification")
                || reason.hasPrefix("Tab alignment") || reason.hasPrefix("Unknown tab alignment")
                || reason.hasPrefix("Native explicit line spacing") || reason.hasPrefix("Native table")
                || reason.hasPrefix("Native glyph paint"):
                record(.unsupportedTextProperty, .approximation, reason)
            default:
                record(.unsupportedShaping, .approximation, String(describing: diagnostic))
            }
        }
        if layout.truncated { record(.textTruncated, .omission, "Text exceeds the preview's 64-line bound.") }
    }

    /// Inspect only the shapes selected for rendering, not hidden placeholders.
    /// Traversal is iterative and document ordered; paths include same-name indices.
    func inspect(_ shape: XML.Element, owner: Part, slideIndex: Int, path: String, package: OPCPackage,
                 tableStyleReference: Bool = false, approximatedTableEffect: XML.Element? = nil) {
        guard !ShapeCollection.isHidden(shape) else { return }
        let id = shape.childElements.first?.firstChild(named: "p:cNvPr")?[attribute: "id"]
        location = FidelityLocation(slideIndex: slideIndex, partURI: owner.uri.description, shapeID: id, path: path)
        if !["p:sp", "p:pic", "p:cxnSp", "p:grpSp", "p:graphicFrame", "p:bg", "p:bgPr", "a:solidFill", "a:gradFill", "a:blipFill", "a:pattFill", "a:tblStyle", "a:tableStyle", "a:ln", "a:effectStyle"].contains(shape.name) {
            if ShapeCollection.isShape(shape) { record(.omittedShape, .omission, "The SVG renderer does not draw \(shape.name).") }
            return
        }
        if shape.name == "p:grpSp", ShapeTransform.childSpace(ShapeTransform.element(of: shape)) == nil {
            record(.omittedShape, .omission, "Malformed p:grpSp has no usable child coordinate space.")
        }
        if shape.name == "p:cxnSp", shape.firstChild(named: "p:spPr") == nil {
            record(.omittedShape, .omission, "Malformed p:cxnSp has no shape properties.")
        }
        // Most visited nodes have no issue. Carry path components through the
        // same document-order traversal instead of allocating a full XPath for
        // every descendant (notably every run/color/border in large tables).
        var stack: [(element: XML.Element, occurrence: Int, depth: Int, parent: String)] = [(shape, 0, 0, "")]
        var components: [(name: String, occurrence: Int)] = []
        let tableStyle = tableStyleReference || shape.name == "a:tblStyle" || shape.name == "a:tableStyle"
        while let (element, occurrence, depth, parent) = stack.popLast() {
            if ShapeCollection.isHidden(element) { continue }
            if components.count > depth { components.removeLast(components.count - depth) }
            if occurrence > 0 { components.append((element.name, occurrence)) }
            func issue(_ code: FidelityIssueCode, _ impact: FidelityImpact, _ text: String) {
                let elementPath = path + components.map { "/\($0.name)[\($0.occurrence)]" }.joined()
                let here = FidelityLocation(slideIndex: slideIndex, partURI: owner.uri.description, shapeID: id, path: elementPath)
                record(code, impact, text, at: here)
            }
            switch element.name {
            case "a:prstGeom":
                let preset = element[attribute: "prst"] ?? "rect"
                if !SVGPresetGeometry.supported.contains(preset) && !["line", "straightConnector1"].contains(preset) {
                    issue(.unsupportedGeometry, .approximation, "Preset \(preset) is approximated by a rectangle.")
                } else if element.firstChild(named: "a:avLst")?.children(named: "a:gd").contains(where: { guide in
                    let formula = (guide[attribute: "fmla"] ?? "").split(whereSeparator: \.isWhitespace)
                    return formula.count != 2 || formula.first != "val" || Double(formula.last ?? "")?.isFinite != true
                }) == true {
                    issue(.unsupportedGeometry, .approximation, "Unsupported geometry guide formulas use default adjustments.")
                }
            case "a:custGeom": break // Diagnosed using the resolved frame by the path renderer.
            case "a:xfrm", "p:xfrm":
                if ShapeTransform.rect(element) == nil, ["rot", "flipH", "flipV"].contains(where: { element[attribute: $0].map { $0 != "0" && $0 != "false" } ?? false }) {
                    issue(.ignoredTransform, .approximation, "A transform without valid bounds cannot be applied.")
                }
            case "a:effectLst", "a:effectDag", "a:scene3d", "a:sp3d":
                if element === approximatedTableEffect {
                    issue(.omittedEffect, .approximation, "Table background outer shadow is approximated with an SVG Gaussian blur.")
                } else if Self.hasEffectContent(element) {
                    issue(.omittedEffect, .omission, "\(element.name) effects are not rendered.")
                }
            case "a:gradFill":
                if (!tableStyle && parent != "a:tcPr") || element.firstChild(named: "a:path") != nil {
                    issue(.gradientApproximation, .approximation, "Gradient geometry is approximated by the preview.")
                }
            case "a:pattFill":
                issue(.unsupportedFill, .omission, "Pattern fill is not rendered in this shape path.")
            case "a:hslClr":
                issue(.unsupportedColor, .omission, "HSL color sources are not resolved by the preview.")
            case "a:srgbClr", "a:schemeClr", "a:sysClr", "a:scrgbClr", "a:prstClr":
                if element.childElements.contains(where: { !Self.supportedColorTransforms.contains($0.name) }) {
                    issue(.unsupportedColor, .approximation, "A color transform is not applied by the preview.")
                }
                if element.name == "a:prstClr", !["black", "white", "red", "green", "blue", "yellow", "gray", "cyan", "magenta", "transparent"].contains(element[attribute: "val"] ?? "") {
                    issue(.unsupportedColor, .omission, "This preset color is not resolved by the preview.")
                }
            case "a:blipFill", "p:blipFill":
                if element[attribute: "rotWithShape"] == "0" || element[attribute: "rotWithShape"] == "false" {
                    issue(.ignoredTransform, .approximation, "Image paint rotation independent of its shape is not applied.")
                }
            case "a:srcRect", "a:fillRect":
                if !PictureCrop.read(element).valid || ["l", "t", "r", "b"].contains(where: {
                    guard let raw = element[attribute: $0] else { return false }
                    guard let value = Int64(raw) else { return true }
                    return value < Int64(Int32.min) || value > Int64(Int32.max)
                }) {
                    issue(.unsupportedImage, .omission, "The image rectangle is empty, inverted or outside the supported percentage encoding.")
                }
            case "a:blip":
                guard let rID = SVGEmbeddedImage.reference(in: element),
                      let resource = images.resolve(rID, owner: owner, package: package) else {
                    issue(.unavailableImage, .missingResource, "Image bytes could not be resolved from the owning part."); break
                }
                if !resource.supported {
                    issue(.unsupportedImage, .omission, "The embedded bytes are not a recognized raster image or supported self-contained SVG.")
                }
                if element.childElements.contains(where: { $0.name != "a:extLst" }) { issue(.omittedEffect, .omission, "Image effects are not applied.") }
            case "a:graphicData":
                let uri = element[attribute: "uri"] ?? ""
                if uri.hasSuffix("/chart") { issue(.chartApproximation, .approximation, "Chart preview approximates axes, labels and formatting; series/point bounds may omit data.") }
                else if !uri.hasSuffix("/table") && uri != GraphicDataURI.diagram { issue(.graphicPlaceholder, .omission, "Graphic content is represented by a labeled placeholder.") }
            case "a:tbl":
                if !Self.hasTableStyle(element, package: package) { issue(.unresolvedTableStyle, .approximation, "The table style has no recognized native or embedded definition; preview uses fallback/direct formatting.") }
            case "a:tcPr":
                if let direction = element[attribute: "vert"], !["horz", "vert", "vert270"].contains(direction) {
                    issue(.unsupportedTextProperty, .approximation, "This vertical cell text direction is not implemented.")
                }
            case "a:bodyPr":
                if let vertical = element[attribute: "vert"], vertical != "horz" { issue(.unsupportedTextProperty, .approximation, "Vertical text layout is not implemented.") }
                if let columns = element[attribute: "numCol"], columns != "1" { issue(.unsupportedTextProperty, .approximation, "Text columns are not implemented.") }
                if let warp = element.firstChild(named: "a:prstTxWarp"), warp[attribute: "prst"] != "textNoShape" { issue(.unsupportedTextProperty, .approximation, "Text warp is not implemented.") }
            case "a:pPr":
                // Resolved paragraph alignment is diagnosed by RichTextLayout,
                // including inherited modes and unsupported justification cases.
                if element[attribute: "rtl"] == "1" { issue(.unsupportedTextProperty, .approximation, "Paragraph RTL layout is not verified.") }
            case "a:rPr", "a:defRPr", "a:endParaRPr":
                if element[attribute: "cap"] == "small" { issue(.unsupportedTextProperty, .approximation, "Small capitals are not rendered.") }
                if ["kumimoji", "normalizeH"].contains(where: { element[attribute: $0].map { $0 != "0" && $0 != "none" && $0 != "noStrike" } ?? false }) {
                    issue(.unsupportedTextProperty, .approximation, "Character transforms are not rendered.")
                }
            case "a:tab":
                if let alignment = element[attribute: "algn"], !["l", "ctr", "r", "dec"].contains(alignment) { issue(.unsupportedTextProperty, .approximation, "Unknown tab alignment is approximated as a left tab.") }
            case "a:buBlip": issue(.unsupportedTextProperty, .omission, "Picture bullets are not rendered.")
            case "a:ln":
                if shape.name == "p:cxnSp" { break }
                if (element[attribute: "cmpd"].map({ $0 != "sng" }) == true
                    && !(tableStyle && TableDoubleBorder.supports(element)))
                    || (!tableStyle && element.firstChild(named: "a:prstDash").map { $0[attribute: "val"] != "solid" } == true)
                    || ["a:custDash", "a:headEnd", "a:tailEnd"].contains(where: { element.firstChild(named: $0) != nil }) {
                    issue(.unsupportedBorder, .approximation, "Compound, dashed or arrowed shape strokes are approximated.")
                }
            case "a:lnL", "a:lnR", "a:lnT", "a:lnB", "a:lnTlToBr", "a:lnBlToTr":
                if (element[attribute: "cmpd"].map({ $0 != "sng" }) == true
                    && !TableDoubleBorder.supports(element))
                    || ["a:custDash", "a:headEnd", "a:tailEnd"].contains(where: { element.firstChild(named: $0) != nil }) {
                    issue(.unsupportedBorder, .approximation, "Compound, custom-dashed or arrowed table borders are approximated.")
                }
            default: break
            }
            // Runs contain many leaves and single-child wrappers. Inspect
            // those directly instead of materializing a child-element array.
            let nodes = element.children
            if nodes.isEmpty { continue }
            if nodes.count == 1 {
                if case .element(let child) = nodes[0],
                   element.name != "a:tblPr" || child.name != "a:tableStyle" {
                    stack.append((child, 1, components.count, element.name))
                }
                continue
            }
            let children = element.childElements
            if !children.isEmpty {
                var counts: [String: Int] = [:]
                for child in children { counts[child.name, default: 0] += 1 }
                for child in children.reversed() {
                    let occurrence = counts[child.name]!
                    counts[child.name] = occurrence - 1
                    // Table rendering inspects only enabled style regions.
                    if element.name == "a:tblPr", child.name == "a:tableStyle" { continue }
                    stack.append((child, occurrence, components.count, element.name))
                }
            }
        }
    }

    private static func hasTableStyle(_ table: XML.Element, package: OPCPackage) -> Bool {
        let properties = table.firstChild(named: "a:tblPr")
        if properties?.firstChild(named: "a:tableStyle") != nil { return true }
        var id = properties?.firstChild(named: "a:tableStyleId")?.textContent
        if let presentation = try? package.mainDocumentPart(),
           let styles = try? presentation.related(by: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/tableStyles", in: package),
           let root = try? styles.dom() {
            id = id ?? root[attribute: "def"]
            if TableStyleXML.definitions(in: root).contains(where: { $0[attribute: "styleId"]?.lowercased() == id?.lowercased() }) { return true }
        }
        return id == nil || id.flatMap(BuiltInTableStyle.init(id:)) != nil
    }
}
