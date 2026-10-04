import Foundation
import Rostrum

/// Owned preservation fixtures. These deliberately use the public XML/package
/// escape hatch for document features that have no typed authoring setter.
enum DrawingLabFixtures {
    // 4x4 JPEG encoded from LibraryLabSupport.pixels with macOS sips; encoded
    // bytes are bundled here so runtime needs no image codec, files or process.
    static let jpeg = Data(base64Encoded: "/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAABKADAAQAAAABAAAABAAAAAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgABAAEAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A+tf2Hfhx4M8cfsueCvFPijTvtup3v9pedN50se7y9RuY1+WN1UYVQOAOmTzX1j/woz4Wf9AT/wAmbn/45Xg3/BPH/kzzwB/3Ff8A06XdfadfyX475JgsNxxnuHw9CMKcMXiIxjGKUYxVaaSSSskloktEjznwLkmYP6/j8DSq1qvvznOnCU5zl70pSlJNylJtuUm22223c//Z")!
    static let styleID = "{ACB19F7A-7609-44B5-879D-1ABCD0000001}"
    static let opaque = Data("<lab:payload xmlns:lab=\"urn:lectern:lab\">owned-style-extension</lab:payload>".utf8)

    static func nodes(_ root: XML.Element, _ name: String) -> [XML.Element] {
        (root.name == name ? [root] : []) + root.childElements.flatMap { nodes($0, name) }
    }

    static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw RostrumError.packageInvalid(message) }
        return value
    }

    static func shapeXML(_ name: String, slide: Slide) throws -> XML.Element {
        try require(nodes(slide.part.dom(), "p:pic").first {
            $0.firstChild(named: "p:nvPicPr")?.firstChild(named: "p:cNvPr")?[attribute: "name"] == name
        }, "Missing owned picture fixture: \(name)")
    }

    static func addPictureFixtures(to deck: Presentation) throws {
        let slide = try deck.slides.add()
        try LibraryLabSupport.text("Owned JPEG and retained Office geometry", on: slide)
        let jpg = try slide.shapes.addPicture(jpeg, frame: LibraryLabSupport.frame(0.5, 1, 3, 2))
        jpg.name = "JPEG specimen"
        let retained = try slide.shapes.addPicture(LibraryLabSupport.pixels, frame: LibraryLabSupport.frame(4.5, 1, 3, 2))
        retained.name = "Retained ellipse and flips"
        let xml = try shapeXML(retained.name, slide: slide)
        let props = try require(xml.firstChild(named: "p:spPr"), "Fixture needs picture properties")
        props.firstChild(named: "a:prstGeom")?[attribute: "prst"] = "ellipse"
        let transform = try require(props.firstChild(named: "a:xfrm"), "Fixture needs transform")
        transform[attribute: "flipH"] = "1"
        transform[attribute: "flipV"] = "1"
        transform[attribute: "rot"] = "1800000"
        let alternate = try slide.shapes.addPicture(LibraryLabSupport.pixels, frame: LibraryLabSupport.frame(8.5, 1, 3, 2))
        alternate.name = "Office SVG alternate"
        let svg = Data("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"4\" height=\"4\"><rect width=\"4\" height=\"4\" fill=\"#276D89\"/></svg>".utf8)
        let svgPart = deck.package.addPart(uri: PackURI("/ppt/media/owned-alternate.svg"), contentType: "image/svg+xml", blob: svg)
        let rId = slide.part.rels.add(type: RelType.image, target: slide.part.uri.relativeReference(to: svgPart.uri))
        let blip = try require(shapeXML(alternate.name, slide: slide).firstChild(named: "p:blipFill")?.firstChild(named: "a:blip"), "Fixture needs blip")
        let extensionNode = XML.Element("a:ext", attributes: [("uri", "{96DAC541-7B7A-43D3-8B79-37D633B846F1}")])
        extensionNode.appendElement(XML.Element("asvg:svgBlip", attributes: [("xmlns:asvg", "http://schemas.microsoft.com/office/drawing/2016/SVG/main"), ("r:embed", rId)]))
        blip.appendElement(XML.Element("a:extLst", children: [.element(extensionNode)]))
        slide.part.markDirty()
    }

    static func style(_ color: Color) throws -> XML.Element {
        try XML.parse(Data("<a:tblStyle xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" styleId=\"\(styleID)\" styleName=\"Owned custom style\"><a:wholeTbl><a:tcStyle><a:fill><a:solidFill><a:srgbClr val=\"\(color.hex)\"/></a:solidFill></a:fill></a:tcStyle></a:wholeTbl></a:tblStyle>".utf8))
    }

    static func stylePart(_ deck: Presentation) throws -> Part {
        let presentation = try deck.package.mainDocumentPart()
        let relation = try require(presentation.rels.first(ofType: RelType.tableStyles), "Missing table styles relationship")
        return try deck.package.part(at: PackURI.resolve(target: relation.target, relativeTo: presentation.uri.baseURI))
    }

    static func addCustomStyles(to deck: Presentation, accent: Color) throws -> (checks: [LibraryLabCheck], verify: (Presentation) throws -> [LibraryLabCheck]) {
        let slide = try deck.slides.add()
        try LibraryLabSupport.text("Custom style: original, transferred and reused", on: slide)
        let original = try slide.shapes.addTable(rows: 2, columns: 2, frame: LibraryLabSupport.frame(0.5, 1.3, 3.8, 2))
        let imported = try slide.shapes.addTable(rows: 2, columns: 2, frame: LibraryLabSupport.frame(4.6, 1.3, 3.8, 2))
        let reused = try slide.shapes.addTable(rows: 2, columns: 2, frame: LibraryLabSupport.frame(8.7, 1.3, 3.8, 2))
        original.setContents([["Original", "Solid"], ["Retained", "Style"]])
        imported.setContents([["Imported", "Image"], ["Opaque", "Dependency"]])
        reused.setContents([["Reused", "Same GUID"], ["No duplicate", "Resources"]])
        try original.setStyleDefinition(style(accent))
        let source = try LibraryLabSupport.deck(title: "Owned custom style source")
        let sourceTable = try source.slides[0].shapes.addTable(rows: 2, columns: 2, frame: LibraryLabSupport.frame())
        try sourceTable.setStyleDefinition(style(.white))
        let owner = try stylePart(source)
        let definition = try require(nodes(owner.dom(), "a:tblStyle").first { $0[attribute: "styleId"] == styleID }, "Missing owned style")
        definition[attribute: "xmlns:r"] = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        definition[attribute: "xmlns:lab"] = "urn:lectern:lab"
        let media = source.package.addPart(uri: PackURI("/ppt/media/owned-style.png"), contentType: ContentType.png, blob: LibraryLabSupport.pixels)
        let imageID = owner.rels.add(type: RelType.image, target: owner.uri.relativeReference(to: media.uri))
        let fill = try require(nodes(definition, "a:fill").first, "Missing style fill")
        fill.children = [.element(XML.Element("a:blipFill", children: [
            .element(XML.Element("a:blip", attributes: [("r:embed", imageID)])),
            .element(XML.Element("a:stretch", children: [.element(XML.Element("a:fillRect"))]))]))]
        let payload = source.package.addPart(uri: PackURI("/ppt/custom/owned-style.xml"), contentType: "application/xml", blob: opaque)
        let payloadID = owner.rels.add(type: "urn:lectern:lab:style-payload", target: owner.uri.relativeReference(to: payload.uri))
        let ext = XML.Element("a:ext", attributes: [("uri", "urn:lectern:lab:preservation")], children: [.element(XML.Element("lab:payload", attributes: [("r:id", payloadID), ("value", "preserve")]))])
        definition.appendElement(XML.Element("a:extLst", children: [.element(ext)]))
        owner.markDirty()
        let sourceBefore = try source.serializedData()
        let beforeRefusal = try deck.serializedData()
        var refused = false
        do { try imported.setStyleDefinition(definition) } catch { refused = true }
        var checks = [LibraryLabCheck("Relationship-bearing standalone style refused atomically", try refused && deck.serializedData() == beforeRefusal, "Transfer requires the style's source part and package; standalone installation leaves destination bytes unchanged.")]
        let missing = try XML.parse(Data(definition.serialized().utf8))
        nodes(missing, "a:blip").first?[attribute: "r:embed"] = "rIdMissingDependency"
        let beforeMissing = try deck.serializedData()
        var missingRefused = false
        do { try imported.setStyleDefinition(missing, from: owner, in: source.package) } catch { missingRefused = true }
        checks.append(.init("Missing custom style dependency refused atomically", try missingRefused && deck.serializedData() == beforeMissing, "A missing image relationship cannot leave a partial style or copied dependency in the destination."))
        try imported.setStyleDefinition(definition, from: owner, in: source.package)
        let importedID = imported.styleID
        let partsBeforeReuse = deck.package.parts.count
        try reused.setStyleDefinition(definition, from: owner, in: source.package)
        checks.append(.init("Equivalent custom style reused", reused.styleID == importedID && deck.package.parts.count == partsBeforeReuse, "Repeated transfer reuses the remapped style and its dependency graph."))
        checks.append(.init("Custom style source unchanged", try source.serializedData() == sourceBefore, "Transferring definitions never modifies source XML or image/extension bytes."))
        return (checks, { reopened in
            let tables = try reopened.slides[1].shapes.all.compactMap { ($0 as? TableFrame)?.table }
            let targetOwner = try stylePart(reopened)
            let definitions = nodes(try targetOwner.dom(), "a:tblStyle")
            let incoming = definitions.first { $0[attribute: "styleId"] == importedID }
            let originalDefinition = definitions.first { $0[attribute: "styleId"] == styleID }
            let imageID = incoming.flatMap { nodes($0, "a:blip").first?[attribute: "r:embed"] }
            let opaqueID = incoming.flatMap { nodes($0, "lab:payload").first?[attribute: "r:id"] }
            func dependency(_ id: String?) throws -> Data? {
                guard let id, let relation = targetOwner.rels.relationship(withId: id) else { return nil }
                return try reopened.package.part(at: PackURI.resolve(target: relation.target, relativeTo: targetOwner.uri.baseURI)).blob
            }
            return [
                .init("Conflicting custom style identities preserved", tables.count == 3 && tables[0].styleID == styleID && tables[1].styleID == importedID && tables[2].styleID == importedID && importedID != styleID && importedID != nil, "Existing style keeps its GUID; both imports use one distinct remapped GUID."),
                .init("Original custom fill preserved", originalDefinition.map { nodes($0, "a:srgbClr").contains { $0[attribute: "val"] == accent.hex } } == true, "The destination solid fill was not overwritten by the incoming image style."),
                .init("Custom style relationships and opaque extension preserved", try dependency(imageID) == LibraryLabSupport.pixels && dependency(opaqueID) == opaque && incoming.map { nodes($0, "lab:payload").first?[attribute: "value"] == "preserve" } == true, "Transferred style resolves exact image and opaque payload bytes, with extension attributes intact.")
            ]
        })
    }
}

extension DrawingLabFixtures {
    /// Match a specific picture's image resource and destination before testing
    /// its crop. Other images' clip paths cannot accidentally satisfy the check.
    static func mappingMatches(svg: String, bytes: Data, mime: String, frame: Rect,
                               crop: PictureCrop, geometry: String, rotation: Int, flipped: Bool) throws -> Bool {
        let root = try XML.parse(Data(svg.utf8))
        let href = "data:\(mime);base64,\(bytes.base64EncodedString())"
        guard let pattern = nodes(root, "pattern").first(where: {
            $0[attribute: "x"] == String(frame.x.rawValue) && $0[attribute: "y"] == String(frame.y.rawValue)
                && nodes($0, "image").contains { $0[attribute: "href"] == href }
        }), let patternID = pattern[attribute: "id"], let image = nodes(pattern, "image").first,
              let group = nodes(pattern, "g").first, let clipURL = group[attribute: "clip-path"],
              let clip = nodes(root, "clipPath").first(where: { "url(#\($0[attribute: "id"] ?? ""))" == clipURL })?.firstChild(named: "rect") else { return false }
        let w = Double(frame.width.rawValue), h = Double(frame.height.rawValue)
        let iw = w / (1 - crop.left - crop.right), ih = h / (1 - crop.top - crop.bottom)
        func equal(_ node: XML.Element, _ key: String, _ value: Double) -> Bool {
            guard let actual = node[attribute: key].flatMap(Double.init) else { return false }
            return abs(actual - value) < 0.000001
        }
        let scale = flipped ? "scale(-1 -1)" : "scale(1 1)"
        let transformed = nodes(root, "g").contains { g in
            guard let transform = g[attribute: "transform"], transform.contains("rotate(\(rotation).0)"), transform.contains(scale) else { return false }
            return g.childElements.contains { $0.name == geometry && $0[attribute: "fill"] == "url(#\(patternID))" }
        }
        return equal(image, "width", iw) && equal(image, "height", ih)
            && equal(image, "x", -crop.left * iw) && equal(image, "y", -crop.top * ih)
            && equal(clip, "x", 0) && equal(clip, "y", 0) && equal(clip, "width", w) && equal(clip, "height", h)
            && transformed
    }
}
