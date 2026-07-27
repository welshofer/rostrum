import Foundation

/// The `[Content_Types].xml` stream: maps part names to MIME-ish content types
/// via extension-based `Default` rules and part-specific `Override` rules.
public struct ContentTypesMap {
    /// Extension (lowercased, no dot) → content type.
    public private(set) var defaults: [String: String]
    /// Part URI → content type. Wins over any Default.
    public private(set) var overrides: [PackURI: String]

    /// The bytes this map was parsed from and the maps they encoded, so an
    /// untouched package re-emits its content-types stream verbatim.
    /// Rebuilding sorts Defaults and Overrides, while Office writes Overrides
    /// in document order — a foreign package's stream would otherwise change
    /// on every save.
    ///
    /// Comparing the maps rather than latching a dirty flag means a change
    /// that nets out — adding a part's override and removing it again, which
    /// the image-dedup path does on every save — still re-emits the original.
    private var pristine: Data?
    private var pristineDefaults: [String: String]?
    private var pristineOverrides: [PackURI: String]?

    static let namespace = "http://schemas.openxmlformats.org/package/2006/content-types"

    /// Every package needs these two Defaults to be readable at all.
    public init() {
        defaults = [
            "rels": ContentType.opcRelationships,
            "xml": "application/xml",
        ]
        overrides = [:]
    }

    public mutating func setDefault(extension ext: String, contentType: String) {
        defaults[ext.lowercased()] = contentType
    }

    public mutating func setOverride(partName: PackURI, contentType: String) {
        overrides[partName] = contentType
    }

    public mutating func removeOverride(partName: PackURI) {
        overrides[partName] = nil
    }

    /// Override first, then extension Default.
    public func contentType(for partName: PackURI) throws -> String {
        if let ct = overrides[partName] { return ct }
        if let ct = defaults[partName.ext] { return ct }
        throw RostrumError.packageInvalid("no content type for part \(partName)")
    }

    public static func parse(_ data: Data) throws -> ContentTypesMap {
        let root = try XML.parse(data)
        guard root.name == "Types" else {
            throw RostrumError.packageInvalid("[Content_Types].xml root is <\(root.name)>, expected <Types>")
        }
        var map = ContentTypesMap()
        for child in root.childElements {
            switch child.name {
            case "Default":
                guard let ext = child[attribute: "Extension"], let ct = child[attribute: "ContentType"] else {
                    throw RostrumError.packageInvalid("<Default> missing Extension or ContentType")
                }
                map.defaults[ext.lowercased()] = ct
            case "Override":
                guard let part = child[attribute: "PartName"], let ct = child[attribute: "ContentType"] else {
                    throw RostrumError.packageInvalid("<Override> missing PartName or ContentType")
                }
                map.overrides[PackURI(part)] = ct
            default:
                continue
            }
        }
        map.pristine = data
        map.pristineDefaults = map.defaults
        map.pristineOverrides = map.overrides
        return map
    }

    /// The original bytes when the map still matches what was parsed;
    /// otherwise a deterministic rebuild (Defaults sorted by extension, then
    /// Overrides sorted by part name).
    public func serialized() -> Data {
        if let pristine, defaults == pristineDefaults, overrides == pristineOverrides {
            return pristine
        }
        return rebuilt()
    }

    private func rebuilt() -> Data {
        let root = XML.Element("Types", attributes: [("xmlns", Self.namespace)])
        for (ext, ct) in defaults.sorted(by: { $0.key < $1.key }) {
            root.appendElement(XML.Element("Default", attributes: [("Extension", ext), ("ContentType", ct)]))
        }
        for (part, ct) in overrides.sorted(by: { $0.key.value < $1.key.value }) {
            root.appendElement(XML.Element("Override", attributes: [("PartName", part.value), ("ContentType", ct)]))
        }
        return XML.document(root)
    }
}

/// Well-known OPC and PresentationML content types (python-pptx: `pptx.opc.constants.CONTENT_TYPE`).
public enum ContentType {
    public static let opcRelationships = "application/vnd.openxmlformats-package.relationships+xml"
    public static let opcCoreProperties = "application/vnd.openxmlformats-package.core-properties+xml"
    public static let officeExtendedProperties = "application/vnd.openxmlformats-officedocument.extended-properties+xml"
    public static let officeCustomProperties = "application/vnd.openxmlformats-officedocument.custom-properties+xml"
    public static let theme = "application/vnd.openxmlformats-officedocument.theme+xml"

    public static let presentationMain = "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"
    /// A PowerPoint template (`.potx`). Structurally identical to a
    /// presentation; only the main part's content type differs.
    public static let presentationTemplateMain = "application/vnd.openxmlformats-officedocument.presentationml.template.main+xml"
    /// A PowerPoint slide show (`.ppsx`); also normalizes to a presentation.
    public static let slideShowMain = "application/vnd.openxmlformats-officedocument.presentationml.slideshow.main+xml"
    public static let slideMaster = "application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"
    public static let slideLayout = "application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"
    public static let slide = "application/vnd.openxmlformats-officedocument.presentationml.slide+xml"
    public static let notesMaster = "application/vnd.openxmlformats-officedocument.presentationml.notesMaster+xml"
    public static let notesSlide = "application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml"
    public static let presProps = "application/vnd.openxmlformats-officedocument.presentationml.presProps+xml"
    public static let viewProps = "application/vnd.openxmlformats-officedocument.presentationml.viewProps+xml"
    public static let tableStyles = "application/vnd.openxmlformats-officedocument.presentationml.tableStyles+xml"

    public static let png = "image/png"
    public static let jpeg = "image/jpeg"
    public static let gif = "image/gif"
    public static let svg = "image/svg+xml"
}

/// Well-known relationship type URIs (python-pptx: `pptx.opc.constants.RELATIONSHIP_TYPE`).
public enum RelType {
    public static let officeDocument = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
    public static let coreProperties = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
    public static let extendedProperties = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties"
    public static let customProperties = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/custom-properties"
    public static let slideMaster = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster"
    public static let slideLayout = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout"
    public static let slide = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"
    public static let theme = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme"
    public static let notesMaster = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesMaster"
    public static let notesSlide = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide"
    public static let image = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"
    public static let hyperlink = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink"
    public static let presProps = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/presProps"
    public static let viewProps = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/viewProps"
    public static let tableStyles = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/tableStyles"
}
