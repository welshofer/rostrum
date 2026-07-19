import Foundation
import Testing
@testable import Rostrum

@Suite struct ZZReproTest {
    private func newBox() throws -> (Presentation, TextFrame) {
        let deck = try Presentation()
        let box = try deck.slides[0].shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(4)))
        return (deck, box.textFrame!)
    }

    @Test func reproBulletThenSpacing() throws {
        let (_, tf) = try newBox()
        let p = tf.addParagraph()
        p.setBullet()
        p.setSpacing(beforePoints: 6)
        let names = p.p.firstChild(named: "a:pPr")!.childElements.map(\.name)
        print("REPRO-ORDER-BEF: \(names)")
    }

    @Test func reproNumberedThenSpacingAfter() throws {
        let (_, tf) = try newBox()
        let p = tf.addParagraph()
        p.setNumbered()
        p.setSpacing(afterPoints: 6)
        let names = p.p.firstChild(named: "a:pPr")!.childElements.map(\.name)
        print("REPRO-ORDER-AFT: \(names)")
    }
}
