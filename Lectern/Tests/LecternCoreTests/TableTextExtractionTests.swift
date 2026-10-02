import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct TableTextExtractionTests {
    private let drawing = "http://schemas.openxmlformats.org/drawingml/2006/main"
    private let presentation = "http://schemas.openxmlformats.org/presentationml/2006/main"

    @Test func scopedAliasesDefaultNamespacesFieldsAndLookalikesAreReadWithoutMutation() throws {
        let root = try xml("""
        <p:sld xmlns:p="\(presentation)" xmlns:d="\(drawing)"><p:cSld><p:spTree>
        <p:graphicFrame><d:graphic><d:graphicData uri="\(GraphicDataURI.table)">
        <tbl xmlns="\(drawing)"><tblGrid><gridCol/><gridCol/></tblGrid><tr>
        <tc><txBody><p><pPr><defRPr><latin typeface="Default Face"/></defRPr></pPr>
        <r><t>Run</t></r><br/><fld id="{00000000-0000-0000-0000-000000000001}" type="datetime1"><rPr><latin typeface="Field Face"/></rPr><t>Field</t></fld>
        <d:r xmlns:d="urn:lookalike"><d:rPr><d:latin typeface="Wrong Face"/></d:rPr><d:t>Wrong text</d:t></d:r>
        </p><p><r><t>Second paragraph</t></r></p></txBody></tc>
        </tr><d:tr xmlns:d="urn:lookalike"><d:tc/></d:tr></tbl>
        </d:graphicData></d:graphic></p:graphicFrame>
        <p:extLst><p:ext uri="opaque"><d:tbl><d:tblGrid><d:gridCol/></d:tblGrid><d:tr><d:tc/></d:tr></d:tbl></p:ext></p:extLst>
        </p:spTree></p:cSld></p:sld>
        """)
        let before = XML.document(root)
        var budget = 10
        let result = TableTextExtractor.extract(in: root, remainingCells: &budget)
        #expect(result.tables.map(\.rows) == [[["Run\nField\nSecond paragraph", ""]]])
        #expect(result.warnings.isEmpty && budget == 8)
        #expect(DeckDetailExtractor.declaredFonts(in: root) == ["Default Face", "Field Face"])
        #expect(XML.document(root) == before)
    }

    @Test func aliasedSlideAndNestedGroupAreSupportedButForeignTablePayloadsAreNot() throws {
        let root = try xml("""
        <sld xmlns="\(presentation)" xmlns:d="\(drawing)"><cSld><spTree><grpSp>
        <graphicFrame><d:graphic><d:graphicData uri="\(GraphicDataURI.table)"><d:tbl><d:tblGrid><d:gridCol/></d:tblGrid><d:tr><d:tc><d:txBody><d:p><d:r><d:t>Nested</d:t></d:r></d:p></d:txBody></d:tc></d:tr></d:tbl></d:graphicData></d:graphic></graphicFrame>
        <graphicFrame><d:graphic><d:graphicData uri="\(GraphicDataURI.table)"><d:tbl xmlns:d="urn:foreign"><d:tblGrid><d:gridCol/></d:tblGrid><d:tr/></d:tbl></d:graphicData></d:graphic></graphicFrame>
        </grpSp></spTree></cSld></sld>
        """)
        var budget = 1
        let result = TableTextExtractor.extract(in: root, remainingCells: &budget)
        #expect(result.tables.map(\.rows) == [[["Nested"]]])
        #expect(result.warnings.isEmpty && budget == 0)
    }

    @Test func sharedCellBudgetRefusesDenseRaggedTablesWithoutAllocation() throws {
        let root = try xml("""
        <p:sld xmlns:p="\(presentation)" xmlns:a="\(drawing)"><p:cSld><p:spTree><p:graphicFrame><a:graphic><a:graphicData uri="\(GraphicDataURI.table)"><a:tbl><a:tblGrid><a:gridCol/><a:gridCol/></a:tblGrid><a:tr/><a:tr/></a:tbl></a:graphicData></a:graphic></p:graphicFrame></p:spTree></p:cSld></p:sld>
        """)
        var budget = 3
        let refused = TableTextExtractor.extract(in: root, remainingCells: &budget)
        #expect(refused.budgetExceeded && refused.tables[0].rows.isEmpty && budget == 3)
        #expect(refused.warnings.count == 1)
        budget = 4
        let first = TableTextExtractor.extract(in: root, remainingCells: &budget)
        #expect(first.tables[0].rows == [["", ""], ["", ""]] && budget == 0)
        #expect(TableTextExtractor.extract(in: root, remainingCells: &budget).budgetExceeded)
    }

    @Test func inspectionAndRefreshExportRestoreAliasedTableTextAndKeepSourceExact() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        _ = try slide.shapes.addTable(rows: 1, columns: 1, frame: Rect(x: .inches(0), y: .inches(0), width: .inches(2), height: .inches(1))).setContents([["CANONICAL CELL"]])
        _ = try slide.shapes.addTable(rows: 1, columns: 1, frame: Rect(x: .inches(2), y: .inches(0), width: .inches(2), height: .inches(1))).setContents([["ALIASED CELL"]])
        let dom = try slide.part.dom()
        let tree = try #require(dom.firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"))
        let frame = try #require(tree.children(named: "p:graphicFrame").last)
        let table = try #require(frame.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?.firstChild(named: "a:tbl"))
        let paragraph = try #require(table.firstChild(named: "a:tr")?.firstChild(named: "a:tc")?.firstChild(named: "a:txBody")?.firstChild(named: "a:p"))
        paragraph.appendElement(XML.Element("a:br"))
        paragraph.appendElement(try xml("<a:fld xmlns:a=\"\(drawing)\" id=\"{00000000-0000-0000-0000-000000000001}\" type=\"datetime1\"><a:rPr><a:latin typeface=\"Field Face\"/></a:rPr><a:t>FIELD TEXT</a:t></a:fld>"))
        paragraph.appendElement(try xml("<a:r xmlns:a=\"urn:foreign\"><a:rPr><a:latin typeface=\"Wrong Face\"/></a:rPr><a:t>WRONG TEXT</a:t></a:r>"))
        frame[attribute: "xmlns:d"] = drawing
        renameDrawing(in: frame)
        // An unknown extension is retained but never interpreted as table content.
        dom.appendElement(try xml("<p:extLst xmlns:p=\"\(presentation)\"><p:ext uri=\"opaque\"><payload xmlns=\"urn:opaque\">preserved</payload></p:ext></p:extLst>"))
        slide.part.markDirty()
        try withFile(try deck.serializedData()) { source, output, bytes in
            let inspection = try DeckInspector.inspect(deckAt: source, renderPreviews: false)
            #expect(inspection.slides[0].tableCount == 2)
            #expect(inspection.slides[0].tables.map(\.rows) == [[["CANONICAL CELL"]], [["ALIASED CELL\nFIELD TEXT"]]])
            #expect(inspection.explicitFonts.contains("Field Face"))
            #expect(!inspection.explicitFonts.contains("Wrong Face"))
            let first = try DeckExporter.export(deckAt: source, into: output)
            let text = try String(contentsOf: first.markdownFile, encoding: .utf8)
            #expect(text.components(separatedBy: "CANONICAL CELL").count == 2)
            #expect(text.components(separatedBy: "ALIASED CELL").count == 2)
            #expect(text.contains("FIELD TEXT") && !text.contains("WRONG TEXT"))
            let second = try DeckExporter.export(deckAt: source, into: output)
            #expect(try Data(contentsOf: second.markdownFile) == Data(text.utf8))
            #expect(try Data(contentsOf: source) == bytes)
        }
    }

    @Test func identicalOrdinaryTablesAreNotSupplementedAndMergeContinuationPolicyMatchesOutline() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        for _ in 0..<2 {
            _ = try slide.shapes.addTable(rows: 1, columns: 1, frame: Rect(x: .inches(0), y: .inches(0), width: .inches(2), height: .inches(1))).setContents([["SAME CELL"]])
        }
        let merged = try slide.shapes.addTable(rows: 2, columns: 2, frame: Rect(x: .inches(0), y: .inches(1), width: .inches(2), height: .inches(1)))
        merged.setContents([["Origin", "Discarded"], ["Discarded", "Discarded"]])
        try merged.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 2)
        var budget = 10
        let extraction = TableTextExtractor.extract(in: try slide.part.dom(), remainingCells: &budget)
        #expect(extraction.tables.map(\.rows) == deck.outline().slides[0].tables.map(\.rows))
        try withFile(try deck.serializedData()) { source, output, _ in
            let result = try DeckExporter.export(deckAt: source, into: output)
            let markdown = try String(contentsOf: result.markdownFile, encoding: .utf8)
            #expect(markdown.components(separatedBy: "SAME CELL").count == 3)
            #expect(!markdown.contains("table 1 text") && !markdown.contains("table 2 text"))
        }
    }

    @Test func partiallyReadableTableExportIncludesCorrectTextAndReportsBaseProjectionMismatch() throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        _ = try slide.shapes.addTable(rows: 1, columns: 1, frame: Rect(x: .inches(0), y: .inches(0), width: .inches(2), height: .inches(1))).setContents([["KNOWN TEXT"]])
        let dom = try slide.part.dom()
        let paragraph = try #require(dom.firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.firstChild(named: "p:graphicFrame")?.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?.firstChild(named: "a:tbl")?.firstChild(named: "a:tr")?.firstChild(named: "a:tc")?.firstChild(named: "a:txBody")?.firstChild(named: "a:p"))
        paragraph.appendElement(try xml("<d:r xmlns:d=\"\(drawing)\"><d:t> ALIASED FIELD</d:t></d:r>"))
        paragraph.appendElement(try xml("<a:r xmlns:a=\"urn:foreign\"><a:t>FOREIGN LOOKALIKE</a:t></a:r>"))
        slide.part.markDirty()
        try withFile(try deck.serializedData()) { source, output, bytes in
            let inspection = try DeckInspector.inspect(deckAt: source, renderPreviews: false)
            #expect(inspection.slides[0].tables[0].rows == [["KNOWN TEXT ALIASED FIELD"]])
            let outcome = try DeckExporter.export(deckAt: source, into: output)
            let markdown = try String(contentsOf: outcome.markdownFile, encoding: .utf8)
            #expect(markdown.contains("KNOWN TEXT ALIASED FIELD"))
            #expect(outcome.warnings.contains { $0.contains("ordinary table outline differs") })
            #expect(try Data(contentsOf: source) == bytes)
        }
    }

    @Test func columnCountIsInitializedOnceForRaggedAndEmptyInspectionValues() {
        let ragged = TableInspection(index: 7, rows: [["a"], ["b", "c"]])
        #expect(ragged.columnCount == 2 && ragged.index == 7)
        #expect(TableInspection(index: 0, rows: []).columnCount == 0)
    }

    @Test(arguments: [false, true])
    func inspectionAndExportRefuseOversizedDenseProjectionBeforeWriting(foreignNamespace: Bool) throws {
        let deck = try Presentation(), slide = try deck.slides[0]
        _ = try slide.shapes.addTable(rows: 1, columns: 1, frame: Rect(x: .inches(0), y: .inches(0), width: .inches(2), height: .inches(1)))
        let table = try #require(try slide.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.firstChild(named: "p:graphicFrame")?.firstChild(named: "a:graphic")?.firstChild(named: "a:graphicData")?.firstChild(named: "a:tbl"))
        if foreignNamespace { table[attribute: "xmlns:a"] = "urn:foreign" }
        let grid = try #require(table.firstChild(named: "a:tblGrid"))
        grid.children = (0..<1001).map { _ in .element(XML.Element("a:gridCol", attributes: [("w", "1")])) }
        table.children.removeAll { if case .element(let element) = $0 { return element.name == "a:tr" }; return false }
        for _ in 0..<1001 { table.appendElement(XML.Element("a:tr", attributes: [("h", "1")])) }
        slide.part.markDirty()
        try withFile(try deck.serializedData()) { source, output, bytes in
            #expect(throws: TableTextExtractor.BudgetError.self) { try DeckInspector.inspect(deckAt: source, renderPreviews: false) }
            #expect(throws: TableTextExtractor.BudgetError.self) { try DeckExporter.export(deckAt: source, into: output) }
            #expect(!FileManager.default.fileExists(atPath: output.appendingPathComponent("deck").path))
            let preserved = try Data(contentsOf: source)
            #expect(preserved == bytes)
        }
    }

    private func xml(_ text: String) throws -> XML.Element { try XML.parse(Data(text.utf8)) }

    private func renameDrawing(in root: XML.Element) {
        var pending: [(XML.Element, [String: String])] = [(root, ["a": drawing])]
        while let (element, inherited) = pending.popLast() {
            var scope = inherited
            for (name, value) in element.attributes where name.hasPrefix("xmlns:") { scope[String(name.dropFirst(6))] = value }
            if element.name.hasPrefix("a:"), scope["a"] == drawing {
                element.name = "d:" + element.name.dropFirst(2)
            }
            pending += element.childElements.map { ($0, scope) }
        }
    }

    private func withFile(_ data: Data, body: (URL, URL, Data) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lectern-tables-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("deck.pptx"), output = root.appendingPathComponent("Export")
        try data.write(to: source)
        try body(source, output, data)
    }
}
