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
        if let ext = dom.firstChild(named: "p:extLst")?.children(named: "p:ext")
            .first(where: { $0[attribute: "uri"] == SectionExt.uri }),
           let list = ext.firstChild(named: "p14:sectionLst") {
            return list
        }
        guard create else { return nil }
        let extLst = dom.getOrAddChild("p:extLst")                 // extLst is last in p:presentation
        let ext = XML.Element("p:ext", attributes: [("uri", SectionExt.uri)])
        let list = XML.Element("p14:sectionLst", attributes: [("xmlns:p14", SectionExt.ns)])
        ext.appendElement(list)
        extLst.appendElement(ext)
        presentationPart.markDirty()
        return list
    }

    private var elements: [XML.Element] {
        ((try? sectionListElement(creatingIfMissing: false)) ?? nil)?.children(named: "p14:section") ?? []
    }

    public var count: Int { elements.count }

    public subscript(index: Int) -> Section {
        Section(element: elements[index], package: package, presentationPart: presentationPart)
    }

    public func makeIterator() -> AnyIterator<Section> {
        var i = 0
        return AnyIterator { defer { i += 1 }; return i < self.count ? self[i] : nil }
    }

    /// Replace all sections with a full partition of the deck's current slides.
    /// Boundaries are (name, first-slide-index); the first MUST start at 0, and
    /// starts must strictly increase and be in range. This is the safest section
    /// primitive — call it after adding the slides.
    public func set(_ boundaries: [(name: String, startSlide: Int)]) throws {
        let ids = try slideIds()
        precondition(!boundaries.isEmpty, "need at least one section")
        precondition(boundaries.first!.startSlide == 0, "the first section must start at slide 0")
        precondition(!ids.isEmpty, "the deck has no slides to partition")
        for i in boundaries.indices {
            precondition(boundaries[i].startSlide >= 0 && boundaries[i].startSlide < ids.count,
                         "section startSlide \(boundaries[i].startSlide) out of range")
            if i > 0 {
                precondition(boundaries[i].startSlide > boundaries[i - 1].startSlide,
                             "section startSlides must strictly increase")
            }
        }
        let list = try sectionListElement(creatingIfMissing: true)!
        list.children = []
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
            list.appendElement(section)
        }
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
    /// that currently owns it. Builds on `set`.
    @discardableResult
    public func add(_ name: String, startingAtSlide startIndex: Int) throws -> Section {
        var bounds = try boundaries()
        bounds.removeAll { $0.startSlide == startIndex }
        bounds.append((name, startIndex))
        bounds.sort { $0.startSlide < $1.startSlide }
        if bounds.first?.startSlide != 0 { bounds.insert(("Default", 0), at: 0) }
        try set(bounds)
        let idx = try boundaries().firstIndex { $0.startSlide == startIndex } ?? 0
        return self[idx]
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
