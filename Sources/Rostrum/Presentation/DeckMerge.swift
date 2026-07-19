import Foundation

/// Copies a slide's entire reachable part graph from one package into another.
///
/// The trick that makes this lossless and cheap: OPC relationship ids are
/// scoped per part, so a copied part keeps its original rIds and only its
/// rel *targets* are retargeted to the renamed/deduped destination parts.
/// The copied blob is therefore byte-identical to the source — Rostrum's
/// pristine-until-mutated model re-emits it verbatim. Only pre-existing
/// destination parts (the presentation, the notes master) get fresh rIds.
final class SlideCopier {
    let source: OPCPackage
    let dest: OPCPackage
    let destPresentation: Part
    /// source part URI → destination part URI (so shared parts copy once).
    private var map: [PackURI: PackURI] = [:]
    /// Destination URIs of newly-copied slide masters (need sldMasterId wiring).
    private(set) var newMasters: [PackURI] = []
    private var destNotesMaster: PackURI?
    /// Running allocator for the shared sldMasterId/sldLayoutId id namespace
    /// (2147483648+), which must be globally unique across the presentation.
    private var _nextBigId: Int?

    /// Extensions whose content type rides an extension-level Default (never an
    /// Override). XML parts are NOT here — slides/layouts/masters/charts/themes
    /// carry specific content types and need per-part Overrides.
    private static let defaultExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "xlsx", "fntdata"]

    init(source: OPCPackage, dest: OPCPackage, destPresentation: Part) {
        self.source = source
        self.dest = dest
        self.destPresentation = destPresentation
    }

    /// Copy `sourceURI` (and everything it references) into `dest`, returning
    /// its destination URI.
    func copy(_ sourceURI: PackURI) throws -> PackURI {
        if let existing = map[sourceURI] { return existing }
        let sourcePart = try source.part(at: sourceURI)
        // A source part whose DOM was mutated carries a stale blob until
        // flushed; copy the current bytes, not the pre-edit ones.
        sourcePart.flushIfDirty()

        // Notes/handout masters are package singletons — never duplicate.
        if sourcePart.contentType == ContentType.notesMaster {
            let nm = try ensureDestNotesMaster()
            map[sourceURI] = nm
            return nm
        }

        // Media dedups by content: reuse an identical image already in dest.
        // Iterate in sorted URI order — dest.parts is a Dictionary with
        // per-process-random iteration, so an unsorted scan could pick a
        // different duplicate each run and break byte-identical output when the
        // destination already holds two same-content images.
        if sourceURI.value.hasPrefix("/ppt/media/") {
            let mediaURIs = dest.parts.keys
                .filter { $0.value.hasPrefix("/ppt/media/") }
                .sorted { $0.value < $1.value }
            for uri in mediaURIs where dest.parts[uri]!.blob == sourcePart.blob {
                map[sourceURI] = uri
                return uri
            }
        }

        let destURI = freshName(like: sourceURI)
        map[sourceURI] = destURI   // record before recursing (master↔layout cycles)

        let destPart = dest.addPart(uri: destURI, contentType: sourcePart.contentType,
                                    blob: sourcePart.blob)
        registerContentType(destURI, sourcePart.contentType)

        // A copied master carries the source's sldLayoutId ids verbatim, which
        // collide with the destination's — renumber them into fresh unique ids.
        if sourcePart.contentType == ContentType.slideMaster,
           let idLst = try? destPart.dom().firstChild(named: "p:sldLayoutIdLst") {
            for entry in idLst.children(named: "p:sldLayoutId") {
                entry[attribute: "id"] = String(allocBigId())
            }
            destPart.markDirty()
        }

        for rel in sourcePart.rels.items {
            if rel.isExternal {
                destPart.rels.add(rId: rel.rId, type: rel.type, target: rel.target, isExternal: true)
            } else {
                let targetSource = PackURI.resolve(target: rel.target, relativeTo: sourceURI.baseURI)
                let targetDest = try copy(targetSource)
                destPart.rels.add(rId: rel.rId, type: rel.type,
                                  target: destURI.relativeReference(to: targetDest))
            }
        }

        if sourcePart.contentType == ContentType.slideMaster { newMasters.append(destURI) }
        return destURI
    }

    /// Allocate a fresh id in the sldMasterId/sldLayoutId namespace, unique
    /// across every master, layout, and the presentation's master list.
    func allocBigId() -> Int {
        if _nextBigId == nil {
            var maxId = 2_147_483_647
            if let pres = try? destPresentation.dom(),
               let list = pres.firstChild(named: "p:sldMasterIdLst") {
                for e in list.childElements { maxId = Swift.max(maxId, Int(e[attribute: "id"] ?? "") ?? 0) }
            }
            for (uri, part) in dest.parts where uri.value.hasPrefix("/ppt/slideMasters/") {
                if let list = try? part.dom().firstChild(named: "p:sldLayoutIdLst") {
                    for e in list.childElements { maxId = Swift.max(maxId, Int(e[attribute: "id"] ?? "") ?? 0) }
                }
            }
            _nextBigId = maxId + 1
        }
        defer { _nextBigId! += 1 }
        return _nextBigId!
    }

    // MARK: - Naming & content types

    /// A collision-free destination URI in the same directory, reusing the
    /// source's `<prefix><N>.<ext>` shape.
    private func freshName(like source: PackURI) -> PackURI {
        let dir = source.baseURI == "/" ? "" : source.baseURI
        let name = source.filename
        // Split "slide12.xml" → prefix "slide", ext "xml".
        let ext = source.ext
        var base = name
        if !ext.isEmpty { base = String(name.dropLast(ext.count + 1)) }
        let prefix = String(base.prefix { !$0.isNumber })
        let extPart = ext.isEmpty ? "" : ".\(ext)"
        var n = 1
        while dest.parts[PackURI("\(dir)/\(prefix)\(n)\(extPart)")] != nil { n += 1 }
        return PackURI("\(dir)/\(prefix)\(n)\(extPart)")
    }

    private func registerContentType(_ uri: PackURI, _ contentType: String) {
        // addPart already set an Override; extension-Default-covered parts use
        // the Default instead (and images/xlsx/fntdata must not carry Overrides).
        if Self.defaultExtensions.contains(uri.ext) {
            dest.contentTypes.removeOverride(partName: uri)
            switch uri.ext {
            case "png": dest.contentTypes.setDefault(extension: "png", contentType: ContentType.png)
            case "jpg", "jpeg": dest.contentTypes.setDefault(extension: uri.ext, contentType: ContentType.jpeg)
            case "gif": dest.contentTypes.setDefault(extension: "gif", contentType: ContentType.gif)
            case "xlsx": dest.contentTypes.setDefault(extension: "xlsx", contentType: ContentType.xlsx)
            case "fntdata": dest.contentTypes.setDefault(extension: "fntdata", contentType: "application/x-fontdata")
            default: break
            }
        } else {
            dest.contentTypes.setOverride(partName: uri, contentType: contentType)
        }
    }

    // MARK: - Notes-master singleton

    private func ensureDestNotesMaster() throws -> PackURI {
        if let cached = destNotesMaster { return cached }
        let uri = PackURI("/ppt/notesMasters/notesMaster1.xml")
        if let existing = dest.parts[uri] {
            destNotesMaster = existing.uri
            return existing.uri
        }
        // Create one (mirrors Slide.ensureNotesMaster): master + own theme +
        // notesMasterIdLst entry.
        let master = dest.addPart(uri: uri, contentType: ContentType.notesMaster,
                                  blob: Data(Slide.notesMasterXML.utf8))
        var themeN = 1
        while dest.parts[PackURI("/ppt/theme/theme\(themeN).xml")] != nil { themeN += 1 }
        let themeURI = PackURI("/ppt/theme/theme\(themeN).xml")
        dest.addPart(uri: themeURI, contentType: ContentType.theme, blob: Data(MinimalTemplate.themeXML.utf8))
        master.rels.add(type: RelType.theme, target: master.uri.relativeReference(to: themeURI))
        let rId = destPresentation.rels.add(type: RelType.notesMaster,
                                            target: destPresentation.uri.relativeReference(to: uri))
        let dom = try destPresentation.dom()
        let list = dom.getOrAddChild("p:notesMasterIdLst",
            beforeAnyOf: ["p:handoutMasterIdLst", "p:sldIdLst", "p:sldSz", "p:notesSz"])
        list.appendElement(XML.Element("p:notesMasterId", attributes: [("r:id", rId)]))
        destPresentation.markDirty()
        destNotesMaster = uri
        return uri
    }
}

extension Slides {
    /// Import a deep copy of `source.slides[index]` into this deck, bringing
    /// its whole reachable graph — images (deduped by content), charts and
    /// their workbooks, its slide layout + master family + theme, and notes.
    /// `insertAt` positions it in the slide order (nil appends).
    @discardableResult
    public func `import`(from source: Presentation, at index: Int, insertAt: Int? = nil) throws -> Slide {
        let sourceSlide = try source.slides.slide(at: index)
        let copier = SlideCopier(source: source.package, dest: destPackage,
                                 destPresentation: destPresentationPart)

        let newSlideURI = try copier.copy(sourceSlide.part.uri)

        // Register any imported masters in this deck's sldMasterIdLst.
        try wireNewMasters(copier.newMasters, copier)

        // Wire the new slide into the presentation (a pre-existing part → fresh rId + sldId).
        let rId = destPresentationPart.rels.add(
            type: RelType.slide, target: destPresentationPart.uri.relativeReference(to: newSlideURI))
        let sldIdLst = try destSldIdLst()
        let entry = XML.Element("p:sldId", attributes: [("id", String(nextSldId())), ("r:id", rId)])
        if let insertAt, insertAt < sldIdLst.childElements.count {
            var entries = sldIdLst.childElements
            entries.insert(entry, at: insertAt)
            sldIdLst.replaceChildElements(with: entries)
        } else {
            sldIdLst.appendElement(entry)
        }
        destPresentationPart.markDirty()
        return Slide(part: try destPackage.part(at: newSlideURI), package: destPackage)
    }

    /// Import a range of slides (or all) from `source`, sharing one copy pass
    /// so masters/themes/images referenced by several slides copy exactly once.
    @discardableResult
    public func importAll(from source: Presentation, at indices: Range<Int>? = nil) throws -> [Slide] {
        let range = indices ?? 0..<source.slides.count
        let copier = SlideCopier(source: source.package, dest: destPackage,
                                 destPresentation: destPresentationPart)
        var result: [Slide] = []
        for index in range {
            let sourceSlide = try source.slides.slide(at: index)
            let newSlideURI = try copier.copy(sourceSlide.part.uri)
            try wireNewMasters(copier.newMasters, copier)
            let rId = destPresentationPart.rels.add(
                type: RelType.slide, target: destPresentationPart.uri.relativeReference(to: newSlideURI))
            try destSldIdLst().appendElement(
                XML.Element("p:sldId", attributes: [("id", String(nextSldId())), ("r:id", rId)]))
            result.append(Slide(part: try destPackage.part(at: newSlideURI), package: destPackage))
        }
        destPresentationPart.markDirty()
        return result
    }

    // MARK: - Presentation wiring helpers

    private var destPackage: OPCPackage { package }
    private var destPresentationPart: Part { presentationPart }

    private func destSldIdLst() throws -> XML.Element {
        try destPresentationPart.dom().getOrAddChild("p:sldIdLst", beforeAnyOf: ["p:sldSz", "p:notesSz"])
    }

    private func nextSldId() -> Int {
        let used = ((try? destSldIdLst())?.childElements.compactMap { $0[attribute: "id"].flatMap { Int($0) } }) ?? []
        return Swift.max(255, used.max() ?? 255) + 1
    }

    private func wireNewMasters(_ masters: [PackURI], _ copier: SlideCopier) throws {
        guard !masters.isEmpty else { return }
        let dom = try destPresentationPart.dom()
        let list = dom.getOrAddChild("p:sldMasterIdLst",
            beforeAnyOf: ["p:notesMasterIdLst", "p:handoutMasterIdLst", "p:sldIdLst", "p:sldSz", "p:notesSz"])
        for masterURI in masters {
            // Skip if already wired (idempotent across importAll iterations).
            let already = list.childElements.contains { entry in
                guard let rId = entry[attribute: "r:id"],
                      let rel = destPresentationPart.rels.relationship(withId: rId) else { return false }
                return PackURI.resolve(target: rel.target, relativeTo: destPresentationPart.uri.baseURI) == masterURI
            }
            if already { continue }
            let rId = destPresentationPart.rels.add(
                type: RelType.slideMaster, target: destPresentationPart.uri.relativeReference(to: masterURI))
            list.appendElement(XML.Element("p:sldMasterId",
                attributes: [("id", String(copier.allocBigId())), ("r:id", rId)]))
        }
        destPresentationPart.markDirty()
    }
}
