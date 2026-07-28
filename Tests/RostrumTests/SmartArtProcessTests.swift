import Foundation
import Testing
@testable import Rostrum

/// Native SmartArt process layout (verified to open as editable SmartArt, no
/// repair, in PowerPoint 16.x + LibreOffice). Locks the part wiring, the layout
/// identity, and that the demo's `.process` diagrams become real SmartArt.
@Suite struct SmartArtProcessTests {
    @Test func processSlideEmitsNativeProcessSmartArt() throws {
        let deck = try Presentation()
        _ = try deck.smartArtSlide("Loop", kind: .process, items: ["Perceive", "Plan", "Act"])

        let reopened = try Presentation(data: try deck.serializedData())

        // The layout part is the process definition, drawn with homePlate arrows
        // (flat-left → point-right, so text never clips on the notch a chevron has).
        let layoutPart = try reopened.package.part(at: PackURI("/ppt/diagrams/layout1.xml"))
        let layout = try layoutPart.dom()
        #expect(layout[attribute: "uniqueId"] == SmartArt.Layout.process.urn)
        let layoutText = String(decoding: layoutPart.blob, as: UTF8.self)
        #expect(layoutText.contains("type=\"homePlate\""))
        #expect(layoutText.contains("linDir") && layoutText.contains("fromL"))   // horizontal

        // All four sibling parts exist and the text round-trips through the model.
        for name in ["data", "layout", "quickStyle", "colors"] {
            _ = try reopened.package.part(at: PackURI("/ppt/diagrams/\(name)1.xml")).dom()
        }
        #expect(try reopened.slides[reopened.slides.count - 1].smartArtTexts == [["Perceive", "Plan", "Act"]])
    }

    @Test func cycleSlideEmitsNativeCycleSmartArt() throws {
        let deck = try Presentation()
        _ = try deck.smartArtSlide("Loop", kind: .cycle, items: ["Build", "Measure", "Learn"])

        let reopened = try Presentation(data: try deck.serializedData())
        let layoutPart = try reopened.package.part(at: PackURI("/ppt/diagrams/layout1.xml"))
        #expect(try layoutPart.dom()[attribute: "uniqueId"] == SmartArt.Layout.cycle.urn)
        let layoutText = String(decoding: layoutPart.blob, as: UTF8.self)
        #expect(layoutText.contains("type=\"cycle\""))     // ring algorithm
        #expect(layoutText.contains("type=\"ellipse\""))   // circular nodes
        #expect(layoutText.contains("type=\"conn\""))      // connectors between nodes
        #expect(try reopened.slides[reopened.slides.count - 1].smartArtTexts == [["Build", "Measure", "Learn"]])
    }

    @Test func defaultLayoutStaysBlockList() throws {
        // addSmartArt without a layout must remain the original Basic Block List
        // (back-compat for existing callers and flex.pptx).
        let deck = try Presentation()
        try deck.slides[0].shapes.addSmartArt(
            items: ["A", "B"], frame: Rect(x: .zero, y: .zero, width: .inches(6), height: .inches(4)))
        let layout = try deck.package.part(at: PackURI("/ppt/diagrams/layout1.xml")).dom()
        #expect(layout[attribute: "uniqueId"] == SmartArt.Layout.blockList.urn)
    }

    @Test func nodeTextColorContrastsWithItsFill() throws {
        // A pale block must get dark text, a dark block light text — so a light
        // brand accent never yields the white-on-pale we saw in QA.
        let xml = try XML.parse(Data(SmartArt.colorsXML(
            nodeColors: [Color("FFEB3B"), Color("102A43")]).utf8))
        let node1 = try #require(xml.children(named: "dgm:styleLbl")
            .first { $0[attribute: "name"] == "node1" })
        let tx = try #require(node1.firstChild(named: "dgm:txFillClrLst"))
        #expect(tx[attribute: "meth"] == "cycle")
        let vals = tx.children(named: "a:srgbClr").compactMap { $0[attribute: "val"] }
        #expect(vals.count == 2)
        #expect(Color(vals[0]).relativeLuminance < 0.5)   // dark text on the light yellow
        #expect(Color(vals[1]).relativeLuminance > 0.5)   // light text on the dark navy
    }

    @Test func everyLayoutXMLIsWellFormedAndSelfIdentifies() throws {
        for layout in SmartArt.Layout.allCases {
            let root = try XML.parse(Data(layout.layoutXML.utf8))
            #expect(root[attribute: "uniqueId"] == layout.urn)
        }
    }
}
