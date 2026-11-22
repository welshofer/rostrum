import Foundation
import Testing
@testable import Rostrum

@Suite struct PictureBulletLayoutTests {
    private static let minimalPNG = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )!

    private static func registerTestFonts(on deck: Presentation) throws {
        let fontBytes = try Data(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures/Typography/DejaVuSans.ttf")
        )
        try deck.fonts.register(fontBytes, aliases: ["Calibri", "Arial"])
    }

    @Test func wrappedParagraphAndInheritedBulletsAlignBlipToParagraphFirstLineWithoutMarkerCollision() throws {
        let deck = try Presentation()
        try Self.registerTestFonts(on: deck)
        let slide = try deck.slides[0]

        // Configure layout body placeholder with level-1 a:buChar ("•") and level-2 a:buAutoNum.
        let layoutPart = try slide.part.related(by: RelType.slideLayout, in: deck.package)
        let layoutTree = try #require(Slide.existingSpTree(of: layoutPart))
        let layoutBody = XML.Element("p:sp", children: [
            .element(XML.Element("p:nvSpPr", children: [
                .element(XML.Element("p:cNvPr", attributes: [("id", "2"), ("name", "Content Placeholder 1")])),
                .element(XML.Element("p:cNvSpPr")),
                .element(XML.Element("p:nvPr", children: [
                    .element(XML.Element("p:ph", attributes: [("type", "body"), ("idx", "1")])),
                ])),
            ])),
            .element(XML.Element("p:spPr")),
            .element(XML.Element("p:txBody", children: [
                .element(XML.Element("a:bodyPr")),
                .element(XML.Element("a:lstStyle", children: [
                    .element(XML.Element("a:lvl1pPr", attributes: [
                        ("marL", "342900"), ("indent", "-342900"),
                    ], children: [
                        .element(XML.Element("a:buChar", attributes: [("char", "•")])),
                    ])),
                    .element(XML.Element("a:lvl2pPr", attributes: [
                        ("marL", "457200"), ("indent", "-228600"),
                    ], children: [
                        .element(XML.Element("a:buAutoNum", attributes: [("type", "arabicPeriod")])),
                    ])),
                ])),
                .element(XML.Element("a:p")),
            ])),
        ])
        layoutTree.appendElement(layoutBody)
        layoutPart.markDirty()

        let boxFrame = Rect(x: .inches(1), y: .inches(1), width: .inches(2.2), height: .inches(5.5))
        let box = try slide.shapes.addTextBox(boxFrame)
        let nvPr = try #require(box.element.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr"))
        nvPr.appendElement(XML.Element("p:ph", attributes: [("type", "body"), ("idx", "1")]))
        slide.part.markDirty()

        let tf = try #require(box.textFrame)
        tf.clear()

        // Paragraph 0: wraps across >= 3 lines and inherits "•".
        let p0 = tf.addParagraph()
        let r0 = p0.addRun("Alpha bravo charlie delta echo foxtrot golf hotel india juliet")
        r0.fontSize = 18

        // Paragraph 1: overrides inherited "•" with a picture bullet and includes an interior <a:br/>.
        let p1 = tf.addParagraph()
        try p1.setPictureBullet(Self.minimalPNG)
        let r1a = p1.addRun("Second item")
        r1a.fontSize = 18
        p1.p.insertChild(XML.Element("a:br"), beforeAnyOf: ["a:endParaRPr"])
        let r1b = p1.addRun("After hard break")
        r1b.fontSize = 18

        // Paragraph 2: empty picture-bullet paragraph emits no orphan <image>.
        let p2 = tf.addParagraph()
        try p2.setPictureBullet(Self.minimalPNG)

        // Paragraph 3 (level 1 -> lvl2pPr): overrides inherited a:buAutoNum ("1.") with a picture bullet.
        let p3 = tf.addParagraph()
        p3.indentLevel = 1
        try p3.setPictureBullet(Self.minimalPNG)
        let r3 = p3.addRun("Overrides numbered")
        r3.fontSize = 18

        // Paragraph 4: inherits "•" again after the picture-bullet paragraphs.
        let p4 = tf.addParagraph()
        let r4 = p4.addRun("Fifth item")
        r4.fontSize = 18

        let report = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(report.problems.isEmpty, "Unexpected render problems: \(report.problems.messages)")

        let root = try XML.parse(Data(report.svg.utf8))
        var blipImages: [XML.Element] = []
        var textNodes: [XML.Element] = []
        var stack: [XML.Element] = [root]
        while let node = stack.popLast() {
            if node.name == "image", node[attribute: "data-rostrum-bullet"] == "blip" {
                blipImages.append(node)
            } else if node.name == "text" {
                textNodes.append(node)
            }
            stack.append(contentsOf: node.childElements.reversed())
        }

        // Only paragraphs 1 and 3 emit picture bullets (1 blip each, despite p1's <a:br/> and p2 being empty).
        #expect(blipImages.count == 2)

        let p1LineIndex = try #require(textNodes.firstIndex(where: { $0.textContent.contains("Second item") }))
        #expect(p1LineIndex >= 3)
        #expect(!textNodes[p1LineIndex].textContent.contains("•"))
        #expect(textNodes[0].textContent.contains("•"))

        let p3LineIndex = try #require(textNodes.firstIndex(where: { $0.textContent.contains("Overrides") }))
        #expect(!textNodes[p3LineIndex].textContent.contains("1."))
        #expect(!textNodes[p3LineIndex].textContent.contains("•"))
        #expect(!textNodes.contains(where: { $0.textContent.contains("1.") }))

        let p4Line = try #require(textNodes.first(where: { $0.textContent.contains("Fifth item") }))
        #expect(p4Line.textContent.contains("•"))

        func translateY(of textEl: XML.Element) -> Double? {
            guard let tr = textEl[attribute: "transform"],
                  let comma = tr.firstIndex(of: ","),
                  let close = tr[comma...].firstIndex(of: ")") else { return nil }
            return Double(tr[tr.index(after: comma)..<close])
        }
        let line1BaselineY = try #require(translateY(of: textNodes[1]))
        let p1BaselineY = try #require(translateY(of: textNodes[p1LineIndex]))
        let p3BaselineY = try #require(translateY(of: textNodes[p3LineIndex]))
        let blip0Y = try #require(blipImages[0][attribute: "y"].flatMap(Double.init))
        let blip0H = try #require(blipImages[0][attribute: "height"].flatMap(Double.init))
        let blip1Y = try #require(blipImages[1][attribute: "y"].flatMap(Double.init))
        let blip1H = try #require(blipImages[1][attribute: "height"].flatMap(Double.init))

        #expect(abs(blip0Y - (p1BaselineY.rounded() - (blip0H * 0.85).rounded())) <= 2)
        #expect(blip0Y > line1BaselineY)
        #expect(abs(blip1Y - (p3BaselineY.rounded() - (blip1H * 0.85).rounded())) <= 2)
    }

    @Test func bodyLstStyleBlipSupportsLocalOverridesPositiveFirstLineIndentAndOtherStyleExclusion() throws {
        let deck = try Presentation()
        try Self.registerTestFonts(on: deck)
        let slide = try deck.slides[0]

        // 1. Seed a picture bullet in txBody/a:lstStyle and override locally with buNone, buChar, and buAutoNum.
        let box = try slide.shapes.addTextBox(
            Rect(x: .inches(0.5), y: .inches(0.5), width: .inches(3.0), height: .inches(4.0))
        )
        let tf = try #require(box.textFrame)
        tf.clear()

        let seed = tf.addParagraph()
        try seed.setPictureBullet(Self.minimalPNG)
        let seededBlip = try #require(seed.p.firstChild(named: "a:pPr")?.firstChild(named: "a:buBlip")?.deepCopy())
        seed.p.removeChildren(named: "a:pPr")
        let lstStyle = try #require(box.element.firstChild(named: "p:txBody")?.firstChild(named: "a:lstStyle"))
        lstStyle.appendElement(XML.Element("a:lvl1pPr", attributes: [
            ("marL", "0"), ("indent", "228600"), // +18pt positive first-line indent
        ], children: [.element(seededBlip)]))

        // Paragraph 0 inherits txBody/a:lstStyle a:buBlip and wraps: line 0 gets +18pt indent, line 1 returns to marL (0).
        let r0 = seed.addRun("Inherited list-style picture bullet wrapping onto continuation line")
        r0.fontSize = 18

        // Paragraph 1 overrides inherited a:buBlip with a:buNone.
        let pNone = tf.addParagraph()
        pNone.setNoBullet()
        pNone.addRun("No bullet override").fontSize = 18

        // Paragraph 2 overrides inherited a:buBlip with a:buChar.
        let pChar = tf.addParagraph()
        pChar.setBullet("–")
        pChar.addRun("Dash bullet override").fontSize = 18

        // Paragraph 3 overrides inherited a:buBlip with a:buAutoNum.
        let pNum = tf.addParagraph()
        pNum.setNumbered("arabicPeriod")
        pNum.addRun("Numbered override").fontSize = 18

        // Check positive first-line indent resets to marL on wrapped continuation line of paragraph 0.
        let txBody = try #require(box.element.firstChild(named: "p:txBody"))
        let layout = RichTextLayout(
            textBody: txBody,
            width: 3.0 * 72.0,
            height: 4.0 * 72.0,
            fonts: deck.fonts
        )
        let p0Lines = layout.lines.filter { $0.paragraphIndex == 0 }
        #expect(p0Lines.count >= 2)
        let line0X = try #require(p0Lines[0].spans.first?.x)
        let line1X = try #require(p0Lines[1].spans.first?.x)
        #expect(abs((line0X - line1X) - 18.0) <= 0.5)

        // 2. Ordinary non-placeholder shape (ph == nil) must NOT inherit a:buBlip from master p:otherStyle.
        let layoutPart = try slide.part.related(by: RelType.slideLayout, in: deck.package)
        let masterPart = try layoutPart.related(by: RelType.slideMaster, in: deck.package)
        let masterDOM = try masterPart.dom()
        let txStyles = masterDOM.getOrAddChild("p:txStyles")
        txStyles.removeChildren(named: "p:otherStyle")
        txStyles.appendElement(XML.Element("p:otherStyle", children: [
            .element(XML.Element("a:lvl1pPr", attributes: [
                ("marL", "254000"), ("indent", "-127000"), // 20pt left, -10pt hanging -> 10pt first-line if unbulleted
            ], children: [
                .element(seededBlip.deepCopy()),
            ])),
        ]))
        masterPart.markDirty()

        let ordinaryBox = try slide.shapes.addTextBox(
            Rect(x: .inches(4.5), y: .inches(0.5), width: .inches(3.0), height: .inches(1.5))
        )
        let ordTF = try #require(ordinaryBox.textFrame)
        ordTF.clear()
        ordTF.addParagraph().addRun("Ordinary non-placeholder text").fontSize = 18
        let ordInherited = RichTextLayout.inheritedStyles(for: ordinaryBox.element, owner: slide.part, package: deck.package)
        let ordLayout = RichTextLayout(
            textBody: try #require(ordinaryBox.element.firstChild(named: "p:txBody")),
            width: 3.0 * 72.0,
            height: 1.5 * 72.0,
            fonts: deck.fonts,
            inheritedStyles: ordInherited
        )
        // Default left inset is 7.2pt + (20pt marL - 10pt indent) = 17.2pt (NOT 27.2pt!).
        let ordX = try #require(ordLayout.lines.first?.spans.first?.x)
        #expect(abs(ordX - 17.2) <= 0.5)

        let report = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(report.problems.isEmpty, "Unexpected render problems: \(report.problems.messages)")
        let root = try XML.parse(Data(report.svg.utf8))
        var blipCount = 0
        var renderedTexts: [String] = []
        var stack: [XML.Element] = [root]
        while let node = stack.popLast() {
            if node.name == "image", node[attribute: "data-rostrum-bullet"] == "blip" {
                blipCount += 1
            } else if node.name == "text" {
                renderedTexts.append(node.textContent)
            }
            stack.append(contentsOf: node.childElements)
        }
        // Only paragraph 0 of `box` emits a picture bullet; buNone, buChar, buAutoNum, and ordinaryBox do not.
        #expect(blipCount == 1)
        #expect(renderedTexts.contains(where: { $0.contains("–") }))
        #expect(renderedTexts.contains(where: { $0.contains("1.") }))
    }
}
