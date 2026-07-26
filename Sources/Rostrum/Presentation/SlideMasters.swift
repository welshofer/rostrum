import Foundation

/// A slide master: the terminus of the placeholder-inheritance chain, and the
/// owner of a set of layouts.
public final class SlideMaster {
    public let part: Part
    let package: OPCPackage

    init(part: Part, package: OPCPackage) {
        self.part = part
        self.package = package
    }

    /// The master's name (`p:cSld@name`), often empty in real decks.
    public var name: String {
        (try? part.dom())?.firstChild(named: "p:cSld")?[attribute: "name"] ?? ""
    }

    /// This master's layouts, in `p:sldLayoutIdLst` order.
    public var layouts: [SlideLayout] {
        guard let dom = try? part.dom(),
              let list = dom.firstChild(named: "p:sldLayoutIdLst") else { return [] }
        return list.childElements.compactMap { entry in
            guard let rId = entry[attribute: "r:id"],
                  let rel = part.rels.relationship(withId: rId),
                  let layoutPart = try? package.part(
                    at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI))
            else { return nil }
            return SlideLayout(part: layoutPart, package: package)
        }
    }

    /// The theme this master uses, when it has one.
    public var theme: Theme? {
        guard let rel = part.rels.first(ofType: RelType.theme),
              let themePart = try? package.part(
                at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI))
        else { return nil }
        return Theme(part: themePart, master: part)
    }
}

public extension Presentation {
    /// Every slide master, in `p:sldMasterIdLst` order.
    ///
    /// Decks built from a corporate template routinely carry several; before
    /// this existed only the first master's layouts were reachable, even
    /// though `slides.importAll(from:)` could already bring multi-master decks
    /// in.
    var slideMasters: [SlideMaster] {
        guard let dom = try? presentationPart.dom(),
              let list = dom.firstChild(named: "p:sldMasterIdLst") else { return [] }
        return list.childElements.compactMap { entry in
            guard let rId = entry[attribute: "r:id"],
                  let rel = presentationPart.rels.relationship(withId: rId),
                  let part = try? package.part(
                    at: PackURI.resolve(target: rel.target, relativeTo: presentationPart.uri.baseURI))
            else { return nil }
            return SlideMaster(part: part, package: package)
        }
    }

    /// Every layout in the deck, across every master — as opposed to
    /// `layouts`, which is the first master's only.
    var allLayouts: [SlideLayout] {
        slideMasters.flatMap(\.layouts)
    }
}

public extension SlideLayout {
    /// The master this layout belongs to.
    var master: SlideMaster? {
        guard let rel = part.rels.first(ofType: RelType.slideMaster),
              let masterPart = try? package.part(
                at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI))
        else { return nil }
        return SlideMaster(part: masterPart, package: package)
    }
}

public extension Slide {
    /// The layout this slide is based on.
    var layout: SlideLayout? {
        guard let rel = part.rels.first(ofType: RelType.slideLayout),
              let layoutPart = try? package.part(
                at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI))
        else { return nil }
        return SlideLayout(part: layoutPart, package: package)
    }

    /// The master behind this slide's layout.
    var master: SlideMaster? { layout?.master }
}
