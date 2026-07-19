import Foundation
import Testing
@testable import Rostrum

@Suite struct TextRichnessTests {
    private func newBox() throws -> (Presentation, TextFrame) {
        let deck = try Presentation()
        let box = try deck.slides[0].shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(4)))
        return (deck, box.textFrame!)
    }

    @Test func bulletsAndNumberingRoundTrip() throws {
        let (deck, tf) = try newBox()
        tf.clear()
        let b = tf.addParagraph(); b.setBullet(); b.addRun("first")
        let n = tf.addParagraph(); n.setNumbered(); n.addRun("one")
        let sub = tf.addParagraph(); sub.indentLevel = 1; sub.setBullet("\u{2013}"); sub.addRun("nested")
        let none = tf.addParagraph(); none.setNoBullet(); none.addRun("plain")

        let reopened = try Presentation(data: try deck.serializedData())
        let ps = reopened.slides[0].shapes[0].textFrame!.paragraphs
        #expect(ps[0].p.firstChild(named: "a:pPr")?.firstChild(named: "a:buChar")?[attribute: "char"] == "\u{2022}")
        #expect(ps[1].p.firstChild(named: "a:pPr")?.firstChild(named: "a:buAutoNum")?[attribute: "type"] == "arabicPeriod")
        #expect(ps[2].indentLevel == 1)
        #expect(ps[2].p.firstChild(named: "a:pPr")?.firstChild(named: "a:buChar")?[attribute: "char"] == "\u{2013}")
        #expect(ps[3].p.firstChild(named: "a:pPr")?.firstChild(named: "a:buNone") != nil)
    }

    @Test func bulletChildrenAreInSchemaOrder() throws {
        let (_, tf) = try newBox()
        let p = tf.addParagraph()
        p.setLineSpacing(1.2)
        p.setBullet()
        // pPr order: lnSpc … buFont, buChar, then (tabLst/defRPr/extLst).
        let names = p.p.firstChild(named: "a:pPr")!.childElements.map(\.name)
        #expect(names.firstIndex(of: "a:lnSpc")! < names.firstIndex(of: "a:buFont")!)
        #expect(names.firstIndex(of: "a:buFont")! < names.firstIndex(of: "a:buChar")!)
    }

    @Test func runStylesRoundTrip() throws {
        let (deck, tf) = try newBox()
        tf.clear()
        let p = tf.addParagraph()
        let r = p.addRun("styled")
        r.underline = true
        r.strikethrough = true
        r.setSuperscript()

        let reopened = try Presentation(data: try deck.serializedData())
        let rr = reopened.slides[0].shapes[0].textFrame!.paragraphs[0].runs[0]
        #expect(rr.underline)
        #expect(rr.strikethrough)
        #expect(rr.baselinePercent == 30)
    }

    @Test func hyperlinkAddsRelAndReadsBack() throws {
        let (deck, tf) = try newBox()
        tf.clear()
        let p = tf.addParagraph()
        let link = p.addRun("Rostrum on GitHub")
        link.setHyperlink("https://github.com/welshofer/rostrum")

        // The run references a hyperlink rel that exists on the slide part.
        let rId = link.r.firstChild(named: "a:rPr")!.firstChild(named: "a:hlinkClick")![attribute: "r:id"]!
        #expect(deck.slides[0].part.rels.relationship(withId: rId)?.type == RelType.hyperlink)
        #expect(deck.slides[0].part.rels.relationship(withId: rId)?.isExternal == true)

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slides[0].shapes[0].textFrame!.paragraphs[0].runs[0].hyperlink
                == "https://github.com/welshofer/rostrum")
    }

    /// a:rPr children must follow CT_TextCharacterProperties order regardless of
    /// which setter is called first: a:solidFill … a:latin … a:hlinkClick.
    /// Applying hyperlink/color BEFORE the font used to append a:latin (and a
    /// partial successor list mis-placed a:solidFill) after a:hlinkClick —
    /// invalid OOXML that triggers a PowerPoint repair.
    @Test func runPropertyChildrenStayInSchemaOrderRegardlessOfCallOrder() throws {
        func indices(applying setters: (Run) -> Void) throws -> [String] {
            let (_, tf) = try newBox()
            tf.clear()
            let run = tf.addParagraph().addRun("link")
            setters(run)
            return run.r.firstChild(named: "a:rPr")!.childElements.map(\.name)
        }
        // Every permutation of {hyperlink, color, font} must yield the same order.
        let orderings: [(String, (Run) -> Void)] = [
            ("hyperlink→color→font", { $0.setHyperlink("https://example.com"); $0.color = Color("FF0000"); $0.fontName = "Arial" }),
            ("font→color→hyperlink", { $0.fontName = "Arial"; $0.color = Color("FF0000"); $0.setHyperlink("https://example.com") }),
            ("color→hyperlink→font", { $0.color = Color("FF0000"); $0.setHyperlink("https://example.com"); $0.fontName = "Arial" }),
        ]
        for (label, setters) in orderings {
            let names = try indices(applying: setters)
            let fill = names.firstIndex(of: "a:solidFill")!
            let latin = names.firstIndex(of: "a:latin")!
            let hlink = names.firstIndex(of: "a:hlinkClick")!
            #expect(fill < latin, "\(label): a:solidFill must precede a:latin — got \(names)")
            #expect(latin < hlink, "\(label): a:latin must precede a:hlinkClick — got \(names)")
        }
    }
}
