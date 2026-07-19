import Foundation
import Testing
@testable import Rostrum

@Suite struct ZZReproTests {
    @Test func hyperlinkThenFontNameOrder() throws {
        let deck = try Presentation()
        let box = try deck.slides[0].shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(4)))
        let tf = box.textFrame!
        tf.clear()
        let p = tf.addParagraph()
        let run = p.addRun("link")
        run.setHyperlink("https://example.com")
        run.fontName = "Arial"

        let rPr = run.r.firstChild(named: "a:rPr")!
        let names = rPr.childElements.map(\.name)
        print("REPRO rPr children order: \(names)")
        let latinIdx = names.firstIndex(of: "a:latin")
        let hlinkIdx = names.firstIndex(of: "a:hlinkClick")
        print("REPRO latinIdx=\(String(describing: latinIdx)) hlinkIdx=\(String(describing: hlinkIdx))")
        // Schema requires a:latin BEFORE a:hlinkClick.
        #expect(latinIdx! < hlinkIdx!)
    }
}
