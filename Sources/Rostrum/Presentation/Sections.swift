import Foundation

// Native PowerPoint sections — group slides into named, ordered sections. Stored
// as a Microsoft-2010 extension (p:presentation/p:extLst/p:ext[uri]/
// p14:sectionLst), entirely in presentation.xml: no new parts, rels, or content
// types. When no section list exists, everything here is a no-op, so a deck that
// never calls the API serializes byte-for-byte identically.

public enum SectionExt {
    /// The fixed section-list extension URI.
    public static let uri = "{521415D9-36F7-43E2-AB2F-B90AF26B5E84}"
    /// The PowerPoint 2010 namespace the section elements live in.
    public static let ns = "http://schemas.microsoft.com/office/powerpoint/2010/main"
}

/// Namespace scopes are captured before editing: XML elements have no parent
/// pointers, and moving a node must not change the meaning of its opaque XML.
private struct SectionNamespaces {
    private static let compatibility = "http://schemas.openxmlformats.org/markup-compatibility/2006"
    private struct Token: Hashable {
        let namespace: String
        let local: String?
    }
    private struct Context {
        var xml: [String: String] = [:]
        var rules: [String: Set<Token>] = [:]
        var names: [String: String] = [:]
        var unsupported = false
    }
    private var scopes: [ObjectIdentifier: [String: String]] = [:]
    private var contexts: [ObjectIdentifier: Context] = [:]
    private var parents: [ObjectIdentifier: ObjectIdentifier] = [:]

    init(_ root: XML.Element) {
        var pending = [(root, ["": "", "xml": "http://www.w3.org/XML/1998/namespace"], Context())]
        while let (element, inherited, inheritedContext) = pending.popLast() {
            var bindings = inherited
            for attribute in element.attributes {
                if attribute.name == "xmlns" { bindings[""] = attribute.value }
                else if attribute.name.hasPrefix("xmlns:") {
                    bindings[String(attribute.name.dropFirst(6))] = attribute.value
                }
            }
            let context = Self.context(of: element, bindings: bindings, inheriting: inheritedContext)
            scopes[ObjectIdentifier(element)] = bindings
            contexts[ObjectIdentifier(element)] = context
            for child in element.childElements {
                parents[ObjectIdentifier(child)] = ObjectIdentifier(element)
                pending.append((child, bindings, context))
            }
        }
    }

    private static func context(of element: XML.Element, bindings: [String: String], inheriting inherited: Context) -> Context {
        var result = inherited
        var declarations: [String: Set<Token>] = [:]
        for attribute in element.attributes {
            let pieces = attribute.name.split(separator: ":", omittingEmptySubsequences: false)
            guard pieces.count == 2, let namespace = bindings[String(pieces[0])] else { continue }
            let local = String(pieces[1])
            if namespace == "http://www.w3.org/XML/1998/namespace", ["lang", "space"].contains(local) {
                result.xml[local] = attribute.value
            } else if namespace == compatibility {
                guard ["Ignorable", "MustUnderstand", "ProcessContent", "PreserveElements", "PreserveAttributes"].contains(local) else {
                    result.unsupported = true; continue
                }
                if declarations[local] != nil { result.unsupported = true }
                result.names[local] = attribute.name
                var tokens: Set<Token> = []
                for raw in attribute.value.split(whereSeparator: \.isWhitespace) {
                    let parts = raw.split(separator: ":", omittingEmptySubsequences: false)
                    let prefixOnly = local == "Ignorable" || local == "MustUnderstand"
                    guard parts.count == (prefixOnly ? 1 : 2), parts.allSatisfy({ !$0.isEmpty }),
                          let uri = bindings[String(parts[0])], !uri.isEmpty, uri != compatibility else {
                        result.unsupported = true; continue
                    }
                    tokens.insert(Token(namespace: uri, local: prefixOnly ? nil : String(parts[1])))
                }
                declarations[local] = tokens
            }
        }
        // ECMA-376 Part 3 §9.2 considers declarations on the element and
        // every ancestor. Keep expanded namespace/name pairs across rebinding.
        for (local, tokens) in declarations { result.rules[local, default: []].formUnion(tokens) }
        return result
    }

    /// Prepare attributes without touching live XML. Destination-only inherited
    /// MC requirements cannot be cancelled by a child, so refuse those transfers.
    func localizedContext(_ member: XML.Element, to parent: XML.Element, fallbackSection: XML.Element?) throws -> [(name: String, value: String)] {
        let source = contexts[ObjectIdentifier(member)] ?? Context()
        let fallback = fallbackSection.flatMap { parents[ObjectIdentifier($0)] }.flatMap { contexts[$0] } ?? Context()
        let destination = contexts[ObjectIdentifier(parent)] ?? fallback
        guard !source.unsupported, !destination.unsupported else {
            throw RostrumError.packageInvalid("section member has unsupported inherited compatibility context")
        }
        for local in ["Ignorable", "MustUnderstand"] {
            guard destination.rules[local, default: []].isSubset(of: source.rules[local, default: []]) else {
                throw RostrumError.packageInvalid("section transfer would add inherited compatibility requirements")
            }
        }
        for local in ["ProcessContent", "PreserveElements", "PreserveAttributes"] {
            guard destination.rules[local, default: []].isSubset(of: source.rules[local, default: []]) else {
                throw RostrumError.packageInvalid("section transfer would change inherited compatibility processing")
            }
        }
        var attributes: [(name: String, value: String)] = []
        for local in ["lang", "space"] {
            if let value = source.xml[local] { attributes.append(("xml:" + local, value)) }
            else if destination.xml[local] != nil { attributes.append(("xml:" + local, local == "space" ? "default" : "")) }
        }
        var bindings = scope(member)
        func prefix(for namespace: String, preferred: String? = nil) -> String {
            if let preferred, !preferred.isEmpty, bindings[preferred] == namespace { return preferred }
            if let existing = bindings.keys.sorted().first(where: { !$0.isEmpty && bindings[$0] == namespace }) { return existing }
            var index = 1
            while bindings["sectionContext" + String(index)] != nil { index += 1 }
            let name = "sectionContext" + String(index)
            bindings[name] = namespace
            attributes.append(("xmlns:" + name, namespace))
            return name
        }
        for local in ["Ignorable", "MustUnderstand", "ProcessContent", "PreserveElements", "PreserveAttributes"] {
            let tokens = source.rules[local, default: []]
            guard !tokens.isEmpty else { continue }
            let preferred = source.names[local]?.split(separator: ":").first.map(String.init)
            let name = prefix(for: Self.compatibility, preferred: preferred) + ":" + local
            let values = tokens.sorted {
                ($0.namespace, $0.local ?? "") < ($1.namespace, $1.local ?? "")
            }.map { token in
                let name = prefix(for: token.namespace)
                return token.local.map { name + ":" + $0 } ?? name
            }
            attributes.append((name, values.joined(separator: " ")))
        }
        return attributes
    }

    func scope(_ element: XML.Element) -> [String: String] {
        scopes[ObjectIdentifier(element)] ?? [:]
    }

    func matches(_ element: XML.Element, _ local: String, namespace: String = SectionExt.ns) -> Bool {
        let pieces = element.name.split(separator: ":", omittingEmptySubsequences: false)
        guard pieces.count <= 2, pieces.allSatisfy({ !$0.isEmpty }), pieces.last.map(String.init) == local else { return false }
        let prefix = pieces.count == 2 ? String(pieces[0]) : ""
        return scope(element)[prefix] == namespace
    }

    func children(_ parent: XML.Element, _ local: String, namespace: String = SectionExt.ns) -> [XML.Element] {
        parent.childElements.filter { matches($0, local, namespace: namespace) }
    }

    func memberList(_ section: XML.Element) -> XML.Element? {
        children(section, "sldIdLst").first
    }

    func members(_ section: XML.Element) -> [XML.Element] {
        memberList(section).map { children($0, "sldId") } ?? []
    }

    /// New descendants reuse the parent's vocabulary spelling. Existing nodes
    /// retain their own spelling, even when the document mixes valid prefixes.
    static func childName(_ local: String, of parent: XML.Element) -> String {
        guard let colon = parent.name.firstIndex(of: ":") else { return local }
        return String(parent.name[...colon]) + local
    }

    static func preserveScope(_ bindings: [String: String], on element: XML.Element) {
        for prefix in bindings.keys.sorted() where prefix != "xml" {
            let name = prefix.isEmpty ? "xmlns" : "xmlns:" + prefix
            if element[attribute: name] == nil { element[attribute: name] = bindings[prefix]! }
        }
    }
}

/// Deterministic {8-4-4-4-12} GUID from a section's name + index — no UUID()/
/// random, so section ids are byte-stable across builds.
enum SectionGUID {
    static func make(name: String, index: Int, avoiding existing: Set<String>) -> String {
        var salt = 0
        var candidate = format(seed("\(index)\u{1}\(name)"))
        while existing.contains(candidate) {
            salt += 1
            candidate = format(seed("\(index)\u{1}\(name)\u{1}\(salt)"))
        }
        return candidate
    }
    private static func seed(_ s: String) -> [UInt8] {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325               // FNV-1a
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x0000_0100_0000_01b3 }
        var x = h == 0 ? 0x9e37_79b9_7f4a_7c15 : h          // splitmix64 → 16 bytes
        var bytes = [UInt8]()
        for _ in 0..<16 {
            x ^= x >> 30; x = x &* 0xbf58_476d_1ce4_e5b9
            x ^= x >> 27; x = x &* 0x94d0_49bb_1331_11eb
            x ^= x >> 31
            bytes.append(UInt8(x & 0xFF))
        }
        return bytes
    }
    private static func format(_ b: [UInt8]) -> String {
        let hex = Array(b.map { String(format: "%02X", $0) }.joined())
        func seg(_ a: Int, _ n: Int) -> String { String(hex[a..<a + n]) }
        return "{\(seg(0, 8))-\(seg(8, 4))-\(seg(12, 4))-\(seg(16, 4))-\(seg(20, 12))}"
    }
}

/// The section list of a presentation.
public final class Sections: Sequence {
    let package: OPCPackage
    let presentationPart: Part

    init(package: OPCPackage, presentationPart: Part) {
        self.package = package
        self.presentationPart = presentationPart
    }

    private func namespaces() throws -> SectionNamespaces {
        SectionNamespaces(try presentationPart.dom())
    }

    private func slideIds() throws -> [Int] {
        let dom = try presentationPart.dom()
        let names = SectionNamespaces(dom)
        return names.children(dom, "sldIdLst", namespace: MinimalTemplate.nsP).first
            .map { names.children($0, "sldId", namespace: MinimalTemplate.nsP) }?
            .compactMap { $0[attribute: "id"].flatMap(Int.init) } ?? []
    }

    private func sectionListElement(creatingIfMissing create: Bool) throws -> XML.Element? {
        let dom = try presentationPart.dom()
        let names = SectionNamespaces(dom)
        let extLists = names.children(dom, "extLst", namespace: MinimalTemplate.nsP)
        let extensions = extLists.flatMap { names.children($0, "ext", namespace: MinimalTemplate.nsP) }
            .filter { $0[attribute: "uri"] == SectionExt.uri }
        guard extensions.count <= 1 else {
            throw RostrumError.packageInvalid("multiple section extensions cannot be maintained")
        }
        let existing = extensions.first
        if let existing {
            let lists = names.children(existing, "sectionLst")
            guard lists.count <= 1 else {
                throw RostrumError.packageInvalid("multiple section lists cannot be maintained")
            }
            if let list = lists.first {
                try validateStructure(list, names: names)
                return list
            }
            // A section URI with misspelled/undeclared vocabulary is malformed,
            // rather than sectionless: slide edits must not leave stale members.
            guard !existing.childElements.contains(where: { $0.name.split(separator: ":").last == "sectionLst" }) else {
                throw RostrumError.packageInvalid("section list has an invalid namespace")
            }
        }
        guard create else { return nil }
        let list = XML.Element("p14:sectionLst", attributes: [("xmlns:p14", SectionExt.ns)])
        if let existing { existing.appendElement(list) }
        else {
            let extLst: XML.Element
            if let found = extLists.first { extLst = found }
            else {
                extLst = XML.Element(SectionNamespaces.childName("extLst", of: dom))
                dom.appendElement(extLst)
            }
            let ext = XML.Element(SectionNamespaces.childName("ext", of: extLst), attributes: [("uri", SectionExt.uri)])
            ext.appendElement(list)
            extLst.appendElement(ext)
        }
        presentationPart.markDirty()
        return list
    }

    private func validateStructure(_ list: XML.Element, names: SectionNamespaces) throws {
        let sections = names.children(list, "section")
        if sections.isEmpty, list.childElements.contains(where: { $0.name.split(separator: ":").last == "section" }) {
            throw RostrumError.packageInvalid("section entries have an invalid namespace")
        }
        for section in sections {
            let memberLists = names.children(section, "sldIdLst")
            guard !memberLists.isEmpty || !section.childElements.contains(where: { $0.name.split(separator: ":").last == "sldIdLst" }) else {
                throw RostrumError.packageInvalid("section member list has an invalid namespace")
            }
            guard memberLists.count <= 1 else {
                throw RostrumError.packageInvalid("section has multiple member lists")
            }
        }
    }

    private var elements: [XML.Element] {
        guard let list = try? sectionListElement(creatingIfMissing: false),
              let names = try? namespaces() else { return [] }
        return names.children(list, "section")
    }

    public var count: Int { elements.count }

    /// The section at `index`. Throws on out-of-range — the section list (and
    /// so the valid index space) comes from the file, and opening untrusted
    /// files must never abort the host process. Same contract as
    /// `Slides.subscript`.
    public subscript(index: Int) -> Section {
        get throws {
            let elements = self.elements
            guard elements.indices.contains(index) else {
                throw RostrumError.packageInvalid(
                    "section index \(index) out of range 0..<\(elements.count)")
            }
            return Section(element: elements[index], package: package,
                           presentationPart: presentationPart)
        }
    }

    public func makeIterator() -> AnyIterator<Section> {
        var i = 0
        return AnyIterator { defer { i += 1 }; return i < self.count ? (try? self[i]) : nil }
    }

    /// Replace all sections with a full partition of the deck's current slides.
    /// Boundaries are (name, first-slide-index); the first must start at 0, and
    /// starts must strictly increase and be in range — violations THROW rather
    /// than trap. Section boundaries routinely arrive from dynamic data (a
    /// parsed outline, a model's plan), and an abort the caller cannot catch
    /// turns a resortable input into a dead process. This is the safest
    /// section primitive — call it after adding the slides.
    public func set(_ boundaries: [(name: String, startSlide: Int)]) throws {
        let ids = try slideIds()
        guard !boundaries.isEmpty else {
            throw RostrumError.packageInvalid("need at least one section boundary")
        }
        guard boundaries[0].startSlide == 0 else {
            throw RostrumError.packageInvalid(
                "the first section must start at slide 0, not \(boundaries[0].startSlide)")
        }
        // The slide list comes from the file: an empty one is a malformed deck
        // to report, exactly like a bad boundary list is a bad input to report.
        guard !ids.isEmpty else {
            throw RostrumError.packageInvalid("the deck has no slides to partition into sections")
        }
        for i in boundaries.indices {
            guard boundaries[i].startSlide >= 0, boundaries[i].startSlide < ids.count else {
                throw RostrumError.packageInvalid(
                    "section start slide \(boundaries[i].startSlide) is outside this deck's "
                        + "\(ids.count) slides")
            }
            if i > 0 {
                guard boundaries[i].startSlide > boundaries[i - 1].startSlide else {
                    throw RostrumError.packageInvalid(
                        "section starts must strictly increase; boundary \(i) starts at slide "
                            + "\(boundaries[i].startSlide), after one starting at "
                            + "\(boundaries[i - 1].startSlide) — sort and dedupe the list first")
                }
            }
        }
        let list = try sectionListElement(creatingIfMissing: true)!
        let names = try namespaces()
        let oldSections = names.children(list, "section")
        var sections: [XML.Element] = []
        var updates: [(section: XML.Element, ids: [Int])] = []
        var used = Set<String>()
        for (i, boundary) in boundaries.enumerated() {
            let end = i + 1 < boundaries.count ? boundaries[i + 1].startSlide : ids.count
            let guid = SectionGUID.make(name: boundary.name, index: i, avoiding: used)
            used.insert(guid)
            let section = XML.Element(SectionNamespaces.childName("section", of: list), attributes: [("name", boundary.name), ("id", guid)])
            section.appendElement(XML.Element(SectionNamespaces.childName("sldIdLst", of: section)))
            sections.append(section)
            updates.append((section, Array(ids[boundary.startSlide..<end])))
        }
        // Rebuild through the shared helper rather than clearing `children`,
        // so a comment or processing instruction in the section list survives
        // being re-sectioned.
        try SectionMembershipPlan(updates: updates, presentation: presentationPart, membersFrom: oldSections, names: names).commit()
        Self.replaceKnownChildren(in: list, replacing: oldSections, with: sections)
        presentationPart.markDirty()
    }

    /// Current section boundaries (name, first-slide-index), derived from the
    /// stored section list.
    func boundaries() throws -> [(name: String, startSlide: Int)] {
        let ids = try slideIds()
        let indexOf = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let names = try namespaces()
        return elements.map { section in
            let name = section[attribute: "name"] ?? ""
            let firstId = names.members(section).first?[attribute: "id"].flatMap(Int.init)
            return (name, firstId.flatMap { indexOf[$0] } ?? 0)
        }
    }

    /// Insert a section boundary starting at `startIndex`, splitting the section
    /// that currently owns it, preserving existing section IDs and extensions.
    @discardableResult
    public func add(_ name: String, startingAtSlide startIndex: Int) throws -> Section {
        let ids = try slideIds()
        guard ids.indices.contains(startIndex) else {
            throw RostrumError.packageInvalid("section start slide is outside this deck")
        }
        // Namespace/structural errors are never repaired by treating the deck
        // as sectionless. The historical boundary repair still handles bad IDs.
        _ = try sectionListElement(creatingIfMissing: false)
        guard let current = try? membership() else {
            // addSection historically repairs malformed foreign boundaries.
            // Preserve that explicit repair API; slide lifecycle operations
            // still refuse malformed membership before changing the deck.
            var bounds = try boundaries()
            bounds.removeAll { $0.startSlide == startIndex }
            bounds.append((name, startIndex))
            bounds.sort { $0.startSlide < $1.startSlide }
            var seen: Set<Int> = [startIndex]
            bounds = bounds.filter { $0.startSlide == startIndex || seen.insert($0.startSlide).inserted }
            if bounds.first?.startSlide != 0 { bounds.insert(("Default", 0), at: 0) }
            try set(bounds)
            guard let index = try boundaries().firstIndex(where: { $0.startSlide == startIndex }) else {
                throw RostrumError.packageInvalid("written section boundary cannot be resolved")
            }
            return try self[index]
        }
        let owningIndex = current.owner[ids[startIndex]]!
        let owning = current.sections[owningIndex]
        let members = ids.filter { current.owner[$0] == owningIndex }
        if members.first == ids[startIndex] {
            owning[attribute: "name"] = name
            presentationPart.markDirty()
            return Section(element: owning, package: package, presentationPart: presentationPart)
        }
        let split = members.firstIndex(of: ids[startIndex])!
        let used = Set(current.sections.compactMap { $0[attribute: "id"] })
        let sectionList = try sectionListElement(creatingIfMissing: false)!
        let section = XML.Element(SectionNamespaces.childName("section", of: sectionList), attributes: [
            ("name", name), ("id", SectionGUID.make(name: name, index: startIndex, avoiding: used)),
        ])
        section.appendElement(XML.Element(SectionNamespaces.childName("sldIdLst", of: section)))
        var sections = current.sections
        sections.insert(section, at: owningIndex + 1)
        try SectionMembershipPlan(updates: [(owning, Array(members.prefix(split))), (section, Array(members.dropFirst(split)))],
                              presentation: presentationPart, membersFrom: current.sections, names: current.names).commit()
        Self.replaceKnownChildren(in: sectionList, replacing: current.sections, with: sections)
        presentationPart.markDirty()
        return Section(element: section, package: package, presentationPart: presentationPart)

    }
}

/// One section (`p14:section`).
public final class Section {
    let element: XML.Element
    let package: OPCPackage
    let presentationPart: Part

    init(element: XML.Element, package: OPCPackage, presentationPart: Part) {
        self.element = element
        self.package = package
        self.presentationPart = presentationPart
    }

    public var name: String {
        get { element[attribute: "name"] ?? "" }
        set { element[attribute: "name"] = newValue; presentationPart.markDirty() }
    }

    /// The section's GUID id.
    public var id: String { element[attribute: "id"] ?? "" }

    /// Indices (into the deck's slide order) of the slides in this section.
    public var slideIndices: [Int] {
        guard let root = try? presentationPart.dom() else { return [] }
        let names = SectionNamespaces(root)
        let ids = names.children(root, "sldIdLst", namespace: MinimalTemplate.nsP).first
            .map { names.children($0, "sldId", namespace: MinimalTemplate.nsP) }?
            .compactMap { $0[attribute: "id"].flatMap(Int.init) } ?? []
        let indexOf = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return names.members(element).compactMap { $0[attribute: "id"].flatMap(Int.init) }
            .compactMap { indexOf[$0] }
    }

    public var slideCount: Int {
        guard let root = try? presentationPart.dom() else { return 0 }
        return SectionNamespaces(root).members(element).count
    }

    /// The section's slides, skipping any entry whose part cannot be resolved
    /// (matching `Slides` iteration semantics on malformed decks).
    public var slides: [Slide] {
        let all = Slides(package: package, presentationPart: presentationPart)
        return slideIndices.compactMap { try? all.slide(at: $0) }
    }
}

public extension Presentation {
    /// The deck's sections.
    var sections: Sections { Sections(package: package, presentationPart: presentationPart) }

    /// Replace all sections with a full partition. See `Sections.set`.
    func setSections(_ boundaries: [(name: String, startSlide: Int)]) throws {
        try sections.set(boundaries)
    }

    /// Insert a section boundary at a slide index. See `Sections.add`.
    @discardableResult
    func addSection(_ name: String, startingAtSlide startIndex: Int) throws -> Section {
        try sections.add(name, startingAtSlide: startIndex)
    }
}

/// Prepared membership edits preserve the existing section/slide-ID elements
/// (and their unknown XML) rather than rebuilding sections from boundaries.
struct SectionMembershipPlan {
    let updates: [(section: XML.Element, ids: [Int])]
    let presentation: Part
    private let names: SectionNamespaces
    private let membersByID: [Int: (element: XML.Element, section: XML.Element, bindings: [String: String])]
    private let contextAttributes: [ObjectIdentifier: [(name: String, value: String)]]

    fileprivate init(updates: [(section: XML.Element, ids: [Int])], presentation: Part,
                     membersFrom sections: [XML.Element], names: SectionNamespaces) throws {
        self.updates = updates
        self.presentation = presentation
        self.names = names
        var byID: [Int: (element: XML.Element, section: XML.Element, bindings: [String: String])] = [:]
        for section in sections {
            for entry in names.members(section) {
                if let id = entry[attribute: "id"].flatMap(Int.init) {
                    byID[id] = (entry, section, names.scope(entry))
                }
            }
        }
        membersByID = byID
        var prepared: [ObjectIdentifier: [(name: String, value: String)]] = [:]
        for (section, ids) in updates {
            for id in ids {
                if let source = byID[id], source.section !== section {
                    prepared[ObjectIdentifier(source.element)] = try names.localizedContext(source.element,
                        to: names.memberList(section) ?? section, fallbackSection: sections.first)
                }
            }
        }
        contextAttributes = prepared
    }

    func commit() {
        for (section, ids) in updates {
            let list: XML.Element
            if let found = names.memberList(section) { list = found }
            else if names.scope(section).isEmpty, let detached = section.childElements.first(where: { $0.name == SectionNamespaces.childName("sldIdLst", of: section) }) {
                list = detached
            } else {
                list = XML.Element(SectionNamespaces.childName("sldIdLst", of: section))
                section.appendElement(list)
            }
            let members = ids.map { id -> XML.Element in
                guard let source = membersByID[id] else {
                    return XML.Element(SectionNamespaces.childName("sldId", of: list), attributes: [("id", String(id))])
                }
                if source.section !== section {
                    SectionNamespaces.preserveScope(source.bindings, on: source.element)
                    for attribute in contextAttributes[ObjectIdentifier(source.element)] ?? [] {
                        source.element[attribute: attribute.name] = attribute.value
                    }
                }
                return source.element
            }
            Sections.replaceKnownChildren(in: list, replacing: names.children(list, "sldId"), with: members)
        }
        if !updates.isEmpty { presentation.markDirty() }
    }
}

extension Sections {
    struct Membership {
        let sections: [XML.Element]
        let liveIDs: [Int]
        let owner: [Int: Int]
        fileprivate let names: SectionNamespaces
    }

    /// Sectionless decks remain sectionless. Existing sections must partition
    /// the live slides; malformed references are refused before any mutation.
    func membership() throws -> Membership? {
        guard let list = try sectionListElement(creatingIfMissing: false) else { return nil }
        let names = try namespaces()
        let sections = names.children(list, "section")
        guard !sections.isEmpty else { return nil }
        let liveIDs = try slideIds()
        guard Set(liveIDs).count == liveIDs.count else {
            throw RostrumError.packageInvalid("duplicate slide IDs prevent section maintenance")
        }
        let live = Set(liveIDs)
        var owner: [Int: Int] = [:]
        var ordered: [Int] = []
        for (index, section) in sections.enumerated() {
            for entry in names.members(section) {
                guard let id = entry[attribute: "id"].flatMap(Int.init), live.contains(id), owner[id] == nil else {
                    throw RostrumError.packageInvalid("sections contain stale or duplicate slide references")
                }
                owner[id] = index
                ordered.append(id)
            }
        }
        guard ordered == liveIDs else {
            throw RostrumError.packageInvalid("sections must cover every slide once in presentation order")
        }
        return Membership(sections: sections, liveIDs: liveIDs, owner: owner, names: names)
    }

    /// Insertion before a boundary belongs to the following section; appends
    /// belong to the last section (including an explicitly retained empty one).
    /// A duplicate belongs to its original's section. Moves adopt the section
    /// at their destination after removal. Empty sections retain their IDs.
    func maintainSectionMembership(order: [Int], insertedAt position: Int? = nil,
                                   insertedIDs: [Int] = [], duplicateOf original: Int? = nil,
                                   moving movedID: Int? = nil) throws -> SectionMembershipPlan? {
        guard let current = try membership() else { return nil }
        var owner = current.owner
        if !insertedIDs.isEmpty || movedID != nil {
            let remaining = current.liveIDs.filter { $0 != movedID }
            let index = position ?? remaining.count
            guard index >= 0, index <= remaining.count else {
                throw RostrumError.packageInvalid("section insertion index out of range")
            }
            let destination = original.flatMap { owner[$0] }
                ?? (index < remaining.count ? owner[remaining[index]] : current.sections.count - 1)
                ?? current.sections.count - 1
            for id in insertedIDs { owner[id] = destination }
            if let movedID { owner[movedID] = destination }
        }
        guard Set(order).count == order.count, order.allSatisfy({ owner[$0] != nil }) else {
            throw RostrumError.packageInvalid("section mutation has unassigned or duplicate slides")
        }
        let assigned = order.compactMap { owner[$0] }
        guard assigned == assigned.sorted() else {
            throw RostrumError.packageInvalid("section mutation would interleave section membership")
        }
        let updates = current.sections.enumerated().map { index, section in
            (section: section, ids: order.filter { owner[$0] == index })
        }
        return try SectionMembershipPlan(updates: updates, presentation: presentationPart, membersFrom: current.sections, names: current.names)
    }

    /// Preserve foreign elements, comments and instructions while replacing
    /// only the named vocabulary, reusing existing element slots where possible.
    static func replaceKnownChildren(in parent: XML.Element, replacing old: [XML.Element], with elements: [XML.Element]) {
        let identities = Set(old.map(ObjectIdentifier.init))
        var index = 0
        var children: [XML.Node] = []
        for child in parent.children {
            if case .element(let element) = child, identities.contains(ObjectIdentifier(element)) {
                if index < elements.count { children.append(.element(elements[index])); index += 1 }
            } else { children.append(child) }
        }
        children.append(contentsOf: elements.dropFirst(index).map { .element($0) })
        parent.children = children
    }

    /// Remove a section boundary, transferring its slides to the preceding
    /// section, or the following section when removing the first. Removing the
    /// final section leaves the deck sectionless; slide order never changes.
    public func remove(at index: Int) throws {
        guard let current = try membership(), current.sections.indices.contains(index),
              let list = try sectionListElement(creatingIfMissing: false) else {
            throw RostrumError.packageInvalid("section removal index out of range")
        }
        let removed = current.sections[index]
        if current.sections.count > 1 {
            let recipient = index > 0 ? index - 1 : 1
            let ids = current.liveIDs.filter { current.owner[$0] == index || current.owner[$0] == recipient }
            try SectionMembershipPlan(updates: [(current.sections[recipient], ids)], presentation: presentationPart, membersFrom: current.sections, names: current.names).commit()
        }
        list.removeChild(removed)
        presentationPart.markDirty()
    }

    /// Reorder entire sections together with their slides. Both indices use
    /// the final section order, matching Slides.move(from:to:).
    public func move(from: Int, to: Int) throws {
        guard let current = try membership(), current.sections.indices.contains(from),
              current.sections.indices.contains(to),
              let list = try sectionListElement(creatingIfMissing: false),
              let slides = current.names.children(try presentationPart.dom(), "sldIdLst", namespace: MinimalTemplate.nsP).first else {
            throw RostrumError.packageInvalid("section move index out of range")
        }
        var sections = current.sections
        let section = sections.remove(at: from)
        sections.insert(section, at: to)
        let ids = sections.flatMap { section in
            current.names.members(section).compactMap { $0[attribute: "id"].flatMap(Int.init) }
        }
        let entries = current.names.children(slides, "sldId", namespace: MinimalTemplate.nsP)
        var byID: [Int: XML.Element] = [:]
        for entry in entries {
            if let id = entry[attribute: "id"].flatMap(Int.init) { byID[id] = entry }
        }
        let reordered = try ids.map { id in
            guard let entry = byID[id] else { throw RostrumError.packageInvalid("section slide cannot be resolved") }
            return entry
        }
        Self.replaceKnownChildren(in: list, replacing: current.sections, with: sections)
        Self.replaceKnownChildren(in: slides, replacing: entries, with: reordered)
        presentationPart.markDirty()
    }
}
