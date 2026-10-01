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

    private func slideIds() throws -> [Int] {
        (try presentationPart.dom().firstChild(named: "p:sldIdLst")?.children(named: "p:sldId") ?? [])
            .compactMap { $0[attribute: "id"].flatMap { Int($0) } }
    }

    private func sectionListElement(creatingIfMissing create: Bool) throws -> XML.Element? {
        let dom = try presentationPart.dom()
        // Reuse the ext carrying the section URI if there is one. A foreign
        // deck can have that ext without a `p14:sectionLst` child — empty, or
        // spelling the 2010 namespace with a different prefix, both legal.
        // Appending a *second* ext with the same URI would leave the reader
        // resolving to the first, so `elements` would stay empty and the
        // caller-facing `add` would index an empty array.
        let existing = dom.firstChild(named: "p:extLst")?.children(named: "p:ext")
            .first(where: { $0[attribute: "uri"] == SectionExt.uri })
        if let existing {
            var unsupported = false
            ModernComments.visit(in: dom) { element, namespace, local in
                if namespace == SectionExt.ns, ["sectionLst", "section", "sldIdLst", "sldId"].contains(local),
                   !element.name.hasPrefix("p14:") { unsupported = true }
            }
            guard !unsupported else {
                throw RostrumError.packageInvalid("aliased section vocabulary cannot be edited without preserving its namespace")
            }
            if let list = existing.firstChild(named: "p14:sectionLst") { return list }
        }
        guard create else { return nil }
        let list = XML.Element("p14:sectionLst", attributes: [("xmlns:p14", SectionExt.ns)])
        if let existing {
            existing.appendElement(list)
        } else {
            let extLst = dom.getOrAddChild("p:extLst")             // extLst is last in p:presentation
            let ext = XML.Element("p:ext", attributes: [("uri", SectionExt.uri)])
            ext.appendElement(list)
            extLst.appendElement(ext)
        }
        presentationPart.markDirty()
        return list
    }

    private var elements: [XML.Element] {
        ((try? sectionListElement(creatingIfMissing: false)) ?? nil)?.children(named: "p14:section") ?? []
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
        var sections: [XML.Element] = []
        var used = Set<String>()
        for (i, boundary) in boundaries.enumerated() {
            let end = i + 1 < boundaries.count ? boundaries[i + 1].startSlide : ids.count
            let guid = SectionGUID.make(name: boundary.name, index: i, avoiding: used)
            used.insert(guid)
            let section = XML.Element("p14:section", attributes: [("name", boundary.name), ("id", guid)])
            let sldIdLst = XML.Element("p14:sldIdLst")
            for slide in boundary.startSlide..<end {
                sldIdLst.appendElement(XML.Element("p14:sldId", attributes: [("id", String(ids[slide]))]))
            }
            section.appendElement(sldIdLst)
            sections.append(section)
        }
        // Rebuild through the shared helper rather than clearing `children`,
        // so a comment or processing instruction in the section list survives
        // being re-sectioned.
        list.replaceChildElements(with: sections)
        presentationPart.markDirty()
    }

    /// Current section boundaries (name, first-slide-index), derived from the
    /// stored section list.
    func boundaries() throws -> [(name: String, startSlide: Int)] {
        let ids = try slideIds()
        let indexOf = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return elements.map { section in
            let name = section[attribute: "name"] ?? ""
            let firstId = section.firstChild(named: "p14:sldIdLst")?.children(named: "p14:sldId")
                .first?[attribute: "id"].flatMap { Int($0) }
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
        let section = XML.Element("p14:section", attributes: [
            ("name", name), ("id", SectionGUID.make(name: name, index: startIndex, avoiding: used)),
        ])
        let list = XML.Element("p14:sldIdLst")
        let originalEntries = owning.firstChild(named: "p14:sldIdLst")?.children(named: "p14:sldId") ?? []
        for id in members.dropFirst(split) {
            list.appendElement(originalEntries.first { $0[attribute: "id"] == String(id) }
                ?? XML.Element("p14:sldId", attributes: [("id", String(id))]))
        }
        section.appendElement(list)
        let sectionList = try sectionListElement(creatingIfMissing: false)!
        var sections = current.sections
        sections.insert(section, at: owningIndex + 1)
        SectionMembershipPlan(updates: [(owning, Array(members.prefix(split)))], presentation: presentationPart, membersFrom: current.sections).commit()
        Self.replaceKnownChildren(in: sectionList, named: "p14:section", with: sections)
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
        let ids = ((try? presentationPart.dom().firstChild(named: "p:sldIdLst")?.children(named: "p:sldId")) ?? nil)?
            .compactMap { $0[attribute: "id"].flatMap { Int($0) } } ?? []
        let indexOf = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return (element.firstChild(named: "p14:sldIdLst")?.children(named: "p14:sldId") ?? [])
            .compactMap { $0[attribute: "id"].flatMap { Int($0) } }
            .compactMap { indexOf[$0] }
    }

    public var slideCount: Int {
        element.firstChild(named: "p14:sldIdLst")?.children(named: "p14:sldId").count ?? 0
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
    private let membersByID: [Int: (element: XML.Element, section: XML.Element, namespaces: [(name: String, value: String)])]

    init(updates: [(section: XML.Element, ids: [Int])], presentation: Part,
         membersFrom sections: [XML.Element]) {
        self.updates = updates
        self.presentation = presentation
        var byID: [Int: (element: XML.Element, section: XML.Element, namespaces: [(name: String, value: String)])] = [:]
        for section in sections {
            guard let list = section.firstChild(named: "p14:sldIdLst") else { continue }
            let namespaces = (section.attributes + list.attributes).filter { $0.name == "xmlns" || $0.name.hasPrefix("xmlns:") }
            for entry in list.children(named: "p14:sldId") {
                if let id = entry[attribute: "id"].flatMap(Int.init) { byID[id] = (entry, section, namespaces) }
            }
        }
        membersByID = byID
    }

    func commit() {
        for (section, ids) in updates {
            let list = section.getOrAddChild("p14:sldIdLst", beforeAnyOf: ["p14:extLst"])
            let members = ids.map { id -> XML.Element in
                guard let source = membersByID[id] else { return XML.Element("p14:sldId", attributes: [("id", String(id))]) }
                if source.section !== section {
                    // A moved member may inherit extension namespace bindings
                    // from its old section/list. Make them local before transfer.
                    for namespace in source.namespaces where source.element[attribute: namespace.name] == nil {
                        source.element[attribute: namespace.name] = namespace.value
                    }
                }
                return source.element
            }
            Sections.replaceKnownChildren(in: list, named: "p14:sldId", with: members)
        }
        if !updates.isEmpty { presentation.markDirty() }
    }
}

extension Sections {
    struct Membership {
        let sections: [XML.Element]
        let liveIDs: [Int]
        let owner: [Int: Int]
    }

    /// Sectionless decks remain sectionless. Existing sections must partition
    /// the live slides; malformed references are refused before any mutation.
    func membership() throws -> Membership? {
        guard let list = try sectionListElement(creatingIfMissing: false) else { return nil }
        let sections = list.children(named: "p14:section")
        guard !sections.isEmpty else { return nil }
        let liveIDs = try slideIds()
        guard Set(liveIDs).count == liveIDs.count else {
            throw RostrumError.packageInvalid("duplicate slide IDs prevent section maintenance")
        }
        let live = Set(liveIDs)
        var owner: [Int: Int] = [:]
        var ordered: [Int] = []
        for (index, section) in sections.enumerated() {
            for entry in section.firstChild(named: "p14:sldIdLst")?.children(named: "p14:sldId") ?? [] {
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
        return Membership(sections: sections, liveIDs: liveIDs, owner: owner)
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
        return SectionMembershipPlan(updates: updates, presentation: presentationPart, membersFrom: current.sections)
    }

    /// Preserve foreign elements, comments and instructions while replacing
    /// only the named vocabulary, reusing existing element slots where possible.
    static func replaceKnownChildren(in parent: XML.Element, named name: String, with elements: [XML.Element]) {
        var index = 0
        var children: [XML.Node] = []
        for child in parent.children {
            if case .element(let element) = child, element.name == name {
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
            SectionMembershipPlan(updates: [(current.sections[recipient], ids)], presentation: presentationPart, membersFrom: current.sections).commit()
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
              let slides = try presentationPart.dom().firstChild(named: "p:sldIdLst") else {
            throw RostrumError.packageInvalid("section move index out of range")
        }
        var sections = current.sections
        let section = sections.remove(at: from)
        sections.insert(section, at: to)
        let ids = sections.flatMap { section in
            section.firstChild(named: "p14:sldIdLst")?.children(named: "p14:sldId")
                .compactMap { $0[attribute: "id"].flatMap(Int.init) } ?? []
        }
        let entries = slides.childElements
        var byID: [Int: XML.Element] = [:]
        for entry in entries {
            if let id = entry[attribute: "id"].flatMap(Int.init) { byID[id] = entry }
        }
        let reordered = try ids.map { id in
            guard let entry = byID[id] else { throw RostrumError.packageInvalid("section slide cannot be resolved") }
            return entry
        }
        Self.replaceKnownChildren(in: list, named: "p14:section", with: sections)
        slides.replaceChildElements(with: reordered)
        presentationPart.markDirty()
    }
}
