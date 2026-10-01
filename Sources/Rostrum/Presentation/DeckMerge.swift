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
    private var stagedParts: [PackURI: Part] = [:]
    private var authorImport: AnnotationAuthorImport?
    private var legacyAuthorImport: LegacyAnnotationAuthorImport?
    private var tableStyleImport: TableStyleImport?
    private var reservedStyleURIs: Set<PackURI> = []
    private var newNotesMaster: PackURI?
    private var sourceNotesSize: XML.Element?
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
            let nm = try ensureDestNotesMaster(from: sourcePart)
            map[sourceURI] = nm
            return nm
        }

        // Media dedups by content: reuse an identical image already in dest.
        // Iterate in sorted URI order — dest.parts is a Dictionary with
        // per-process-random iteration, so an unsorted scan could pick a
        // different duplicate each run and break byte-identical output when the
        // destination already holds two same-content images.
        if sourceURI.value.hasPrefix("/ppt/media/"), let existing = dest.matchingMedia(for: sourcePart.blob) {
            map[sourceURI] = existing.uri
            return existing.uri
        }

        let destURI = freshName(like: sourceURI)
        map[sourceURI] = destURI   // record before recursing (master↔layout cycles)

        let destPart = Part(uri: destURI, contentType: sourcePart.contentType, blob: sourcePart.blob)
        stagedParts[destURI] = destPart

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

        if [ContentType.slide, ContentType.slideLayout, ContentType.slideMaster].contains(sourcePart.contentType) {
            try importTableStyles(in: destPart)
        }
        if sourcePart.contentType == ContentType.slideMaster { newMasters.append(destURI) }
        return destURI
    }

    /// Styles live on the presentation, outside a slide's relationship graph.
    /// Remap references on detached copied slides/layouts/masters before commit.
    private func importTableStyles(in part: Part) throws {
        var tables: [(XML.Element, [String: String])] = []
        try TableStyleXML.walk(part.dom()) { node, scope in
            if TableStyleXML.isDrawing(node, "tbl", namespaces: scope) { tables.append((node, scope)) }
        }
        guard !tables.isEmpty else { return }
        let presentation = try source.mainDocumentPart()
        guard let rel = presentation.rels.first(ofType: RelType.tableStyles) else { return }
        guard !rel.isExternal else { throw RostrumError.packageInvalid("source table styles must be internal") }
        let sourceStyles = try presentation.related(by: RelType.tableStyles, in: source)
        let root = try sourceStyles.dom()
        for (table, scope) in tables {
            let existingProperties = table.childElements.first { TableStyleXML.isDrawing($0, "tblPr", namespaces: scope) }
            let properties = existingProperties ?? XML.Element("a:tblPr", attributes: [("xmlns:a", TableStyleXML.drawing)])
            let propertyScope = TableStyleXML.bindings(properties, inheriting: scope)
            if properties.childElements.contains(where: { TableStyleXML.isDrawing($0, "tableStyle", namespaces: propertyScope) }) { continue }
            let reference = properties.childElements.first { TableStyleXML.isDrawing($0, "tableStyleId", namespaces: propertyScope) }
            guard let id = reference?.textContent ?? root[attribute: "def"] else { continue }
            let matches = TableStyleXML.definitions(in: root).filter { $0[attribute: "styleId"]?.lowercased() == id.lowercased() }
            guard matches.count <= 1 else { throw RostrumError.packageInvalid("ambiguous source table style ID") }
            // An implicit native default still needs an explicit reference in
            // the destination, even when no embedded definition is available.
            let mapped = try matches.first.map { try importTableStyle($0, from: sourceStyles) } ?? id
            let target = reference ?? XML.Element("a:tableStyleId", attributes: [("xmlns:a", TableStyleXML.drawing)])
            var wroteText = false
            target.children = target.children.compactMap { node in
                guard case .text = node else { return node }
                guard !wroteText else { return nil }
                wroteText = true
                return .text(mapped)
            }
            if !wroteText { target.children.insert(.text(mapped), at: 0) }
            if existingProperties == nil {
                table.insertChild(properties, beforeAnyOf: table.childElements.filter {
                    TableStyleXML.isDrawing($0, "tblGrid", namespaces: scope) || TableStyleXML.isDrawing($0, "tr", namespaces: scope)
                }.map(\.name))
            }
            if reference == nil { properties.insertChild(target, beforeAnyOf: properties.childElements.filter { TableStyleXML.isDrawing($0, "extLst", namespaces: propertyScope) }.map(\.name)) }
            part.markDirty()
        }
    }

    func importTableStyle(_ definition: XML.Element, from owner: Part) throws -> String {
        if tableStyleImport == nil {
            tableStyleImport = try TableStyleImport(source: source, destination: dest, presentation: destPresentation) { uri in
                let reserved = self.freshName(like: uri)
                self.reservedStyleURIs.insert(reserved)
                return reserved
            }
        }
        return try tableStyleImport!.transfer(definition, from: owner) { try self.copy($0) }
    }

    /// Allocate a fresh id in the sldMasterId/sldLayoutId namespace, unique
    /// across every master, layout, and the presentation's master list.
    func allocBigId() -> Int {
        if _nextBigId == nil {
            // This namespace starts above ST_SlideId's ceiling and runs to
            // UINT_MAX. Ids are bounded on the way in: a file-supplied
            // 9223372036854775807 would make the `+ 1` below an overflow trap.
            let namespace = 2_147_483_647...Int(UInt32.max)
            var maxId = namespace.lowerBound
            if let pres = try? destPresentation.dom(),
               let list = pres.firstChild(named: "p:sldMasterIdLst") {
                for e in list.childElements {
                    maxId = Swift.max(maxId, e.boundedInt("id", in: namespace) ?? 0)
                }
            }
            for (uri, part) in dest.parts where uri.value.hasPrefix("/ppt/slideMasters/") {
                if let list = try? part.dom().firstChild(named: "p:sldLayoutIdLst") {
                    for e in list.childElements {
                        maxId = Swift.max(maxId, e.boundedInt("id", in: namespace) ?? 0)
                    }
                }
            }
            // Saturate rather than trap: this allocator has no throwing path,
            // and a deck that has genuinely exhausted the namespace is beyond
            // anything a merge can repair.
            _nextBigId = Swift.min(maxId, namespace.upperBound - 1) + 1
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
        while dest.parts[PackURI("\(dir)/\(prefix)\(n)\(extPart)")] != nil
            || stagedParts[PackURI("\(dir)/\(prefix)\(n)\(extPart)")] != nil
            || reservedStyleURIs.contains(PackURI("\(dir)/\(prefix)\(n)\(extPart)")) { n += 1 }
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

    /// Annotation bodies can only be retargeted once the destination slide
    /// IDs have been allocated, while the copied parts are still detached.
    func importAnnotations(on slideURI: PackURI, slideID: Int) throws {
        guard let slide = stagedParts[slideURI] else { return }
        for rel in slide.rels.items where rel.type == ModernComments.commentsRelType || rel.type == LegacyComments.commentsRelType {
            guard !rel.isExternal else {
                throw RostrumError.packageInvalid("comment relationship must be internal")
            }
            let uri = PackURI.resolve(target: rel.target, relativeTo: slide.uri.baseURI)
            guard let comments = stagedParts[uri] else {
                throw RostrumError.packageInvalid("imported comment part is not staged")
            }
            if rel.type == LegacyComments.commentsRelType {
                if legacyAuthorImport == nil {
                    legacyAuthorImport = try LegacyAnnotationAuthorImport(source: source, dest: dest,
                                                                          presentation: destPresentation)
                }
                try legacyAuthorImport?.remapAuthors(in: comments)
                continue
            }
            if authorImport == nil {
                authorImport = try AnnotationAuthorImport(source: source, dest: dest,
                                                         presentation: destPresentation)
            }
            try authorImport?.remapAuthors(in: comments)
            var ids: Set<String> = []
            for part in Array(dest.parts.values) + Array(stagedParts.values)
                where part.contentType == ModernComments.commentsContentType {
                ModernComments.visit(in: try part.dom()) { element, ns, name in
                    if ns == ModernComments.ns, name == "cm" || name == "reply",
                       let id = element[attribute: "id"] { ids.insert(id.uppercased()) }
                }
            }
            try ModernComments.retargetCopy(comments, slideID: slideID, avoiding: &ids)
        }
    }

    /// Called only after every requested slide, annotation and presentation
    /// target has been validated. Installing the staged parts cannot throw.
    func commit() {
        for part in stagedParts.values.sorted(by: { $0.uri.value < $1.uri.value }) {
            part.flushIfDirty()
            let installed = dest.addPart(uri: part.uri, contentType: part.contentType, blob: part.blob)
            installed.rels.setItems(part.rels.items)
            registerContentType(part.uri, part.contentType)
        }
        tableStyleImport?.commit()
        authorImport?.commit()
        legacyAuthorImport?.commit()
        if let uri = newNotesMaster, let dom = try? destPresentation.dom() {
            if let size = sourceNotesSize {
                dom.removeChildren(named: "p:notesSz")
                dom.insertChild(size, beforeAnyOf: ["p:smartTags", "p:embeddedFontLst", "p:custShowLst", "p:photoAlbum", "p:custDataLst", "p:kinsoku", "p:defaultTextStyle", "p:modifyVerifier", "p:extLst"])
            }
            let rId = destPresentation.rels.add(type: RelType.notesMaster,
                target: destPresentation.uri.relativeReference(to: uri))
            let list = dom.getOrAddChild("p:notesMasterIdLst",
                beforeAnyOf: ["p:handoutMasterIdLst", "p:sldIdLst", "p:sldSz", "p:notesSz"])
            list.appendElement(XML.Element("p:notesMasterId", attributes: [("r:id", rId)]))
            destPresentation.markDirty()
        }
    }

    // MARK: - Notes-master singleton

    /// Notes masters are presentation singletons. Preserve the first source
    /// master and its actual dependency graph; reuse only an exact compatible
    /// appearance. Conflicts are rejected while all imports are still staged.
    private func ensureDestNotesMaster(from sourceMaster: Part) throws -> PackURI {
        let sourcePresentation = try source.mainDocumentPart()
        guard let size = try sourcePresentation.dom().firstChild(named: "p:notesSz") else {
            throw RostrumError.packageInvalid("source notes-page dimensions are missing")
        }
        let destinationMaster: Part?
        if let cached = destNotesMaster {
            destinationMaster = dest.parts[cached] ?? stagedParts[cached]
        } else if let rel = destPresentation.rels.first(ofType: RelType.notesMaster) {
            guard !rel.isExternal else { throw RostrumError.packageInvalid("notes master must be internal") }
            destinationMaster = try dest.part(at: PackURI.resolve(target: rel.target, relativeTo: destPresentation.uri.baseURI))
        } else { destinationMaster = nil }
        if let existing = destinationMaster {
            let destinationSize = try sourceNotesSize ?? destPresentation.dom().firstChild(named: "p:notesSz")
            guard destinationSize?.attributes.elementsEqual(size.attributes, by: { $0.name == $1.name && $0.value == $1.value }) == true else {
                throw NotesImportError.incompatibleAppearance("notes-page dimensions conflict; import would change notes appearance")
            }
            var visited: Set<String> = []
            guard try notesGraphsMatch(sourceMaster, existing, visited: &visited) else {
                throw NotesImportError.incompatibleAppearance("notes masters or their themes/images conflict; appearance reconciliation is unsupported")
            }
            destNotesMaster = existing.uri
            return existing.uri
        }
        let uri = freshName(like: sourceMaster.uri)
        map[sourceMaster.uri] = uri  // cycle guard before copying dependencies
        let master = Part(uri: uri, contentType: sourceMaster.contentType, blob: sourceMaster.blob)
        _ = try master.dom()
        stagedParts[uri] = master
        for rel in sourceMaster.rels.items {
            if rel.isExternal {
                master.rels.add(rId: rel.rId, type: rel.type, target: rel.target, isExternal: true)
            } else {
                let target = PackURI.resolve(target: rel.target, relativeTo: sourceMaster.uri.baseURI)
                let copied = try copy(target)
                master.rels.add(rId: rel.rId, type: rel.type, target: uri.relativeReference(to: copied))
            }
        }
        newNotesMaster = uri
        sourceNotesSize = size.deepCopy()
        destNotesMaster = uri
        return uri
    }

    /// Compare actual payloads and corresponding relationship graphs, allowing
    /// different part filenames. Unknown master/theme/image data must match,
    /// otherwise reuse would silently change inherited notes-page appearance.
    private func notesGraphsMatch(_ sourcePart: Part, _ destinationPart: Part,
                                  visited: inout Set<String>) throws -> Bool {
        let pair = "\(sourcePart.uri.value)\u{1}\(destinationPart.uri.value)"
        guard visited.insert(pair).inserted else { return true }
        sourcePart.flushIfDirty()
        destinationPart.flushIfDirty()
        guard sourcePart.contentType == destinationPart.contentType,
              sourcePart.blob == destinationPart.blob,
              sourcePart.rels.items.count == destinationPart.rels.items.count else { return false }
        for rel in sourcePart.rels.items {
            guard let other = destinationPart.rels.relationship(withId: rel.rId),
                  rel.type == other.type, rel.isExternal == other.isExternal else { return false }
            if rel.isExternal {
                if rel.target != other.target { return false }
            } else {
                let sourceURI = PackURI.resolve(target: rel.target, relativeTo: sourcePart.uri.baseURI)
                let destURI = PackURI.resolve(target: other.target, relativeTo: destinationPart.uri.baseURI)
                let target = try source.part(at: sourceURI)
                guard let otherTarget = dest.parts[destURI] ?? stagedParts[destURI] else {
                    throw RostrumError.partMissing(destURI.value)
                }
                if try !notesGraphsMatch(target, otherTarget, visited: &visited) { return false }
            }
        }
        return true
    }

}

extension Slides {
    /// Import a deep copy of `source.slides[index]` into this deck, bringing
    /// its whole reachable graph — images (deduped by content), charts and
    /// their workbooks, its slide layout + master family + theme, and notes.
    /// `insertAt` positions it in the slide order (nil appends).
    @discardableResult
    public func `import`(from source: Presentation, at index: Int, insertAt: Int? = nil) throws -> Slide {
        let count = self.count
        let position = insertAt ?? count
        guard position >= 0, position <= count else {
            throw RostrumError.packageInvalid("import insertion index \(position) out of range 0...\(count)")
        }
        let slides = try importSlides(from: source, indices: [index], insertAt: position)
        return slides[0]
    }

    /// Import a range of slides (or all) atomically, sharing one copy pass so
    /// masters/themes/images referenced by several slides copy exactly once.
    @discardableResult
    public func importAll(from source: Presentation, at indices: Range<Int>? = nil) throws -> [Slide] {
        let range = indices ?? 0..<source.slides.count
        guard range.lowerBound >= 0, range.upperBound <= source.slides.count else {
            throw RostrumError.packageInvalid("import range is outside source slides")
        }
        return try importSlides(from: source, indices: Array(range), insertAt: count)
    }

    private func importSlides(from source: Presentation, indices: [Int], insertAt: Int) throws -> [Slide] {
        guard !indices.isEmpty else { return [] }
        let sourceSlides = try indices.map { try source.slides.slide(at: $0) }
        let firstID = try nextSldId()
        guard indices.count - 1 <= OOXMLBounds.slideID.upperBound - firstID else {
            throw RostrumError.packageInvalid("not enough slide IDs remain for import")
        }
        let dom = try destPresentationPart.dom()
        let list = try destSldIdLst()
        let copier = SlideCopier(source: source.package, dest: destPackage,
                                 destPresentation: destPresentationPart)
        var copied: [(uri: PackURI, id: Int)] = []
        for (offset, sourceSlide) in sourceSlides.enumerated() {
            let uri = try copier.copy(sourceSlide.part.uri)
            let id = firstID + offset
            try copier.importAnnotations(on: uri, slideID: id)
            copied.append((uri, id))
        }
        var sectionOrder = list.childElements.compactMap { $0[attribute: "id"].flatMap(Int.init) }
        sectionOrder.insert(contentsOf: copied.map(\.id), at: insertAt)
        let sections = try Sections(package: package, presentationPart: presentationPart)
            .maintainSectionMembership(order: sectionOrder, insertedAt: insertAt,
                                      insertedIDs: copied.map(\.id))
        // The package graph and annotation author/anchor transforms are now
        // validated. No throwing operation follows the commit boundary.
        copier.commit()
        wireNewMasters(copier.newMasters, copier, in: dom)
        var entries = list.childElements
        for (offset, copy) in copied.enumerated() {
            let rId = destPresentationPart.rels.add(type: RelType.slide,
                target: destPresentationPart.uri.relativeReference(to: copy.uri))
            entries.insert(XML.Element("p:sldId", attributes: [
                ("id", String(copy.id)), ("r:id", rId),
            ]), at: insertAt + offset)
        }
        list.replaceChildElements(with: entries)
        sections?.commit()
        destPresentationPart.markDirty()
        return copied.compactMap { copy in
            destPackage.parts[copy.uri].map { Slide(part: $0, package: destPackage) }
        }
    }

    // MARK: - Presentation wiring helpers

    private var destPackage: OPCPackage { package }
    private var destPresentationPart: Part { presentationPart }

    private func destSldIdLst() throws -> XML.Element {
        try destPresentationPart.dom().getOrAddChild("p:sldIdLst", beforeAnyOf: ["p:sldSz", "p:notesSz"])
    }

    private func nextSldId() throws -> Int {
        let used = ((try? destSldIdLst())?.childElements
            .compactMap { $0.boundedInt("id", in: OOXMLBounds.slideID) }) ?? []
        let highest = Swift.max(255, used.max() ?? 255)
        guard highest < OOXMLBounds.slideID.upperBound else {
            throw RostrumError.packageInvalid(
                "slide ids reach the format's maximum; there is no id left to assign")
        }
        return highest + 1
    }

    private func wireNewMasters(_ masters: [PackURI], _ copier: SlideCopier, in dom: XML.Element) {
        guard !masters.isEmpty else { return }
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
