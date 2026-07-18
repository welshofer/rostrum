import Foundation

/// Speaker notes. Notes live in a `notesSlide` part per slide, all bound to a
/// single `notesMaster`; Rostrum creates both lazily on first use.
extension Slide {
    /// True if this slide already has a notes part.
    public var hasNotes: Bool {
        part.rels.first(ofType: RelType.notesSlide) != nil
    }

    /// The slide's speaker-notes text ("" when none).
    public var notesText: String {
        guard hasNotes, let frame = try? notesTextFrame() else { return "" }
        return frame.text
    }

    /// Convenience: replace the speaker notes with plain text.
    public func setNotes(_ text: String) throws {
        try notesTextFrame().text = text
    }

    /// The notes body text frame, creating the notes slide (and the deck's
    /// notes master, first time) on demand.
    public func notesTextFrame() throws -> TextFrame {
        let notesPart = try existingNotesPart() ?? createNotesPart()
        guard let body = Self.bodyPlaceholderTxBody(in: try notesPart.dom()) else {
            throw RostrumError.packageInvalid("notes slide \(notesPart.uri) has no body placeholder")
        }
        return TextFrame(txBody: body, part: notesPart)
    }

    private func existingNotesPart() throws -> Part? {
        guard let rel = part.rels.first(ofType: RelType.notesSlide) else { return nil }
        return try package.part(at: PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI))
    }

    private func createNotesPart() throws -> Part {
        let master = try ensureNotesMaster()

        var n = 1
        while package.parts[PackURI("/ppt/notesSlides/notesSlide\(n).xml")] != nil { n += 1 }
        let uri = PackURI("/ppt/notesSlides/notesSlide\(n).xml")

        let notes = package.addPart(
            uri: uri, contentType: ContentType.notesSlide,
            blob: Data(Self.notesSlideXML.utf8))
        notes.rels.add(type: RelType.notesMaster, target: uri.relativeReference(to: master.uri))
        notes.rels.add(type: RelType.slide, target: uri.relativeReference(to: part.uri))
        part.rels.add(type: RelType.notesSlide, target: part.uri.relativeReference(to: uri))
        return notes
    }

    /// The deck-wide notes master: find it or create it and wire it into
    /// `p:notesMasterIdLst` (schema position: after sldMasterIdLst, before
    /// sldIdLst).
    private func ensureNotesMaster() throws -> Part {
        let uri = PackURI("/ppt/notesMasters/notesMaster1.xml")
        if let existing = package.parts[uri] { return existing }

        let master = package.addPart(
            uri: uri, contentType: ContentType.notesMaster,
            blob: Data(Self.notesMasterXML.utf8))
        // Office invariant: every master owns a DISTINCT theme part — sharing
        // the slide master's theme1 trips PowerPoint's repair dialog.
        var themeN = 1
        while package.parts[PackURI("/ppt/theme/theme\(themeN).xml")] != nil { themeN += 1 }
        let notesTheme = package.addPart(
            uri: PackURI("/ppt/theme/theme\(themeN).xml"),
            contentType: ContentType.theme,
            blob: Data(MinimalTemplate.themeXML.utf8))
        master.rels.add(type: RelType.theme, target: master.uri.relativeReference(to: notesTheme.uri))

        let presentation = try package.mainDocumentPart()
        let rId = presentation.rels.add(
            type: RelType.notesMaster,
            target: presentation.uri.relativeReference(to: uri))
        let dom = try presentation.dom()
        let list = dom.getOrAddChild(
            "p:notesMasterIdLst",
            beforeAnyOf: ["p:handoutMasterIdLst", "p:sldIdLst", "p:sldSz", "p:notesSz"])
        list.appendElement(XML.Element("p:notesMasterId", attributes: [("r:id", rId)]))
        presentation.markDirty()
        return master
    }

    /// Find the `p:txBody` of the body placeholder (`p:ph type="body"`).
    static func bodyPlaceholderTxBody(in root: XML.Element) -> XML.Element? {
        var stack = [root]
        while let element = stack.popLast() {
            if element.name == "p:sp",
               let ph = element.firstChild(named: "p:nvSpPr")?
                   .firstChild(named: "p:nvPr")?.firstChild(named: "p:ph"),
               ph[attribute: "type"] == "body" {
                return element.firstChild(named: "p:txBody")
            }
            stack.append(contentsOf: element.childElements)
        }
        return nil
    }

    static let notesSlideXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:notes xmlns:a="\(MinimalTemplate.nsA)" xmlns:r="\(MinimalTemplate.nsR)" xmlns:p="\(MinimalTemplate.nsP)"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr><p:sp><p:nvSpPr><p:cNvPr id="2" name="Notes Placeholder 1"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr><p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:notes>
        """

    static let notesMasterXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:notesMaster xmlns:a="\(MinimalTemplate.nsA)" xmlns:r="\(MinimalTemplate.nsR)" xmlns:p="\(MinimalTemplate.nsP)"><p:cSld><p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/></p:notesMaster>
        """
}
