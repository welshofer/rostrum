import Foundation

/// Validate and wrap every requested face before changing any package state.
/// Existing declarations stay in place so opaque metadata and references survive.
struct FontEmbeddingPlan {
    private let root: XML.Element
    private let list: XML.Element
    private let family: XML.Element
    private let listIsNew: Bool
    private let familyIsNew: Bool
    private let rootScope: [String: String]
    private let familyScope: [String: String]
    private var pending: [(tag: String, blob: Data)] = []

    init(typeface: String, faces: FontFaces, allowRestrictedLicense: Bool,
         presentation: Part, package: OPCPackage) throws {
        root = try presentation.dom()
        rootScope = EmbeddedFontXML.scope(root)
        guard EmbeddedFontXML.expanded(root.name, rootScope) == "{\(EmbeddedFontXML.presentation)}presentation" else {
            throw RostrumError.packageInvalid("font embedding requires a presentation root")
        }
        let lists = EmbeddedFontXML.children(root, "embeddedFontLst")
        guard lists.count <= 1 else { throw RostrumError.packageInvalid("ambiguous embedded font lists") }
        listIsNew = lists.isEmpty
        list = lists.first ?? Self.element("embeddedFontLst", in: rootScope)
        let listScope = EmbeddedFontXML.scope(list, rootScope)
        var matching: [XML.Element] = []
        for entry in EmbeddedFontXML.children(list, "embeddedFont", inheriting: rootScope) {
            let declarations = EmbeddedFontXML.children(entry, "font", inheriting: listScope)
            if declarations.contains(where: { $0[attribute: "typeface"]?.lowercased() == typeface.lowercased() }) {
                guard declarations.count == 1 else {
                    throw RostrumError.packageInvalid("ambiguous embedded typeface: \(typeface)")
                }
                matching.append(entry)
            }
        }
        guard matching.count <= 1 else {
            throw RostrumError.packageInvalid("ambiguous embedded family: \(typeface)")
        }
        familyIsNew = matching.isEmpty
        family = matching.first ?? Self.element("embeddedFont", in: listScope)
        familyScope = EmbeddedFontXML.scope(family, listScope)
        if familyIsNew {
            let declaration = Self.element("font", in: familyScope)
            declaration[attribute: "typeface"] = typeface
            family.appendElement(declaration)
        }

        let variants: [(tag: String, style: String, weight: UInt32, italic: Bool, data: Data?)] = [
            ("regular", "Regular", 400, false, faces.regular),
            ("bold", "Bold", 700, false, faces.bold),
            ("italic", "Italic", 400, true, faces.italic),
            ("boldItalic", "Bold Italic", 700, true, faces.boldItalic),
        ]
        for variant in variants {
            guard let data = variant.data else { continue }
            if !allowRestrictedLicense, let fsType = EOTLite.fsType(of: data), fsType & EOTLite.fsTypeRestricted != 0 {
                throw RostrumError.fontEmbeddingRestricted(typeface)
            }
            let existing = EmbeddedFontXML.children(family, variant.tag, inheriting: listScope)
            guard existing.count <= 1 else {
                throw RostrumError.packageInvalid("ambiguous embedded face: \(typeface) \(variant.tag)")
            }
            if let face = existing.first {
                let scope = EmbeddedFontXML.scope(face, familyScope)
                let references = face.attributes.filter {
                    EmbeddedFontXML.expanded($0.name, scope, attribute: true) == "{\(EmbeddedFontXML.relationships)}id"
                }
                guard references.count == 1,
                      let rel = presentation.rels.relationship(withId: references[0].value),
                      rel.type == RelType.font, !rel.isExternal else {
                    throw RostrumError.packageInvalid("embedded face requires an internal font relationship: \(typeface) \(variant.tag)")
                }
                let uri = PackURI.resolve(target: rel.target, relativeTo: presentation.uri.baseURI)
                guard let part = package.parts[uri] else { throw RostrumError.packageInvalid("embedded font part is missing: \(uri)") }
                guard part.contentType == "application/x-fontdata", EOTLite.unwrap(part.blob) == data else {
                    throw RostrumError.packageInvalid("embedded font conflicts with requested face: \(typeface) \(variant.tag)")
                }
            } else {
                // EOT name lengths are UInt16 byte counts; total sizes are UInt32.
                // Check before the nonthrowing wrapper's integer conversions.
                let lengths = [typeface.utf16.count, variant.style.utf16.count, 11,
                               typeface.utf16.count + 1 + variant.style.utf16.count]
                guard lengths.allSatisfy({ $0 <= Int(UInt16.max) / 2 }),
                      data.count <= Int(UInt32.max) - (82 + 16 + 2 + lengths.reduce(0, +) * 2) else {
                    throw RostrumError.fontCorrupt("font embedding exceeds EOT size limits")
                }
                pending.append((variant.tag, EOTLite.wrap(data, typeface: typeface, style: variant.style,
                                                         weight: variant.weight, italic: variant.italic)))
            }
        }
    }

    func commit(to package: OPCPackage, presentation: Part) {
        guard !pending.isEmpty else { return }
        let contentType = "application/x-fontdata"
        let carriedNames = Set(package.untypedEntries.map { "/" + $0.name })
        if package.contentTypes.defaults["fntdata"] == nil,
           !carriedNames.contains(where: { $0.lowercased().hasSuffix(".fntdata") }) {
            package.contentTypes.setDefault(extension: "fntdata", contentType: contentType)
        }
        var n = 1
        for (tag, blob) in pending {
            while package.parts[PackURI("/ppt/fonts/font\(n).fntdata")] != nil
                    || carriedNames.contains("/ppt/fonts/font\(n).fntdata") { n += 1 }
            let uri = PackURI("/ppt/fonts/font\(n).fntdata")
            package.addPart(uri: uri, contentType: contentType, blob: blob)
            if package.contentTypes.defaults["fntdata"] == contentType {
                package.contentTypes.removeOverride(partName: uri)
            }
            let id = presentation.rels.add(type: RelType.font, target: presentation.uri.relativeReference(to: uri))
            let face = Self.element(tag, in: familyScope)
            if familyScope["r"] != EmbeddedFontXML.relationships {
                face[attribute: "xmlns:r"] = EmbeddedFontXML.relationships
            }
            face[attribute: "r:id"] = id
            let later = EmbeddedFontXML.variants.drop { $0 != tag }.dropFirst() + ["extLst"]
            Self.insert(face, in: family, before: Array(later), scope: familyScope)
        }
        if familyIsNew {
            Self.insert(family, in: list, before: ["extLst"], scope: EmbeddedFontXML.scope(list, rootScope))
        }
        if listIsNew {
            Self.insert(list, in: root, before: ["custShowLst", "photoAlbum", "custDataLst", "kinsoku",
                "defaultTextStyle", "modifyVerifier", "extLst"], scope: rootScope)
        }
        root[attribute: "embedTrueTypeFonts"] = "1"
        root[attribute: "saveSubsetFonts"] = "0"
        presentation.markDirty()
    }

    private static func element(_ local: String, in scope: [String: String]) -> XML.Element {
        let node = XML.Element("p:\(local)")
        if scope["p"] != EmbeddedFontXML.presentation { node[attribute: "xmlns:p"] = EmbeddedFontXML.presentation }
        return node
    }

    private static func insert(_ child: XML.Element, in parent: XML.Element,
                               before successors: [String], scope: [String: String]) {
        let names = Set(successors.map { "{\(EmbeddedFontXML.presentation)}\($0)" })
        let index = parent.children.firstIndex {
            guard case .element(let node) = $0 else { return false }
            return names.contains(EmbeddedFontXML.expanded(node.name, EmbeddedFontXML.scope(node, scope)))
        } ?? parent.children.endIndex
        parent.children.insert(.element(child), at: index)
    }
}
