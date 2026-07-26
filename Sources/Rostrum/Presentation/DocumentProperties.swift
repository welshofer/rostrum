import Foundation

/// The document's metadata: OPC core properties (`docProps/core.xml`), the
/// Office extended properties (`docProps/app.xml`), and user-defined custom
/// properties (`docProps/custom.xml`).
///
/// A live view — every accessor reads and writes the underlying part, so
/// there is nothing to save separately. Reads never create a part: a deck
/// without `docProps/custom.xml` reports no custom properties rather than
/// growing an empty one.
///
/// Dates are `Date` values you supply. Rostrum never stamps wall-clock time
/// of its own, because identical input must produce identical bytes.
public final class DocumentProperties {
    private let package: OPCPackage

    init(package: OPCPackage) {
        self.package = package
    }

    // MARK: - Core properties (docProps/core.xml)

    /// Title (`dc:title`).
    public var title: String? {
        get { core("dc:title") }
        set { setCore("dc:title", newValue) }
    }

    /// Author (`dc:creator`).
    public var author: String? {
        get { core("dc:creator") }
        set { setCore("dc:creator", newValue) }
    }

    /// Subject (`dc:subject`).
    public var subject: String? {
        get { core("dc:subject") }
        set { setCore("dc:subject", newValue) }
    }

    /// Description / comments (`dc:description`).
    public var comments: String? {
        get { core("dc:description") }
        set { setCore("dc:description", newValue) }
    }

    /// Keywords / tags (`cp:keywords`).
    public var keywords: String? {
        get { core("cp:keywords") }
        set { setCore("cp:keywords", newValue) }
    }

    /// Category (`cp:category`).
    public var category: String? {
        get { core("cp:category") }
        set { setCore("cp:category", newValue) }
    }

    /// Last modified by (`cp:lastModifiedBy`).
    public var lastModifiedBy: String? {
        get { core("cp:lastModifiedBy") }
        set { setCore("cp:lastModifiedBy", newValue) }
    }

    /// Revision number (`cp:revision`).
    public var revision: Int? {
        get { core("cp:revision").flatMap { Int($0) } }
        set { setCore("cp:revision", newValue.map(String.init)) }
    }

    /// Content status, e.g. "Draft" (`cp:contentStatus`).
    public var contentStatus: String? {
        get { core("cp:contentStatus") }
        set { setCore("cp:contentStatus", newValue) }
    }

    /// Created timestamp (`dcterms:created`).
    public var created: Date? {
        get { core("dcterms:created").flatMap(Self.parseDate) }
        set { setCore("dcterms:created", newValue.map(Self.formatDate), isDate: true) }
    }

    /// Last-modified timestamp (`dcterms:modified`).
    public var modified: Date? {
        get { core("dcterms:modified").flatMap(Self.parseDate) }
        set { setCore("dcterms:modified", newValue.map(Self.formatDate), isDate: true) }
    }

    // MARK: - Extended properties (docProps/app.xml)

    /// The authoring application (`Application`).
    public var application: String? {
        get { extended("Application") }
        set { setExtended("Application", newValue) }
    }

    /// Company (`Company`).
    public var company: String? {
        get { extended("Company") }
        set { setExtended("Company", newValue) }
    }

    /// Manager (`Manager`).
    public var manager: String? {
        get { extended("Manager") }
        set { setExtended("Manager", newValue) }
    }

    // MARK: - Custom properties (docProps/custom.xml)

    /// A user-defined property's value. Rostrum models the string, number,
    /// boolean and date variants Office writes; anything else reads as its
    /// raw text.
    public enum CustomValue: Equatable, Sendable {
        case text(String)
        case number(Int)
        case decimal(Double)
        case boolean(Bool)
        case date(Date)

        var elementName: String {
            switch self {
            case .text: return "vt:lpwstr"
            case .number: return "vt:i4"
            case .decimal: return "vt:r8"
            case .boolean: return "vt:bool"
            case .date: return "vt:filetime"
            }
        }

        var literal: String {
            switch self {
            case .text(let s): return s
            case .number(let n): return String(n)
            case .decimal(let d): return String(d)
            case .boolean(let b): return b ? "true" : "false"
            case .date(let d): return DocumentProperties.formatDate(d)
            }
        }

        init?(element: XML.Element) {
            let text = element.textContent
            switch element.name {
            case "vt:lpwstr", "vt:lpstr": self = .text(text)
            case "vt:i4", "vt:int": self = Int(text).map(CustomValue.number) ?? .text(text)
            case "vt:r8": self = Double(text).map(CustomValue.decimal) ?? .text(text)
            case "vt:bool": self = .boolean(text == "true" || text == "1")
            case "vt:filetime": self = DocumentProperties.parseDate(text).map(CustomValue.date) ?? .text(text)
            default: self = .text(text)
            }
        }
    }

    /// Every custom property, in document order.
    public var custom: [(name: String, value: CustomValue)] {
        guard let part = package.parts[Self.customURI],
              let root = try? part.dom() else { return [] }
        return root.children(named: "property").compactMap { property in
            guard let name = property[attribute: "name"],
                  let valueElement = property.childElements.first,
                  let value = CustomValue(element: valueElement) else { return nil }
            return (name, value)
        }
    }

    /// Read a custom property by name.
    public func customValue(_ name: String) -> CustomValue? {
        custom.first { $0.name == name }?.value
    }

    /// Set (or, with nil, remove) a custom property. Creates
    /// `docProps/custom.xml` and its relationship on first use.
    public func setCustomValue(_ value: CustomValue?, for name: String) {
        guard let part = customPart(creatingIfNeeded: value != nil),
              let root = try? part.dom() else { return }

        for existing in root.children(named: "property")
        where existing[attribute: "name"] == name {
            root.removeChild(existing)
        }
        if let value {
            let property = XML.Element("property", attributes: [
                ("fmtid", Self.customFormatID),
                // pid is 1-based and starts at 2; ids must be unique and
                // contiguous, so renumber the whole list after the edit.
                ("pid", "0"), ("name", name),
            ])
            let valueElement = XML.Element(value.elementName)
            valueElement.children = [.text(value.literal)]
            property.appendElement(valueElement)
            root.appendElement(property)
        }
        for (index, property) in root.children(named: "property").enumerated() {
            property[attribute: "pid"] = String(index + 2)
        }
        part.markDirty()
    }

    // MARK: - Core/extended plumbing

    private static let coreURI = PackURI("/docProps/core.xml")
    private static let appURI = PackURI("/docProps/app.xml")
    static let customURI = PackURI("/docProps/custom.xml")
    /// The format id Office writes for user-defined properties.
    private static let customFormatID = "{D5CDD505-2E9C-101B-9397-08002B2CF9AE}"

    /// The child order `CT_CoreProperties` requires (xsd:sequence).
    private static let coreOrder = [
        "dc:title", "dc:subject", "dc:creator", "cp:keywords", "dc:description",
        "cp:lastModifiedBy", "cp:revision", "cp:lastPrinted",
        "dcterms:created", "dcterms:modified", "cp:category", "cp:contentStatus",
    ]

    private func core(_ name: String) -> String? {
        guard let part = package.parts[Self.coreURI],
              let root = try? part.dom(),
              let element = root.firstChild(named: name) else { return nil }
        let text = element.textContent
        return text.isEmpty ? nil : text
    }

    private func setCore(_ name: String, _ value: String?, isDate: Bool = false) {
        guard let part = package.parts[Self.coreURI],
              let root = try? part.dom() else { return }
        root.removeChildren(named: name)
        if let value {
            let successors = Array(Self.coreOrder.drop(while: { $0 != name }).dropFirst())
            let element = XML.Element(name)
            if isDate { element[attribute: "xsi:type"] = "dcterms:W3CDTF" }
            element.children = [.text(value)]
            root.insertChild(element, beforeAnyOf: successors)
        }
        part.markDirty()
    }

    private func extended(_ name: String) -> String? {
        guard let part = package.parts[Self.appURI],
              let root = try? part.dom(),
              let element = root.firstChild(named: name) else { return nil }
        let text = element.textContent
        return text.isEmpty ? nil : text
    }

    private func setExtended(_ name: String, _ value: String?) {
        guard let part = package.parts[Self.appURI],
              let root = try? part.dom() else { return }
        root.removeChildren(named: name)
        if let value {
            let element = XML.Element(name)
            element.children = [.text(value)]
            root.appendElement(element)
        }
        part.markDirty()
    }

    /// The custom-properties part, created (with its content-type override
    /// and package relationship) only when a value is being written.
    private func customPart(creatingIfNeeded create: Bool) -> Part? {
        if let existing = package.parts[Self.customURI] { return existing }
        guard create else { return nil }
        let part = package.addPart(
            uri: Self.customURI,
            contentType: ContentType.officeCustomProperties,
            blob: Data("""
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/custom-properties"\
 xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"></Properties>
                """.utf8))
        package.rels.add(type: RelType.customProperties, target: "docProps/custom.xml")
        return part
    }

    // MARK: - Dates

    /// W3CDTF, the profile OPC requires — and always UTC, so the same `Date`
    /// serializes identically wherever the code runs.
    static func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}

public extension Presentation {
    /// The document's metadata — title, author, timestamps, company, and
    /// user-defined custom properties.
    ///
    /// Timestamps are never stamped automatically: set `modified` yourself
    /// when you want one, so that building the same deck twice keeps
    /// producing the same bytes.
    var documentProperties: DocumentProperties {
        DocumentProperties(package: package)
    }
}
