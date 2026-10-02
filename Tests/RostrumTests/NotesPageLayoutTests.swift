import Foundation
import Testing
@testable import Rostrum

@Suite struct NotesPageLayoutTests {
    private func placeholders(_ root: XML.Element) -> [XML.Element] {
        root.firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.children(named: "p:sp") ?? []
    }
    private func placeholder(_ shape: XML.Element) -> XML.Element? {
        shape.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph")
    }

    @Test func newlyAuthoredNotesHavePrintableInheritedGeometry() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addShape(.rectangle,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(3)),
            fill: .solid(Color("276D89")))
        try deck.slides[0].setNotes("A readable notes page.")
        let notes = try deck.slides[0].part.related(by: RelType.notesSlide, in: deck.package)
        let master = try notes.related(by: RelType.notesMaster, in: deck.package)
        let shapes = placeholders(try master.dom())
        #expect(shapes.compactMap { placeholder($0)?[attribute: "type"] } == ["sldImg", "body"])
        var bottom = 0
        for shape in shapes {
            let transform = try #require(shape.firstChild(named: "p:spPr")?.firstChild(named: "a:xfrm"))
            let offset = try #require(transform.firstChild(named: "a:off"))
            let extent = try #require(transform.firstChild(named: "a:ext"))
            let x = try #require(Int(offset[attribute: "x"] ?? "")), y = try #require(Int(offset[attribute: "y"] ?? ""))
            let width = try #require(Int(extent[attribute: "cx"] ?? "")), height = try #require(Int(extent[attribute: "cy"] ?? ""))
            #expect(x > 0 && width > 0 && x + width < 6_858_000)
            #expect(y >= bottom && height > 0 && y + height < 9_144_000)
            bottom = y + height
        }
        #expect(placeholders(try notes.dom()).compactMap { placeholder($0)?[attribute: "idx"] } == ["2", "1"])
        #expect(try deck.validate().isEmpty)
        let bytes = try deck.serializedData()
        let reopened = try Presentation(data: bytes)
        #expect(try reopened.slides[0].notesText == "A readable notes page.")
        #expect(try reopened.serializedData() == bytes)
        if let folder = ProcessInfo.processInfo.environment["ROSTRUM_NOTES_ORACLE_OUTPUT"] {
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try bytes.write(to: URL(fileURLWithPath: folder).appendingPathComponent("authored-notes.pptx"))
        }
    }

    @Test func foreignMasterPlaceholderIDsAndGeometryRemainAuthoritative() throws {
        let root = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let source = try Presentation(contentsOf: root.appendingPathComponent("Conformance/python-tables-v3.pptx"))
        let destination = try Presentation()
        destination.slideSize = source.slideSize
        _ = try destination.slides.import(from: source, at: 0)
        try destination.slides.remove(at: 0)
        let master = try destination.presentationPart.related(by: RelType.notesMaster, in: destination.package)
        let masterBefore = try master.dom().serialized()
        // New notes in a foreign deck must inherit body idx=3, not Rostrum's 1.
        let added = try destination.slides.add()
        try added.setNotes("Uses the existing notes master.")
        let notes = try added.part.related(by: RelType.notesSlide, in: destination.package)
        let body = try #require(placeholders(notes.dom()).first { placeholder($0)?[attribute: "type"] == "body" })
        #expect(placeholder(body)?[attribute: "idx"] == "3")
        #expect(body.firstChild(named: "p:spPr")?.childElements.isEmpty == true)
        #expect(try master.dom().serialized() == masterBefore)
        try destination.slides.remove(at: 1)
        #expect(try destination.slides[0].notesText == "Independent table fixture notes.")
        if let folder = ProcessInfo.processInfo.environment["ROSTRUM_NOTES_ORACLE_OUTPUT"] {
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try destination.serializedData().write(to: URL(fileURLWithPath: folder).appendingPathComponent("imported-notes.pptx"))
        }
    }

    @Test func legacyEmptyMasterGetsLocalFallbackWithoutMutation() throws {
        let deck = try Presentation()
        try deck.slides[0].setNotes("first")
        let master = try deck.presentationPart.related(by: RelType.notesMaster, in: deck.package)
        let tree = try #require(master.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
        tree.removeChildren(named: "p:sp"); master.markDirty()
        let before = try master.dom().serialized()
        let added = try deck.slides.add()
        try added.setNotes("second")
        let notes = try added.part.related(by: RelType.notesSlide, in: deck.package)
        #expect(placeholders(try notes.dom()).allSatisfy { $0.firstChild(named: "p:spPr")?.firstChild(named: "a:xfrm") != nil })
        #expect(try master.dom().serialized() == before)
    }

    @Test func invalidPageSizeRefusesBeforeCreatingParts() throws {
        let deck = try Presentation()
        let size = try #require(deck.presentationPart.dom().firstChild(named: "p:notesSz"))
        size[attribute: "cx"] = "9223372036854775807"; deck.presentationPart.markDirty()
        let before = try deck.serializedData()
        #expect(throws: (any Error).self) { try deck.slides[0].setNotes("refused") }
        #expect(try deck.serializedData() == before)
    }

    @Test(arguments: ["q:notesSz xmlns:q", "notesSz xmlns"])
    func pageSizeRecognizesAliasedAndDefaultNamespaces(_ declaration: String) throws {
        let root = try XML.parse(Data("""
        <p:presentation xmlns:p="\(MinimalTemplate.nsP)" xmlns:fake="urn:foreign">
        <fake:notesSz cx="1" cy="2"/><\(declaration)="\(MinimalTemplate.nsP)" cx="6858000" cy="9144000"/>
        </p:presentation>
        """.utf8))
        let size = try NotesPageTemplate.pageSize(in: root)
        #expect(size.0 == 6_858_000 && size.1 == 9_144_000)
    }

    @Test func aliasedMasterBindsOnlyRealPresentationPlaceholders() throws {
        let master = try XML.parse(Data("""
        <q:notesMaster xmlns:q="\(MinimalTemplate.nsP)" xmlns:fake="urn:foreign"><q:cSld><q:spTree>
        <fake:ph type="body" idx="99"/><q:sp><q:nvSpPr><q:nvPr><q:ph type="body" idx="7" orient="horz" sz="quarter"/></q:nvPr></q:nvSpPr></q:sp>
        </q:spTree></q:cSld></q:notesMaster>
        """.utf8))
        let notes = try XML.parse(NotesPageTemplate.slide(master: master, size: (6_858_000, 9_144_000)))
        let body = try #require(placeholders(notes).first { placeholder($0)?[attribute: "type"] == "body" })
        #expect(placeholder(body)?[attribute: "idx"] == "7")
        #expect(placeholder(body)?[attribute: "sz"] == "quarter")
        #expect(body.firstChild(named: "p:spPr")?.childElements.isEmpty == true)
    }

    @Test func opaqueExtensionsDoNotSupplyPlaceholderGeometry() throws {
        let master = try XML.parse(Data("""
        <p:notesMaster xmlns:p="\(MinimalTemplate.nsP)" xmlns:x="urn:foreign"><p:cSld><p:spTree/></p:cSld>
        <p:extLst><p:ext><x:storedShape><p:ph type="body" idx="99"/></x:storedShape></p:ext></p:extLst></p:notesMaster>
        """.utf8))
        let notes = try XML.parse(NotesPageTemplate.slide(master: master, size: (6_858_000, 9_144_000)))
        let body = try #require(placeholders(notes).first { placeholder($0)?[attribute: "type"] == "body" })
        #expect(placeholder(body)?[attribute: "idx"] == "1")
        #expect(body.firstChild(named: "p:spPr")?.firstChild(named: "a:xfrm") != nil)
    }
}
