import Foundation
import Testing
@testable import Rostrum

@Suite struct ShapeAppearanceTests {
    private let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(3), height: .inches(2))

    @Test func solidFillAndLineReadBack() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addShape(
            .rectangle, frame: frame, fill: .solid(Color("18A999")),
            line: Line(color: Color("0B1D33"), width: .points(3)))

        let reopened = try Presentation(data: try deck.serializedData())
        let shape = try reopened.slides[0].shapes[0]
        #expect(shape.fill == .solid(Color("18A999"), alpha: 1))
        #expect(shape.line?.color == Color("0B1D33"))
        #expect(shape.line?.width == EMU.points(3))
        #expect(shape.hasShadow == false)
    }

    @Test func alphaGradientImageAndNoneReadBack() throws {
        let deck = try Presentation()
        let shapes = try deck.slides[0].shapes
        try shapes.addShape(.rectangle, frame: frame, fill: .solidAlpha(Color("FF6B5E"), 0.5))
        try shapes.addShape(.ellipse, frame: frame, fill: .gradient(
            GradientFill(stops: [GradientStop(position: 0, color: Color("000000")),
                                 GradientStop(position: 1, color: Color("FFFFFF"))])))
        try shapes.addTextBox(frame)   // text boxes are written with a:noFill

        let reopened = try Presentation(data: try deck.serializedData())
        let all = try reopened.slides[0].shapes.all
        #expect(all[0].fill == .solid(Color("FF6B5E"), alpha: 0.5))
        guard case .gradient(let stops) = try #require(all[1].fill) else {
            Issue.record("expected a gradient fill"); return
        }
        #expect(stops.count == 2)
        #expect(stops.first?.color == Color("000000"))
        #expect(stops.last?.position == 1)
        // `.noFill` (explicit) is deliberately distinct from nil (inherits) —
        // and is named so it cannot be confused with `Optional.none`.
        #expect(all[2].fill == .noFill)
    }

    @Test func shadowAndSlideBackgroundReadBack() throws {
        let deck = try Presentation()
        try deck.slides[0].setBackground(.solid(Color("0B1D33")))
        let shape = try deck.slides[0].shapes.addShape(
            .rectangle, frame: frame, fill: .solid(Color("FFFFFF")))
        shape.enableSoftShadow()

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.slides[0].background == .solid(Color("0B1D33"), alpha: 1))
        #expect(try reopened.slides[0].shapes[0].hasShadow)
    }

    @Test func inheritedAppearanceReadsAsNilNotAsAGuess() throws {
        // A placeholder with no fill of its own inherits — reporting a color
        // there would be a lie. nil is the honest answer.
        let deck = try Presentation()
        let layout = try #require(deck.layout(type: "title"))
        let slide = try deck.slides.add(clonedFrom: layout)
        let placeholder = try #require(slide.shapes.all.first)
        #expect(placeholder.fill == nil)
        #expect(placeholder.line == nil)
        #expect(placeholder.hasShadow == false)
    }

    @Test func appearanceReadsNeverMutateTheDOM() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addShape(.rectangle, frame: frame, fill: .solid(Color("18A999")))
        let reopened = try Presentation(data: try deck.serializedData())
        let slide = try reopened.slides[0]

        let before = XML.document(try slide.part.dom())
        for shape in slide.shapes.all { _ = (shape.fill, shape.line, shape.hasShadow) }
        _ = slide.background
        #expect(XML.document(try slide.part.dom()) == before)
        #expect(!slide.part.isDirty)
    }

    @Test func tableCellFillReadsBack() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(
            rows: 2, columns: 2,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(6), height: .inches(2)))
        try table.cell(0, 0).setFill(.solid(Color("18A999")))

        let reopened = try Presentation(data: try deck.serializedData())
        let frameShape = try #require(reopened.slides[0].shapes.all.first { $0.kind == .table } as? TableFrame)
        let readTable = try #require(frameShape.table)
        #expect(try readTable.cell(0, 0).fill == .solid(Color("18A999"), alpha: 1))
        #expect(try readTable.cell(1, 1).fill == nil)
    }
}

@Suite struct SlideMasterTests {
    @Test func slideMastersExposeLayoutsAndTheme() throws {
        let deck = try Presentation()
        #expect(deck.slideMasters.count == 1)
        let master = try #require(deck.slideMasters.first)
        #expect(master.layouts.count == deck.layouts.count)
        #expect(master.layouts.map(\.name) == deck.layouts.map(\.name))
        #expect(master.theme != nil)
        #expect(deck.allLayouts.count == deck.layouts.count)
    }

    @Test func layoutsAndSlidesResolveTheirMaster() throws {
        let deck = try Presentation()
        let layout = try #require(deck.layout(type: "title"))
        #expect(layout.master?.part.uri == deck.slideMasters.first?.part.uri)

        let slide = try deck.slides.add(clonedFrom: layout)
        #expect(slide.layout?.name == layout.name)
        #expect(slide.master?.part.uri == deck.slideMasters.first?.part.uri)
    }

    @Test func multiMasterDecksExposeEveryMasterAndLayout() throws {
        // A deck merged from two sources carries both masters; `layouts` only
        // ever showed the first one's.
        let source = try Presentation()
        try source.bulletSlide("Imported", ["from another deck"])
        let deck = try Presentation()
        try deck.slides.importAll(from: source)

        let reopened = try Presentation(data: try deck.serializedData())
        // The point of the test: the merge produced a SECOND master, and the
        // API sees past the first. (`allLayouts.count == sum of per-master
        // counts` would be a tautology — it is defined that way.)
        #expect(reopened.slideMasters.count == 2,
                "importAll should bring the source's master with it")
        for master in reopened.slideMasters {
            #expect(!master.layouts.isEmpty, "a master exposed no layouts")
        }
        #expect(reopened.allLayouts.count > reopened.layouts.count,
                "allLayouts must span masters that `layouts` cannot see")
        #expect(reopened.layouts.count == reopened.slideMasters[0].layouts.count)
        // Every slide still resolves its own layout and master.
        for slide in reopened.slides {
            #expect(slide.layout != nil)
            #expect(slide.master != nil)
        }
    }

    @Test func masterEnumerationIsPristine() throws {
        let deck = try Presentation()
        let original = try deck.serializedData()
        let reopened = try Presentation(data: original)
        for master in reopened.slideMasters {
            _ = (master.name, master.theme?.majorFont)
            for layout in master.layouts { _ = (layout.name, layout.type, layout.master?.name) }
        }
        #expect(try reopened.serializedData() == original)
    }
}
