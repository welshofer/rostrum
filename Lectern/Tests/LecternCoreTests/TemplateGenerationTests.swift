import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct TemplateGenerationTests {
    private func source(slides: Int = 2) throws -> Presentation {
        let deck = try Presentation()
        deck.documentKind = .template
        let originalWidth = Double(deck.slideSize.width.rawValue)
        deck.slideSize = (.inches(10), .inches(7.5))
        let scaleX = Double(deck.slideSize.width.rawValue) / originalWidth
        for part in deck.package.parts.values where [ContentType.slideLayout, ContentType.slideMaster].contains(part.contentType) {
            var pending = [try part.dom()]
            while let node = pending.popLast() {
                for key in node.name == "a:off" ? ["x"] : node.name == "a:ext" ? ["cx"] : [] {
                    if let value = node[attribute: key].flatMap(Double.init) { node[attribute: key] = String(Int((value * scaleX).rounded())) }
                }
                pending += node.childElements
            }
            part.markDirty()
        }
        deck.theme.majorFont = "Georgia"
        deck.theme.minorFont = "Arial"
        deck.theme.setAccent(1, Color("7B2D8B"))
        deck.theme.setColor(.lt1, Color("FFF7EA"))
        deck.documentProperties.company = "Template brand"
        let master = try #require(deck.slideMasters.first?.part)
        let tree = try #require(master.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
        // Owned master artwork, deliberately outside the builders' content
        // margin, so native verification can see inheritance on every slide.
        let brand = try XML.parse(Data("""
        <p:sp xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:nvSpPr><p:cNvPr id="99" name="Template purple corner mark"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="8229600" y="201168"/><a:ext cx="685800" cy="73152"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="7B2D8B"/></a:solidFill><a:ln><a:noFill/></a:ln></p:spPr></p:sp>
        """.utf8))
        tree.appendElement(brand)
        master.markDirty()
        while deck.slides.count < slides { _ = try deck.slides.add() }
        while deck.slides.count > slides { try deck.slides.remove(at: 0) }
        if slides > 0 {
            try deck.slides[0].setNotes("SOURCE NOTES MUST DISAPPEAR")
            try deck.slides[0].addComment("SOURCE COMMENT MUST DISAPPEAR", author: "Template author")
            try deck.setSections([("Source examples", 0)])
            let main = try deck.package.mainDocumentPart()
            let dom = try main.dom()
            let id = try #require(main.rels.first(ofType: RelType.slide)?.rId)
            let shows = XML.Element("p:custShowLst")
            let show = XML.Element("p:custShow", attributes: [("name", "Source show"), ("id", "0")])
            let list = XML.Element("p:sldLst")
            list.appendElement(XML.Element("p:sld", attributes: [("r:id", id)]))
            show.appendElement(list); shows.appendElement(show)
            let index = dom.children.firstIndex { if case .element(let child) = $0 { return child.name == "p:extLst" }; return false } ?? dom.children.count
            dom.children.insert(.element(shows), at: index)
            main.markDirty()
            let uri = PackURI("/ppt/presProps.xml")
            _ = deck.package.addPart(uri: uri, contentType: ContentType.presProps, blob: Data("""
            <p:presentationPr xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:showPr><p:present/><p:custShow id="0"/></p:showPr></p:presentationPr>
            """.utf8))
            main.rels.add(type: RelType.presProps, target: "presProps.xml")
        }
        return deck
    }

    private func content(withSections: Bool = true) -> DeckIR {
        DeckIR(meta: Meta(title: "Template generated"),
            sections: withSections ? [IRSection(id: "new", title: "Generated section", slideIds: ["a", "b", "c"])] : nil,
            slides: [
                IRSlide(id: "a", layout: "title", title: "A new presentation", body: Body(subtitle: "New content"), notes: "New opening notes"),
                IRSlide(id: "b", layout: "bullets", title: "Template branding", body: Body(bullets: [Bullet(text: "The template is used locally.")]), notes: "New evidence notes"),
                IRSlide(id: "c", layout: "closing", title: "Ready to use", body: Body(callToAction: "Open the saved file"), notes: "New closing notes")
            ])
    }

    private func scratch() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("template-generation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func templateSurvivesProviderRepairAndQAIntoSavedPresentation() async throws {
        let directory: URL
        let keep = ProcessInfo.processInfo.environment["LECTERN_TEMPLATE_ARTIFACTS"]
        if let keep {
            directory = URL(fileURLWithPath: keep, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } else { directory = try scratch() }
        defer { if keep == nil { try? FileManager.default.removeItem(at: directory) } }
        let original = try source()
        let sourceBytes = try original.serializedData()
        let sourceURL = directory.appendingPathComponent("selected-template.potx")
        try sourceBytes.write(to: sourceURL)
        let template = try DeckTemplate.load(contentsOf: sourceURL)
        #expect(template.name == "selected-template.potx")
        #expect(template.slideCount == 2 && template.layoutCount == original.allLayouts.count)
        #expect(template.widthInches == 10 && template.heightInches == 7.5)
        let json = String(decoding: try JSONEncoder().encode(content()), as: UTF8.self)
        let provider = TemplateProvider(json: json)
        let result = try await DeckGenerator(provider: provider).generate(
            DeckRequest(prompt: "Create something new", slideCount: 3, notes: true),
            designURL: URL(fileURLWithPath: "/a-design-that-must-never-be-opened.md"),
            template: template, into: directory) { _ in }
        let output = try Presentation(contentsOf: result.url)
        #expect(await provider.draftCalls == 2)
        #expect(await provider.revisionCalls == 1)
        #expect(await provider.prompts == ["Create something new", "Create something new"])
        #expect(output.documentKind == .presentation && output.slides.count == 3)
        #expect(output.slideSize.width == .inches(10) && output.slideSize.height == .inches(7.5))
        #expect(output.theme.majorFont == "Georgia" && output.theme.accent(1) == Color("7B2D8B"))
        #expect(output.sections.map(\.name) == ["Generated section"])
        #expect(output.slides.map(\.notesText) == content().slides.map { $0.notes! })
        #expect(try output.slides.allSatisfy { try $0.comments.isEmpty })
        #expect(result.droppedContent.isEmpty)
        #expect(result.schemaIssues.isEmpty)
        #expect(try Data(contentsOf: sourceURL) == sourceBytes)
        // All masters/layouts/themes are retained byte-for-byte, not recreated
        // from a generic theme with only its displayed name copied.
        for part in original.package.parts.values where [ContentType.slideMaster, ContentType.slideLayout, ContentType.theme].contains(part.contentType) {
            #expect(try output.package.part(at: part.uri).blob == part.blob)
        }
        let main = try output.package.mainDocumentPart()
        #expect(try main.dom().firstChild(named: "p:custShowLst") == nil)
        let props = try output.package.part(at: PackURI("/ppt/presProps.xml")).dom()
        #expect(props.firstChild(named: "p:showPr")?.firstChild(named: "p:custShow") == nil)
        #expect(props.firstChild(named: "p:showPr")?.firstChild(named: "p:sldAll") != nil)
        let texts = output.package.parts.values.filter { $0.uri.ext == "xml" }.map { String(decoding: $0.blob, as: UTF8.self) }.joined()
        #expect(!texts.contains("SOURCE NOTES MUST DISAPPEAR") && !texts.contains("SOURCE COMMENT MUST DISAPPEAR"))
    }

    @Test func emptyTemplateAndSectionlessGeneratedContentWork() async throws {
        let directory = try scratch(); defer { try? FileManager.default.removeItem(at: directory) }
        for count in [0, 3] {
            let template = try DeckTemplate(data: source(slides: count).serializedData(), name: "Examples.potx")
            let result = try await DeckRenderer().render(content(withSections: false), designURL: nil, notesEnabled: false, template: template, into: directory)
            let output = try Presentation(contentsOf: result.url)
            #expect(result.slideCount == 3 && output.sections.count == 0)
            #expect(output.slides.allSatisfy { !$0.hasNotes })
        }
    }

    @Test func snapshotDoesNotDependOnTheSourceFileAfterSelection() async throws {
        let directory = try scratch(); defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.pptx")
        let original = try source(slides: 0)
        original.documentKind = .presentation
        try original.save(to: file)
        let selected = try DeckTemplate.load(contentsOf: file)
        try Data("File replaced after selection".utf8).write(to: file)
        let result = try await DeckRenderer().render(content(), designURL: nil, notesEnabled: true, template: selected, into: directory)
        #expect(try Presentation(contentsOf: result.url).theme.majorFont == "Georgia")
        #expect(try Data(contentsOf: file) == Data("File replaced after selection".utf8))
    }

    @Test func secondaryMastersAreRetainedAndTheirSelectionBoundaryIsVisible() async throws {
        let directory = try scratch(); defer { try? FileManager.default.removeItem(at: directory) }
        let base = try source(slides: 0)
        let other = try source(slides: 1)
        other.theme.majorFont = "Courier New"
        _ = try base.slides.importAll(from: other)
        #expect(base.slideMasters.count == 2)
        // The master-id list controls the order, independently of relationship
        // stream order. The imported master's relationship is still last.
        let main = try base.package.mainDocumentPart()
        let masters = try #require(main.dom().firstChild(named: "p:sldMasterIdLst"))
        masters.children.reverse()
        main.markDirty()
        let template = try DeckTemplate(data: base.serializedData(), name: "Multiple masters.potx")
        #expect(template.warnings.contains { $0.contains("first master is selected") })
        let result = try await DeckRenderer().render(content(), designURL: nil, notesEnabled: false, template: template, into: directory)
        let output = try Presentation(contentsOf: result.url)
        #expect(output.slideMasters.count == 2 && output.theme.majorFont == "Courier New")
        #expect(output.slides.allSatisfy { $0.master?.part.uri == output.slideMasters.first?.part.uri })
    }

    @Test func sourceOnlyPayloadsAreRemovedWhileMasterAndUnknownRootsKeepSharedAssets() async throws {
        let directory = try scratch(); defer { try? FileManager.default.removeItem(at: directory) }
        let base = try source()
        let slide = try base.slides[0]
        _ = try slide.shapes.addChart(.barClustered, data: ChartData(categories: ["Private source category"], name: "Private source series", values: [987654]),
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(5), height: .inches(4)))
        let sourcePayloads = Set(base.package.parts.values.filter { $0.uri.value.hasPrefix("/ppt/charts/") || $0.uri.value.hasPrefix("/ppt/embeddings/") }.map(\.uri))
        #expect(sourcePayloads.count >= 2)
        let png = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg=="))
        _ = try slide.shapes.addPicture(png, frame: Rect(x: .inches(9), y: .inches(0.1), width: .inches(0.2), height: .inches(0.2)))
        let imageRel = try #require(slide.part.rels.first(ofType: RelType.image))
        let imageURI = PackURI.resolve(target: imageRel.target, relativeTo: slide.part.uri.baseURI)
        let master = try #require(base.slideMasters.first?.part)
        master.rels.add(type: RelType.image, target: master.uri.relativeReference(to: imageURI))
        let attachmentURI = PackURI("/ppt/embeddings/source-only.bin")
        _ = base.package.addPart(uri: attachmentURI, contentType: "application/octet-stream", blob: Data("PRIVATE ATTACHMENT".utf8))
        slide.part.rels.add(type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/oleObject", target: slide.part.uri.relativeReference(to: attachmentURI))
        let sharedURI = PackURI("/custom/shared.bin")
        _ = base.package.addPart(uri: sharedURI, contentType: "application/octet-stream", blob: Data("Shared opaque asset".utf8))
        slide.part.rels.add(type: "urn:owned:shared", target: slide.part.uri.relativeReference(to: sharedURI))
        let orphanURI = PackURI("/custom/unrelated.xml")
        let orphan = base.package.addPart(uri: orphanURI, contentType: "application/xml", blob: Data("<owned/>".utf8))
        orphan.rels.add(type: "urn:owned:shared", target: orphan.uri.relativeReference(to: sharedURI))
        let template = try DeckTemplate(data: base.serializedData(), name: "Private examples.pptx")
        let result = try await DeckRenderer().render(content(), designURL: nil, notesEnabled: true, template: template, into: directory)
        let output = try Presentation(contentsOf: result.url)
        #expect(sourcePayloads.allSatisfy { output.package.parts[$0] == nil })
        #expect(output.package.parts[attachmentURI] == nil)
        #expect(output.package.parts[imageURI]?.blob == png)
        #expect(output.package.parts[sharedURI] != nil && output.package.parts[orphanURI] != nil)
    }

    @Test func unsupportedCanvasSizesFailBeforeGridConstruction() throws {
        for inches in [1.0, 1.8, 3.9, 4.0, 56.1] {
            let deck = try source(slides: 0)
            deck.slideSize = (.inches(inches), .inches(7.5))
            #expect(throws: DeckTemplateError.self) { try DeckTemplate(data: deck.serializedData(), name: "Unsupported.potx") }
        }
        let boundary = try source(slides: 0)
        boundary.slideSize = (.inches(4.01), .inches(4.01))
        #expect(try DeckTemplate(data: boundary.serializedData(), name: "Boundary.potx").widthInches == 4.01)
    }

    @Test func malformedTemplateFailsBeforeProviderWork() async throws {
        let directory = try scratch(); defer { try? FileManager.default.removeItem(at: directory) }
        let provider = TemplateProvider(json: "{}")
        do {
            _ = try await DeckGenerator(provider: provider).generate(
                DeckRequest(prompt: "Do not send", slideCount: 3), designURL: nil,
                template: DeckTemplate(data: Data("Not a PowerPoint".utf8), name: "bad.potx"), into: directory) { _ in }
            Issue.record("Malformed template was accepted")
        } catch {}
        #expect(await provider.draftCalls == 0)
        let missingLayout = try source(slides: 0)
        for layout in missingLayout.layouts { missingLayout.package.removePart(at: layout.part.uri) }
        #expect(throws: (any Error).self) { try DeckTemplate(data: missingLayout.serializedData(), name: "broken.potx") }
        let show = try source(slides: 0); show.documentKind = .slideShow
        #expect(throws: DeckTemplateError.self) { try DeckTemplate(data: show.serializedData(), name: "show.ppsx") }
    }

    @Test func fileLimitIsEnforcedBeforeReadingPayload() throws {
        let directory = try scratch(); defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("too-large.potx")
        #expect(FileManager.default.createFile(atPath: file.path, contents: nil))
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: UInt64(DeckTemplate.maximumFileBytes + 1))
        try handle.close()
        #expect(throws: DeckTemplateError.self) { try DeckTemplate.load(contentsOf: file) }
    }
}

private actor TemplateProvider: LLMProvider {
    nonisolated let id: ProviderID = .custom
    nonisolated let displayName = "Template pipeline fixture"
    let json: String
    var draftCalls = 0
    var revisionCalls = 0
    var prompts: [String] = []
    init(json: String) { self.json = json }
    func draft(_ request: DeckRequest, repairing: RepairContext?, emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft {
        draftCalls += 1; prompts.append(request.prompt)
        return RawDraft(json: repairing == nil ? "{" : json, usage: Usage())
    }
    func revise(_ request: DeckRequest, deckJSON: String, emit: @Sendable (GenerationEvent) -> Void) async throws -> RawDraft {
        revisionCalls += 1
        return RawDraft(json: json, usage: Usage())
    }
}
