import Foundation
import Testing
@testable import Rostrum

@Suite struct DeckMergeTests {
    private var pngFixture: Data {
        var b: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        func be32(_ v: Int) -> [UInt8] { [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
        // One append per field: long `[UInt8] + … + …` chains can time out the
        // Swift type-checker on some toolchains.
        b += be32(13); b += Array("IHDR".utf8); b += be32(40); b += be32(30); b += [8, 6, 0, 0, 0]; b += be32(0)
        b += be32(0); b += Array("IEND".utf8); b += be32(0)
        return Data(b)
    }

    /// A source deck: slide 0 has a text box + picture, slide 1 has a chart.
    private func makeSource() throws -> Presentation {
        let deck = try Presentation()
        try deck.slides[0].shapes.addTextBox(Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(1)))
            .textFrame?.text = "Imported slide one"
        try deck.slides[0].shapes.addPicture(pngFixture, x: .inches(1), y: .inches(3))
        let s2 = try deck.slides.add(clonedFrom: deck.layout(type: "obj")!)
        try s2.shapes.addChart(.pie,
            data: ChartData(categories: ["X", "Y", "Z"], name: "Data", values: [3, 2, 1]),
            frame: Rect(x: .inches(2), y: .inches(2), width: .inches(6), height: .inches(4)))
        return deck
    }

    @Test func importSingleSlideBringsItsGraph() throws {
        let source = try makeSource()
        let dest = try Presentation()
        let before = dest.slides.count

        try dest.slides.import(from: source, at: 0)
        #expect(dest.slides.count == before + 1)

        let reopened = try Presentation(data: try dest.serializedData())
        #expect(reopened.slides.count == before + 1)
        // The imported slide's text and picture came along.
        let imported = try reopened.slides[reopened.slides.count - 1]
        #expect(imported.shapes.contains { $0.textFrame?.text == "Imported slide one" })
        let media = reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/media/") }
        #expect(media.count == 1)
        // Every rel target resolves to a real part (no danglers).
        for (_, part) in reopened.package.parts {
            for rel in part.rels.items where !rel.isExternal {
                let target = PackURI.resolve(target: rel.target, relativeTo: part.uri.baseURI)
                #expect(reopened.package.parts[target] != nil, "dangling rel to \(target)")
            }
        }
    }

    @Test func importChartSlideCopiesChartAndWorkbook() throws {
        let source = try makeSource()
        let dest = try Presentation()
        try dest.slides.import(from: source, at: 1)   // the chart slide

        let reopened = try Presentation(data: try dest.serializedData())
        let charts = reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/charts/") }
        let books = reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/embeddings/") }
        #expect(charts.count == 1 && books.count == 1)
        // The chart part's rId1 → workbook still resolves.
        let chart = try reopened.package.part(at: charts[0])
        #expect(chart.rels.relationship(withId: "rId1")?.type == RelType.package)
    }

    @Test func importAllDedupesSharedMaster() throws {
        let source = try makeSource()   // both slides share one master
        let dest = try Presentation()
        try dest.slides.importAll(from: source)

        let reopened = try Presentation(data: try dest.serializedData())
        // dest's original master + exactly one imported master (shared, deduped).
        let masters = reopened.package.parts.keys.filter { $0.value.hasPrefix("/ppt/slideMasters/") }
        #expect(masters.count == 2)
        // Every master in sldMasterIdLst resolves.
        let idLst = try reopened.presentationPart.dom().firstChild(named: "p:sldMasterIdLst")!
        #expect(idLst.childElements.count == 2)
        for entry in idLst.childElements {
            let rId = entry[attribute: "r:id"]!
            #expect(reopened.presentationPart.rels.relationship(withId: rId) != nil)
        }
    }

    /// The `sldMasterId`/`sldLayoutId` values share one global id namespace;
    /// a copied master must be renumbered off the source's ids, or PowerPoint
    /// silently "repairs" the deck. Assert uniqueness after import.
    private func allGlobalIds(_ p: Presentation) throws -> [Int] {
        var ids: [Int] = []
        if let list = try p.presentationPart.dom().firstChild(named: "p:sldMasterIdLst") {
            ids += list.childElements.compactMap { $0[attribute: "id"].flatMap(Int.init) }
        }
        for (uri, part) in p.package.parts where uri.value.hasPrefix("/ppt/slideMasters/") {
            if let list = try part.dom().firstChild(named: "p:sldLayoutIdLst") {
                ids += list.childElements.compactMap { $0[attribute: "id"].flatMap(Int.init) }
            }
        }
        return ids
    }

    @Test func importAllKeepsGlobalIdsUnique() throws {
        let source = try makeSource()
        let dest = try Presentation()
        try dest.slides.importAll(from: source)
        let ids = try allGlobalIds(try Presentation(data: try dest.serializedData()))
        #expect(Set(ids).count == ids.count, "duplicate global ids: \(ids.sorted())")
    }

    @Test func repeatedImportOfSameSourceKeepsGlobalIdsUnique() throws {
        // Two imports of the same source with independent copiers must not
        // collide on the source's original master/layout ids.
        let source = try makeSource()
        let dest = try Presentation()
        try dest.slides.import(from: source, at: 0)
        try dest.slides.import(from: source, at: 0)
        let ids = try allGlobalIds(try Presentation(data: try dest.serializedData()))
        #expect(Set(ids).count == ids.count, "duplicate global ids: \(ids.sorted())")
    }

    @Test func importPreservesCopiedBlobsVerbatim() throws {
        // The copied slide's blob must equal the source's (rIds preserved).
        let source = try makeSource()
        _ = try source.serializedData()   // flush the source's dirty parts
        let dest = try Presentation()
        let sourceBlob = try source.slides[0].part.blob
        try dest.slides.import(from: source, at: 0)
        let importedURI = dest.package.parts.keys
            .filter { $0.value.hasPrefix("/ppt/slides/") }
            .sorted { $0.value < $1.value }.last!
        #expect(try dest.package.part(at: importedURI).blob == sourceBlob)
    }
}
