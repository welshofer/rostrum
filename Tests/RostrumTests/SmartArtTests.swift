import Foundation
import Testing
@testable import Rostrum

@Suite struct SmartArtTests {
    @Test func quadrupletPartsRelsAndFrame() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addSmartArt(
            items: ["Plan", "Build", "Ship"],
            frame: Rect(x: .inches(2), y: .inches(1), width: .inches(9), height: .inches(5)))

        let reopened = try Presentation(data: try deck.serializedData())
        for (name, ct) in [
            ("data", SmartArt.dataContentType),
            ("layout", SmartArt.layoutContentType),
            ("quickStyle", SmartArt.quickStyleContentType),
            ("colors", SmartArt.colorsContentType),
        ] {
            let part = try reopened.package.part(at: PackURI("/ppt/diagrams/\(name)1.xml"))
            #expect(part.contentType == ct)
            _ = try part.dom()  // well-formed
        }

        // dgm:relIds resolves all four through the slide's rels.
        let relIds = try reopened.slides[0].spTree()
            .firstChild(named: "p:graphicFrame")!
            .firstChild(named: "a:graphic")!.firstChild(named: "a:graphicData")!
            .firstChild(named: "dgm:relIds")!
        let rels = reopened.slides[0].part.rels
        #expect(rels.relationship(withId: relIds[attribute: "r:dm"]!)?.type == SmartArt.dataRelType)
        #expect(rels.relationship(withId: relIds[attribute: "r:lo"]!)?.type == SmartArt.layoutRelType)
        #expect(rels.relationship(withId: relIds[attribute: "r:qs"]!)?.type == SmartArt.quickStyleRelType)
        #expect(rels.relationship(withId: relIds[attribute: "r:cs"]!)?.type == SmartArt.colorsRelType)
    }

    @Test func dataModelStructureForNItems() throws {
        let xml = try XML.parse(Data(SmartArt.dataModelXML(items: ["A", "B", "C", "D"]).utf8))
        let pts = xml.firstChild(named: "dgm:ptLst")!.children(named: "dgm:pt")
        let cxns = xml.firstChild(named: "dgm:cxnLst")!.children(named: "dgm:cxn")

        // 1 doc + 4 items + 4 parTrans + 4 sibTrans + 1 presRoot + 4 presNodes + 3 spacers.
        #expect(pts.count == 1 + 4 + 8 + 1 + 4 + 3)
        // 4 parOf + 1 doc-presOf + 4 item-presOf + 7 presParOf.
        #expect(cxns.count == 4 + 1 + 4 + 7)

        // Unique modelIds across points and connections.
        let ids = pts.compactMap { $0[attribute: "modelId"] } + cxns.compactMap { $0[attribute: "modelId"] }
        #expect(Set(ids).count == ids.count)

        // parTrans/sibTrans point back at their cxn, which points back at them.
        let parOf = cxns.filter { $0[attribute: "type"] == nil }
        for cxn in parOf {
            let cxnId = cxn[attribute: "modelId"]!
            let parTrans = pts.first { $0[attribute: "modelId"] == cxn[attribute: "parTransId"] }
            #expect(parTrans?[attribute: "cxnId"] == cxnId)
            #expect(parTrans?[attribute: "type"] == "parTrans")
        }

        // Pres cache: styleIdx 0..<n with styleCnt n; presParOf ordering alternates node/spacer.
        let presNodes = pts.filter { $0[attribute: "type"] == "pres" }
        let nodeLabels = presNodes.compactMap { $0.firstChild(named: "dgm:prSet")?[attribute: "presStyleIdx"] }
        #expect(nodeLabels == ["0", "1", "2", "3"])
        let presParOf = cxns.filter { $0[attribute: "type"] == "presParOf" }
        #expect(presParOf.compactMap { $0[attribute: "srcOrd"] } == (0...6).map(String.init))
    }

    @Test func textExtractionReadsBack() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addSmartArt(
            items: ["Reduce & Reuse", "Recycle"],
            frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(4)))
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slides[0].smartArtTexts == [["Reduce & Reuse", "Recycle"]])
    }

    @Test func multipleDiagramsNumberIndependently() throws {
        let deck = try Presentation()
        try deck.slides.add()
        try deck.slides[0].shapes.addSmartArt(items: ["A"], frame: Rect(x: .zero, y: .zero, width: .inches(4), height: .inches(3)))
        try deck.slides[1].shapes.addSmartArt(items: ["B"], frame: Rect(x: .zero, y: .zero, width: .inches(4), height: .inches(3)))
        #expect(deck.package.parts[PackURI("/ppt/diagrams/data2.xml")] != nil)
        #expect(deck.slides[1].smartArtTexts == [["B"]])
    }
}
