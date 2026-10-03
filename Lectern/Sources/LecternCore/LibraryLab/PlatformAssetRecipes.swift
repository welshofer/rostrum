import Foundation
import Rostrum

extension PlatformLabRecipes {
    static func media(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Media and shape taxonomy"), before = try deck.serializedData()
        let video = try resource("PlatformSample", "mp4"), audio = try resource("PlatformSample", "wav")
        let slide = try deck.slides[0]
        try text(label(options), on: slide)
        let movie = try slide.shapes.addMedia(video, format: .mp4, frame: LibraryLabSupport.frame(0.7, 1.8, 4, 3), poster: options.alternative ? nil : LibraryLabSupport.pixels, name: "Owned video")
        let sound = try slide.shapes.addMedia(audio, format: .wav, frame: LibraryLabSupport.frame(5, 1.8, 2, 2), name: "Owned audio")
        // Re-embedding the same clip exercises package deduplication.
        try slide.shapes.addMedia(video, format: .mp4, frame: LibraryLabSupport.frame(8, 1.8, 3, 2), name: "Same video bytes")
        let taxonomy = try deck.slides.add()
        let workbookDeck = try Presentation()
        try workbookDeck.slides[0].shapes.addChart(.barClustered, data: ChartData(categories: ["Owned"], values: [1]), frame: LibraryLabSupport.frame())
        let workbook = try require(workbookDeck.package.parts.values.first { $0.uri.ext == "xlsx" }?.blob, "Owned chart workbook missing")
        let attachmentURI = PackURI("/ppt/embeddings/PlatformSample.xlsx")
        deck.package.addPart(uri: attachmentURI, contentType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", blob: workbook)
        let attachmentID = taxonomy.part.rels.add(type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/package", target: taxonomy.part.uri.relativeReference(to: attachmentURI))
        // PowerPoint requires a preview picture for this embedded workbook.
        // Without it, 16.113.3 repairs the slide even though schema lint passes.
        let previewURI = PackURI("/ppt/media/PlatformOLEPreview.png")
        deck.package.addPart(uri: previewURI, contentType: "image/png", blob: LibraryLabSupport.pixels)
        let previewID = taxonomy.part.rels.add(type: RelType.image, target: taxonomy.part.uri.relativeReference(to: previewURI))
        let root = try taxonomy.part.dom()
        let tree = try require(root.firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"), "Shape tree missing")
        // Owned fixture XML, deliberately separate from public shape authoring.
        let wrapper = try XML.parse(Data("""
        <p:spTree xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <p:grpSp><p:nvGrpSpPr><p:cNvPr id="100" name="Owned group"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="3657600" cy="1828800"/><a:chOff x="0" y="0"/><a:chExt cx="1828800" cy="914400"/></a:xfrm></p:grpSpPr>
            <p:sp><p:nvSpPr><p:cNvPr id="101" name="Owned child"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="914400" cy="914400"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="276D89"/></a:solidFill></p:spPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Owned group child</a:t></a:r></a:p></p:txBody></p:sp>
          </p:grpSp>
          <p:cxnSp><p:nvCxnSpPr><p:cNvPr id="102" name="Owned connector"/><p:cNvCxnSpPr><a:stCxn id="101" idx="1"/><a:endCxn id="103" idx="0"/></p:cNvCxnSpPr><p:nvPr/></p:nvCxnSpPr><p:spPr><a:xfrm><a:off x="2743200" y="1828800"/><a:ext cx="3657600" cy="0"/></a:xfrm><a:prstGeom prst="line"><a:avLst/></a:prstGeom><a:ln w="12700"><a:solidFill><a:srgbClr val="276D89"/></a:solidFill></a:ln></p:spPr></p:cxnSp>
          <p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="103" name="Owned OLE package"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr><p:xfrm><a:off x="6400800" y="914400"/><a:ext cx="2743200" cy="1828800"/></p:xfrm><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/presentationml/2006/ole"><p:oleObj name="Owned workbook" r:id="\(attachmentID)" progId="Excel.Sheet.12" imgW="2743200" imgH="1828800"><p:embed/><p:pic><p:nvPicPr><p:cNvPr id="104" name="Owned OLE preview"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="\(previewID)"/><a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr><a:xfrm><a:off x="6400800" y="914400"/><a:ext cx="2743200" cy="1828800"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic></p:oleObj></a:graphicData></a:graphic></p:graphicFrame>
        </p:spTree>
        """.utf8))
        for element in wrapper.childElements { tree.appendElement(element) }
        taxonomy.part.markDirty()
        // Exercise replacement with exactly the owned bytes, then read the taxonomy.
        let taxonomyBytes = XML.document(try taxonomy.part.dom())
        taxonomy.part.replaceBlob(taxonomyBytes)
        let exported = try exportedFiles(deck)
        var files = exported.files
        files["owned-attachment.xlsx"] = workbook
        let mediaCount = deck.package.parts.values.filter { ["video/mp4", "audio/wav"].contains($0.contentType) }.count
        return LibraryLabDraft(deck: deck, before: before, checks: [
            .init("Valid owned media embedded", movie.mediaData == video && sound.mediaData == audio && sound.isAudio && !movie.isAudio, "A 32×24 H.264 MP4 and 8 kHz PCM WAV are bundled with offline provenance."),
            .init("Identical media deduplicated", mediaCount == 2, "Three media shapes reference only two distinct clip parts."),
            .init("Media extraction bytes", exported.files.values.contains(video) && exported.files.values.contains(audio), "DeckExport writes actual audio/video payloads, not poster substitutes.")
        ], extraFiles: files, verify: { reopened in
            let pictures = try reopened.slides[0].shapes.all.compactMap { $0 as? Picture }.filter(\.isMedia)
            let shapes = try reopened.slides[1].shapes.all
            let group = shapes.compactMap { $0 as? GroupShape }.first
            let connector = shapes.compactMap { $0 as? Connector }.first
            let ole = shapes.compactMap { $0 as? GraphicFrame }.first
            let childRect = group?.shapes.first?.frame
            let converted = childRect.flatMap { group?.convertToParentSpace($0) }
            return [
                .init("Media read back", pictures.count == 3 && pictures.filter { $0.mediaData == video }.count == 2 && pictures.contains { $0.isAudio && $0.mediaData == audio }, "Clip identity and audio/video classification survive reopening."),
                .init("Owned group and connector read back", group?.shapes.count == 1 && converted?.width == .inches(2) && connector?.startConnection?.shapeID == 101 && connector?.endConnection?.shapeID == 103, "Group child coordinates convert at 2×; connection target IDs remain intact."),
                .init("OLE taxonomy and opaque package preserved", ole?.graphicData?[attribute: "uri"] == GraphicDataURI.ole && reopened.package.parts[attachmentURI]?.blob == workbook && reopened.package.parts[previewURI]?.blob == LibraryLabSupport.pixels, "An unsupported graphic-frame payload and valid spreadsheet bytes survive without being interpreted."),
                .init("Foreign shape XML preserved", try XML.document(reopened.slides[1].part.dom()) == taxonomyBytes, "Reading foreign shape facades does not rewrite their XML.")
            ]
        })
    }

    static func package(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "OPC package"), before = try deck.serializedData()
        try text(label(options), on: deck.slides[0])
        let uri = PackURI("/libraryLab/opaque.xml")
        let element = XML.Element("lab:extension", attributes: [("xmlns:lab", "urn:lectern:library-lab"), ("count", String(options.sampleSize))])
        element.appendElement(XML.Element("lab:value"))
        element.firstChild(named: "lab:value")?.append(.text(label(options)))
        let opaque = XML.document(element)
        deck.package.addPart(uri: uri, contentType: "application/xml", blob: opaque)
        let main = try deck.package.mainDocumentPart()
        main.rels.add(type: "urn:lectern:library-lab:extension", target: main.uri.relativeReference(to: uri))
        let saved = try deck.serializedData()
        let archive = try OPCArchive(data: saved, validation: options.alternative ? .onAccess : .strict, cacheBytes: 65_536)
        archive.clearCache()
        let first = try archive.data(forPart: uri), second = try archive.data(forPart: uri)
        let hits = archive.cacheStatistics.hits
        let inspected = try archive.xml(forPart: uri)
        inspected[attribute: "count"] = "unpersisted inspection copy"
        let independent = try archive.xml(forPart: uri)[attribute: "count"] == String(options.sampleSize)
        let promoted = try archive.presentation()
        let zip = try ZipReader(data: saved)
        var refused = false
        do { _ = try OPCArchive(data: saved, limits: .init(totalUncompressedBytes: 0)) }
        catch { refused = true }
        let issues = try promoted.validate()
        archive.clearCache()
        let report = archive.partURIs.map(\.value).joined(separator: "\n")
        return LibraryLabDraft(deck: promoted, before: before, checks: [
            .init("Lazy cache hit and reset", first == opaque && second == opaque && hits >= 1 && archive.cacheStatistics.retainedBytes == 0, "Repeated reads hit the bounded cache; clearCache releases retained payloads."),
            .init("Inspection trees are independent", independent && archive.mainPartURI == main.uri && !archive.relationships.items.isEmpty, "Mutating a read-only XML copy does not edit the archive."),
            .init("ZIP decoding and XML parse", try zip.data(forEntry: uri.memberName) == opaque && XML.parse(opaque).name == "lab:extension", "CRC-checked ZIP bytes parse as the owned extension."),
            .init("Limits refuse before promotion", refused, "A zero aggregate decompression budget rejects this package."),
            .init("Promotion and schema lint", issues.isEmpty, "\(archive.partURIs.count) parts promoted; required-attribute lint reports \(issues.count) issues.")
        ], extraFiles: ["package-parts.txt": Data(report.utf8)], verify: { reopened in
            let part = try reopened.package.part(at: uri)
            let readMain = try reopened.package.mainDocumentPart()
            let untouched = try reopened.serializedData()
            _ = try part.dom()
            return [
                .init("Unknown part and relationship retained", part.blob == opaque && readMain.rels.first(ofType: "urn:lectern:library-lab:extension") != nil, "Unmodeled extension bytes and relationship survive editable promotion/reopening."),
                .init("Read-only save is stable", try reopened.serializedData() == untouched, "Inspecting an unknown XML part does not rewrite its saved bytes.")
            ]
        })
    }

    static func extraction(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Extraction and rendering"), before = try deck.serializedData()
        let font = try resource("DejaVuSans", "ttf")
        try deck.fonts.register(font)
        try deck.embedFont("DejaVu Sans", faces: .init(regular: font))
        let clean = try deck.slides[0]
        // Known text is intentionally fixed so strict success does not depend on
        // arbitrary user-entered Unicode. User copy appears on the content page.
        // Multi-scalar ligatures remain diagnosed; keep the strict-success
        // specimen within the native-calibrated single-scalar ASCII profile.
        try text("AV sample", on: clean)
        let strict = try deck.renderSVG(slideAt: 0, strictRendering: true)
        let ordinary = try deck.renderSVG(slideAt: 0)
        let content = try deck.slides.add()
        try text(label(options), on: content)
        try content.shapes.addPicture(LibraryLabSupport.pixels, frame: LibraryLabSupport.frame(0.7, 2, 2, 2), fit: .stretch)
        let categories = (1...options.sampleSize).map { "Category \($0)" }
        try content.shapes.addChart(.barClustered, data: ChartData(categories: categories, values: (1...options.sampleSize).map(Double.init)), frame: LibraryLabSupport.frame(4, 2, 6, 4))
        try content.setNotes("Notes: " + label(options))
        let diagnostic = try deck.slides.add()
        try text(options.alternative ? "سلام abc" : "Missing face", on: diagnostic, font: options.alternative ? "DejaVu Sans" : "Library Lab Unavailable Face")
        let rendered = try deck.renderSVGReportingProblems(slideAt: 2)
        var refused = false
        do { _ = try deck.renderSVG(slideAt: 2, strictRendering: true) }
        catch is StrictRenderingError { refused = true }
        let notes = try deck.renderNotesSVGReportingProblems(slideAt: 1)
        let outline = deck.outline(), markdown = deck.outline().markdown(title: label(options))
        let exports = try exportedFiles(deck)
        var files = exports.files
        files["strict-slide.svg"] = Data(strict.utf8)
        files["notes-page.svg"] = Data(notes.svg.utf8)
        files["diagnostic-slide.svg"] = Data(rendered.svg.utf8)
        files["outline.md"] = Data(markdown.utf8)
        return LibraryLabDraft(deck: deck, before: before, checks: [
            .init("Strict supported geometry", strict == ordinary && strict.contains("@font-face"), "Known single-scalar ASCII text uses the same font-embedded SVG in ordinary and strict modes."),
            .init("Strict refusal is distinct from rendering", refused && !rendered.problems.isEmpty && rendered.svg.contains("<svg"), "An ordinary diagnostic preview exists; strict mode refuses its known limitations."),
            .init("Actual extracted content", outline.chartCount == 1 && outline.assetCount >= 1 && markdown.contains(label(options)) && exports.assets >= 1 && exports.charts == 1, "Markdown, PNG bytes and one chart CSV were exported."),
            .init("Notes preview uses page geometry", notes.svg.contains("<svg") && notes.svg.contains("Notes:"), "Notes preview produced; \(notes.problems.fidelityIssues.count) known fidelity issue(s) are kept separate from extraction.")
        ], extraFiles: files, verify: { reopened in
            _ = reopened.registerEmbeddedFonts()
            let second = try exportedFiles(reopened)
            let chart = reopened.outline().slides.flatMap(\.charts).first
            let changed = Set(second.files.keys).union(exports.files.keys).filter { second.files[$0] != exports.files[$0] }.sorted()
            return [
                .init("Reopened extraction agrees", second.files == exports.files && chart?.grid.count == options.sampleSize + 1, "Markdown/assets/CSV must agree; changed files: \(changed). Chart rows: \(chart?.grid.count ?? -1), expected \(options.sampleSize + 1)."),
                .init("Reopened strict rendering agrees", try reopened.renderSVG(slideAt: 0, strictRendering: true) == strict, "The embedded font recovers the same strict SVG."),
                .init("Reopened notes remain readable", reopened.outline().slides[1].notes.contains("Notes: " + label(options)), "Notes text is extracted from the serialized notes part.")
            ]
        })
    }
}
