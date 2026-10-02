import Foundation

/// An operation-local rendering view. Source parts, relationships and XML are
/// never modified: namespace canonicalization and inheritance happen on copies.
struct NotesPageRenderContext {
    let notes: Part
    let master: Part?
    let theme: Theme
    let thumbnail: String
    let problems: SlideRenderProblems
    private let ancestors: [String: XML.Element]

    init(presentation: Presentation, slide: Slide, index: Int, pixelWidth: Int) throws {
        let package = presentation.package
        guard let relationship = slide.part.rels.first(ofType: RelType.notesSlide), !relationship.isExternal else {
            throw RostrumError.packageInvalid("slide \(index + 1) has no internal notes page")
        }
        let source = try package.part(at: PackURI.resolve(target: relationship.target, relativeTo: slide.part.uri.baseURI))
        notes = try Self.renderCopy(source)
        guard try notes.dom().name == "p:notes", Slide.existingSpTree(of: notes) != nil else {
            throw RostrumError.packageInvalid("invalid notes-page root or shape tree")
        }
        var issues: [FidelityIssue] = []
        func issue(_ message: String, owner: Part = source, code: FidelityIssueCode = .unresolvedInheritance) {
            issues.append(FidelityIssue(code: code, impact: .approximation,
                location: FidelityLocation(slideIndex: index, partURI: owner.uri.description, path: "/p:notes"), message: message))
        }
        func related(_ part: Part, _ type: String) -> Part? {
            guard let rel = part.rels.first(ofType: type), !rel.isExternal else { return nil }
            return try? package.part(at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI))
        }
        let sourceMaster = related(source, RelType.notesMaster)
        master = sourceMaster.flatMap { source in
            guard let copy = try? Self.renderCopy(source), (try? copy.dom().name) == "p:notesMaster" else { return nil }
            return copy
        }
        if master == nil { issue("The notes master could not be resolved.") }
        if let master, (try? master.dom().firstChild(named: "p:hf")) != nil {
            issue("Notes-master header/footer visibility settings are not applied by this preview.", owner: sourceMaster ?? source)
        }
        if let sourceMaster {
            let presentationRoot = Self.canonical(try presentation.presentationPart.dom())
            let registered = presentationRoot.firstChild(named: "p:notesMasterIdLst")?.children(named: "p:notesMasterId").contains { entry in
                guard let id = entry[attribute: "r:id"], let rel = presentation.presentationPart.rels.relationship(withId: id),
                      !rel.isExternal, rel.type == RelType.notesMaster else { return false }
                return PackURI.resolve(target: rel.target, relativeTo: presentation.presentationPart.uri.baseURI) == sourceMaster.uri
            } ?? false
            if !registered { issue("The notes relationship selects a master not registered by the presentation; native notes-page placement may differ.") }
        }
        let themeSource = sourceMaster.flatMap { related($0, RelType.theme) }
        if themeSource == nil { issue("The notes theme could not be resolved; slide-theme fallback is approximate.") }
        let themePart = try Self.renderCopy(themeSource ?? slide.resolvedTheme.part)
        let colorMap = try notes.dom().firstChild(named: "p:clrMapOvr")?.firstChild(named: "a:overrideClrMapping")
        theme = Theme(part: themePart, master: master, colorMap: colorMap)
        var matches: [String: XML.Element] = [:], ambiguous: Set<String> = []
        for shape in master.flatMap({ Slide.existingSpTree(of: $0) })?.childElements ?? [] {
            if !["p:sp", "p:pic", "p:graphicFrame", "p:nvGrpSpPr", "p:grpSpPr", "p:grpSp", "p:cxnSp"].contains(shape.name),
               !["0", "false"].contains((try? notes.dom()[attribute: "showMasterSp"]) ?? "") {
                issue("Notes-master element \(shape.name) is not rendered.", owner: sourceMaster ?? source, code: .omittedShape)
            }
            guard let type = Self.placeholderType(shape) else { continue }
            if matches[type] != nil { ambiguous.insert(type) }
            matches[type] = shape
        }
        for type in ambiguous.sorted() {
            matches.removeValue(forKey: type)
            issue("Multiple notes-master placeholders have type \(type); ancestry is ambiguous.", owner: sourceMaster ?? source)
        }
        // Inherited resource references belong to the master. Retarget only
        // copies to fresh detached notes relationships before merging properties.
        if let master {
            for key in matches.keys.sorted() { matches[key] = Self.retarget(matches[key]!, from: master, to: notes) }
        }
        ancestors = matches
        var seen: Set<String> = [], imageNeeded = false
        for shape in Slide.existingSpTree(of: notes)?.childElements ?? [] {
            if let type = Self.placeholderType(shape) {
                if !seen.insert(type).inserted { issue("Multiple notes-page placeholders have type \(type); ancestry is ambiguous.") }
                if shape.name != "p:sp" { issue("Notes inheritance on \(shape.name) placeholders is not supported.") }
                if !["body", "sldImg"].contains(type) {
                    issue("Notes placeholder type \(type) needs header/footer or other placeholder semantics not supported by this preview.", code: .omittedShape)
                }
                if type == "sldImg", !Self.suppressesSlideImage(Self.merged(shape.firstChild(named: "p:spPr"), matches[type]?.firstChild(named: "p:spPr"))) {
                    imageNeeded = true
                }
                let local = shape.firstChild(named: "p:spPr")?.firstChild(named: "a:xfrm")
                let inherited = matches[type]?.firstChild(named: "p:spPr")?.firstChild(named: "a:xfrm")
                let effective = Self.merged(local, inherited)
                let offset = effective?.firstChild(named: "a:off"), extent = effective?.firstChild(named: "a:ext")
                if offset?.coordinate("x") == nil || offset?.coordinate("y") == nil
                    || (extent?.coordinate("cx") ?? 0) <= 0 || (extent?.coordinate("cy") ?? 0) <= 0 {
                    issue("Notes placeholder \(type) has no complete local or inherited position and size.")
                }
            }
            if !["p:sp", "p:pic", "p:graphicFrame", "p:nvGrpSpPr", "p:grpSpPr", "p:grpSp", "p:cxnSp"].contains(shape.name) {
                issue("Notes-page element \(shape.name) is not rendered.", code: .omittedShape)
            }
        }
        // Image documents isolate CSS font aliases and SVG definition IDs from
        // the outer notes document, even when slide and notes themes differ.
        var thumbnailProblems = SlideRenderProblems()
        if imageNeeded {
            let slideResult = try presentation.renderSVGReportingProblems(slideAt: index, pixelWidth: pixelWidth)
            thumbnail = "data:image/svg+xml;base64," + Data(slideResult.svg.utf8).base64EncodedString()
            thumbnailProblems = slideResult.problems
        } else { thumbnail = "" }
        issues += thumbnailProblems.fidelityIssues
        problems = SlideRenderProblems(layoutUnresolved: thumbnailProblems.layoutUnresolved,
            masterUnresolved: master == nil || thumbnailProblems.masterUnresolved, fidelityIssues: issues)
    }

    /// The pinned native notes fixtures established that Office suppresses the
    /// slide image when its effective placeholder has neither fill nor line.
    static func suppressesSlideImage(_ properties: XML.Element?) -> Bool {
        properties?.firstChild(named: "a:noFill") != nil
            && properties?.firstChild(named: "a:ln")?.firstChild(named: "a:noFill") != nil
    }

    static func placeholderType(_ shape: XML.Element) -> String? {
        Placeholders.phElement(of: shape).map { $0[attribute: "type"] ?? "obj" }
    }

    func effectiveShape(_ shape: XML.Element) -> XML.Element {
        guard let type = Self.placeholderType(shape), let ancestor = ancestors[type] else { return shape }
        let copy = shape.deepCopy()
        if let properties = Self.merged(copy.firstChild(named: "p:spPr"), ancestor.firstChild(named: "p:spPr")) {
            copy.removeChildren(named: "p:spPr"); copy.appendElement(properties)
        }
        if copy.firstChild(named: "p:style") == nil, let style = ancestor.firstChild(named: "p:style") { copy.appendElement(style.deepCopy()) }
        if let body = copy.firstChild(named: "p:txBody"),
           let properties = Self.merged(body.firstChild(named: "a:bodyPr"), ancestor.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr")) {
            body.removeChildren(named: "a:bodyPr"); body.insertChild(properties, beforeAnyOf: ["a:lstStyle", "a:p"])
        }
        return copy
    }

    func styles(for shape: XML.Element) -> [XML.Element] {
        guard let type = Self.placeholderType(shape) else { return [] }
        return [ancestors[type]?.firstChild(named: "p:txBody")?.firstChild(named: "a:lstStyle"),
                try? master?.dom().firstChild(named: "p:notesStyle")].compactMap { $0 }
    }

    /// Merge property containers at the attribute/child level, keeping explicit
    /// local values (including noFill/noLine and partial transforms).
    private static func merged(_ local: XML.Element?, _ ancestor: XML.Element?) -> XML.Element? {
        guard let ancestor else { return local?.deepCopy() }
        guard let local else { return ancestor.deepCopy() }
        let copy = local.deepCopy()
        for attribute in ancestor.attributes where copy[attribute: attribute.name] == nil { copy[attribute: attribute.name] = attribute.value }
        let alternatives = [["a:noFill", "a:solidFill", "a:gradFill", "a:blipFill", "a:pattFill", "a:grpFill"],
                            ["a:prstGeom", "a:custGeom"], ["a:effectLst", "a:effectDag"], ["a:noAutofit", "a:normAutofit", "a:spAutoFit"]]
        for inherited in ancestor.childElements {
            if let own = copy.firstChild(named: inherited.name) {
                if ["a:xfrm", "a:off", "a:ext", "a:ln"].contains(inherited.name), let value = merged(own, inherited) {
                    copy.removeChildren(named: inherited.name); copy.appendElement(value)
                }
            } else if !alternatives.contains(where: { $0.contains(inherited.name) && $0.contains(where: { copy.firstChild(named: $0) != nil }) }) {
                copy.appendElement(inherited.deepCopy())
            }
        }
        return copy
    }

    private static func retarget(_ root: XML.Element, from master: Part, to notes: Part) -> XML.Element {
        let copy = root.deepCopy()
        var mapped: [String: String] = [:], pending = [copy]
        while let node = pending.popLast() {
            for attribute in node.attributes where ["r:embed", "r:link", "r:id"].contains(attribute.name) {
                if mapped[attribute.value] == nil, let relationship = master.rels.relationship(withId: attribute.value) {
                    let target = relationship.isExternal ? relationship.target
                        : PackURI.resolve(target: relationship.target, relativeTo: master.uri.baseURI).description
                    mapped[attribute.value] = notes.rels.add(type: relationship.type, target: target, isExternal: relationship.isExternal)
                }
                // A broken master reference must stay broken even if notes has
                // an unrelated relationship with the same source identifier.
                node[attribute: attribute.name] = mapped[attribute.value] ?? "rostrum-unresolved-master-" + attribute.value
            }
            pending += node.childElements
        }
        return copy
    }

    private static func renderCopy(_ part: Part) throws -> Part {
        let relationships = Relationships()
        relationships.setItems(part.rels.items)
        return Part(uri: part.uri, contentType: part.contentType,
            blob: XML.document(canonical(try part.dom())), rels: relationships)
    }

    /// Resolve expanded names before mapping to the renderer's conventional
    /// prefixes. Foreign lookalikes never acquire DrawingML/PML semantics.
    static func canonical(_ root: XML.Element, scope inherited: [String: String] = [:]) -> XML.Element {
        func shallow(_ source: XML.Element, inherited: [String: String]) -> (XML.Element, [String: String]) {
            var scope = inherited
            for attribute in source.attributes {
                if attribute.name == "xmlns" { scope[""] = attribute.value }
                else if attribute.name.hasPrefix("xmlns:") { scope[String(attribute.name.dropFirst(6))] = attribute.value }
            }
            func name(_ value: String, attribute: Bool = false) -> String {
                let pieces = value.split(separator: ":", maxSplits: 1).map(String.init)
                if attribute && pieces.count == 1 { return value }
                let namespace = scope[pieces.count == 2 ? pieces[0] : ""]
                let prefix: String?
                switch namespace { case MinimalTemplate.nsP: prefix = "p"; case MinimalTemplate.nsA: prefix = "a"; case MinimalTemplate.nsR: prefix = "r"; default: prefix = nil }
                if let prefix { return prefix + ":" + pieces.last! }
                return value.replacingOccurrences(of: ":", with: "_")
            }
            let copy = XML.Element(name(source.name))
            copy.attributes = source.attributes.filter { $0.name != "xmlns" && !$0.name.hasPrefix("xmlns:") }.map { (name($0.name, attribute: true), $0.value) }
            copy[attribute: "xmlns:p"] = MinimalTemplate.nsP
            copy[attribute: "xmlns:a"] = MinimalTemplate.nsA
            copy[attribute: "xmlns:r"] = MinimalTemplate.nsR
            return (copy, scope)
        }
        let (copy, scope) = shallow(root, inherited: inherited)
        var pending = [(root, copy, scope)]
        while let (source, target, bindings) = pending.popLast() {
            for node in source.children {
                if case .element(let child) = node {
                    let (childCopy, childScope) = shallow(child, inherited: bindings)
                    target.appendElement(childCopy)
                    pending.append((child, childCopy, childScope))
                } else { target.append(node) }
            }
        }
        return copy
    }
}

public extension Presentation {
    /// Render an existing notes page without creating notes or changing the
    /// package. Uses the file's notes size, master, theme and placeholder types.
    /// Missing notes or invalid page dimensions throw. This bounded preview is
    /// not a universal Office fidelity guarantee; use reporting/strict mode.
    func renderNotesSVG(slideAt index: Int, pixelWidth: Int = 1280, strictRendering: Bool = false) throws -> String {
        try renderNotesSVGReportingProblems(slideAt: index, pixelWidth: pixelWidth, strictRendering: strictRendering).svg
    }

    /// Render notes and report known gaps, including those of the slide image.
    /// Strict mode refuses any reported gap, using the slide renderer's error.
    func renderNotesSVGReportingProblems(slideAt index: Int, pixelWidth: Int = 1280, strictRendering: Bool = false)
        throws -> (svg: String, problems: SlideRenderProblems) {
        guard pixelWidth > 0, pixelWidth <= 100_000 else { throw RostrumError.packageInvalid("notes pixel width must be between 1 and 100000") }
        let slide = try slides[index]
        let size = try NotesPageTemplate.pageSize(in: presentationPart.dom())
        let context = try NotesPageRenderContext(presentation: self, slide: slide, index: index, pixelWidth: pixelWidth)
        let result = try SVGRenderer(slidePart: context.notes, slideSize: (EMU(size.0), EMU(size.1)),
            theme: context.theme, package: package, fonts: fonts, slideNumber: index + 1, notesContext: context).render(pixelWidth: pixelWidth)
        if strictRendering && !result.problems.isEmpty { throw StrictRenderingError(problems: result.problems) }
        return result
    }
}
