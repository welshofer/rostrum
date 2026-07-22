import Foundation
import Testing
@testable import Rostrum

@Suite struct SlidesCollectionTests {
    @Test func addAppendsSlides() throws {
        let deck = try Presentation()
        #expect(deck.slides.count == 1)
        let s2 = try deck.slides.add()
        let s3 = try deck.slides.add()
        #expect(deck.slides.count == 3)
        #expect(s2.part.uri.value == "/ppt/slides/slide2.xml")
        #expect(s3.part.uri.value == "/ppt/slides/slide3.xml")

        // Persists through save/reopen with resolvable parts.
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slides.count == 3)
        for slide in reopened.slides {
            #expect(slide.part.contentType == ContentType.slide)
        }
    }

    @Test func removeDropsEntryRelAndPart() throws {
        let deck = try Presentation()
        try deck.slides.add()
        try deck.slides.remove(at: 0)
        #expect(deck.slides.count == 1)
        #expect(deck.package.parts[PackURI("/ppt/slides/slide1.xml")] == nil)

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.slides.count == 1)
    }

    @Test func moveReorders() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
            .textFrame?.text = "first"
        try deck.slides.add().shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
            .textFrame?.text = "second"
        try deck.slides.move(from: 1, to: 0)

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.slides[0].shapes[0].textFrame?.text == "second")
        #expect(try reopened.slides[1].shapes[0].textFrame?.text == "first")
    }

    @Test func duplicateCopiesContentAfterSource() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .inches(2), height: .inches(1)))
            .textFrame?.text = "original"
        try deck.slides.add()
        try deck.slides.duplicate(at: 0)

        #expect(deck.slides.count == 3)
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.slides[0].shapes[0].textFrame?.text == "original")
        #expect(try reopened.slides[1].shapes[0].textFrame?.text == "original")
        #expect(try reopened.slides[1].part.uri != try reopened.slides[0].part.uri)
        // Unique sldIds across the deck.
        let ids = try reopened.presentationPart.dom()
            .firstChild(named: "p:sldIdLst")!.childElements
            .compactMap { $0[attribute: "id"] }
        #expect(Set(ids).count == 3)
    }
}

@Suite struct PristineRoundTripTests {
    @Test func untouchedDeckSerializesByteIdentical() throws {
        let original = try Presentation().serializedData()
        let reopened = try Presentation(data: original)
        // No mutations: every byte identical, whole file.
        #expect(try reopened.serializedData() == original)
    }

    @Test func mutationDirtiesOnlyTheTouchedPart() throws {
        let deck = try Presentation()
        try deck.slides.add()
        let original = try deck.serializedData()

        let reopened = try Presentation(data: original)
        try reopened.slides[1].shapes.all.first?.textFrame?.text = "touched"
        try reopened.slides[1].shapes.addTextBox(
            Rect(x: .zero, y: .zero, width: .inches(3), height: .inches(1)))
            .textFrame?.text = "touched"
        let mutated = try reopened.serializedData()

        let before = try ZipReader(data: original)
        let after = try ZipReader(data: mutated)
        for name in before.entryNames where name != "ppt/slides/slide2.xml" {
            #expect(try after.data(forEntry: name) == before.data(forEntry: name),
                    "untouched part \(name) must re-emit original bytes")
        }
        #expect(try after.data(forEntry: "ppt/slides/slide2.xml")
             != before.data(forEntry: "ppt/slides/slide2.xml"))
    }
}

@Suite struct ShapeAndTextTests {
    private func newSlide() throws -> (Presentation, Slide) {
        let deck = try Presentation()
        return (deck, try deck.slides[0])
    }

    @Test func textBoxRoundTripsRichText() throws {
        let (deck, slide) = try newSlide()
        let box = try slide.shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(2)))
        let frame = box.textFrame!
        frame.clear()
        let para = frame.addParagraph()
        para.alignment = .center
        let run = para.addRun("Big & Bold")
        run.fontSize = 44
        run.bold = true
        run.fontName = "Avenir Next"
        run.color = Color("FF6B5E")

        let reopened = try Presentation(data: try deck.serializedData())
        let rrun = try reopened.slides[0].shapes[0].textFrame!.paragraphs[0].runs[0]
        #expect(rrun.text == "Big & Bold")
        #expect(rrun.fontSize == 44)
        #expect(rrun.bold)
        #expect(rrun.fontName == "Avenir Next")
        #expect(rrun.color == Color("FF6B5E"))
        #expect(try reopened.slides[0].shapes[0].textFrame!.paragraphs[0].alignment == .center)
    }

    @Test func autoshapeGeometryFillLine() throws {
        let (deck, slide) = try newSlide()
        let shape = try slide.shapes.addShape(
            .roundedRectangle,
            frame: Rect(x: .inches(2), y: .inches(2), width: .inches(4), height: .inches(2)),
            fill: .solid(Color("0FA3A3")),
            line: Line(color: .white, width: .points(2)))
        shape.enableSoftShadow()

        let reopened = try Presentation(data: try deck.serializedData())
        let sp = try reopened.slides[0].spTree().children(named: "p:sp")[0]
        let spPr = sp.firstChild(named: "p:spPr")!
        #expect(spPr.firstChild(named: "a:prstGeom")?[attribute: "prst"] == "roundRect")
        #expect(spPr.firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr")?[attribute: "val"] == "0FA3A3")
        #expect(spPr.firstChild(named: "a:ln")?[attribute: "w"] == String(EMU.points(2).rawValue))
        #expect(spPr.firstChild(named: "a:effectLst")?.firstChild(named: "a:outerShdw") != nil)
        // Fill precedes line, line precedes effects (schema order).
        let names = spPr.childElements.map(\.name)
        #expect(names.firstIndex(of: "a:solidFill")! < names.firstIndex(of: "a:ln")!)
        #expect(names.firstIndex(of: "a:ln")! < names.firstIndex(of: "a:effectLst")!)
    }

    @Test func gradientBackgroundIsFirstChildOfCSld() throws {
        let (deck, slide) = try newSlide()
        try slide.setBackground(.gradient(GradientFill(
            from: Color("0A1A2F"), to: Color("14344F"))))

        let reopened = try Presentation(data: try deck.serializedData())
        let cSld = try reopened.slides[0].cSld()
        #expect(cSld.childElements.first?.name == "p:bg")
        let gradFill = cSld.childElements.first?
            .firstChild(named: "p:bgPr")?.firstChild(named: "a:gradFill")
        #expect(gradFill != nil)
        #expect(gradFill?.firstChild(named: "a:gsLst")?.childElements.count == 2)
    }

    @Test func shapeFrameAndRotationReadBack() throws {
        let (deck, slide) = try newSlide()
        let shape = try slide.shapes.addShape(
            .ellipse,
            frame: Rect(x: .inches(1), y: .inches(2), width: .inches(3), height: .inches(3)),
            fill: .solidAlpha(Color("FFB454"), 0.6))
        shape.rotation = 45
        _ = deck

        #expect(shape.frame.x == .inches(1))
        #expect(shape.frame.height == .inches(3))
        #expect(shape.rotation == 45)
        shape.frame = Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1))
        #expect(shape.frame.width == .inches(1))
    }

    @Test func roundedRectCornerRadiusClampsToPill() throws {
        let (deck, slide) = try newSlide()
        // Radius far exceeding half the short side → clamped to 50% (pill).
        let pill = try slide.shapes.addRoundedRectangle(
            Rect(x: .zero, y: .zero, width: .inches(3), height: .inches(0.4)),
            cornerRadius: .inches(5), fill: .solid(.black))
        // Modest radius → proportional adj.
        let card = try slide.shapes.addRoundedRectangle(
            Rect(x: .zero, y: .inches(1), width: .inches(4), height: .inches(2)),
            cornerRadius: .inches(0.2), fill: .solid(.white))
        _ = deck
        func adj(_ s: Shape) -> String? {
            s.element.firstChild(named: "p:spPr")?.firstChild(named: "a:prstGeom")?
                .firstChild(named: "a:avLst")?.firstChild(named: "a:gd")?[attribute: "fmla"]
        }
        #expect(adj(pill) == "val 50000")
        // 0.2" of a 2" short side = 10%.
        #expect(adj(card) == "val 10000")
    }

    @Test func shapeIDsUniquePerSlide() throws {
        let (deck, slide) = try newSlide()
        for _ in 0..<5 {
            try slide.shapes.addShape(
                .rectangle,
                frame: Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1)),
                fill: .solid(.black))
        }
        _ = deck
        let dom = try slide.part.dom()
        var ids: [String] = []
        var stack = [dom]
        while let el = stack.popLast() {
            if el.name == "p:cNvPr", let id = el[attribute: "id"] { ids.append(id) }
            stack.append(contentsOf: el.childElements)
        }
        #expect(Set(ids).count == ids.count)
    }
}
