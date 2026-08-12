import Foundation
import Testing
@testable import Rostrum

@Suite struct LayoutTests {
    @Test func templateShipsFourLayouts() throws {
        let deck = try Presentation()
        let names = deck.layouts.map(\.name)
        #expect(names == ["Blank", "Title Slide", "Title and Content", "Section Header"])
        #expect(deck.layout(type: "title")?.name == "Title Slide")
        #expect(deck.layout(named: "Blank")?.type == "blank")
    }

    @Test func addWithTitleLayoutClonesPlaceholders() throws {
        let deck = try Presentation()
        let slide = try deck.slides.add(clonedFrom: deck.layout(type: "title")!)

        let phs = slide.placeholders.compactMap(\.placeholder)
        #expect(phs.map(\.type) == ["ctrTitle", "subTitle"])
        #expect(phs.map(\.idx) == [0, 1])

        // Clones are minimal: empty spPr (geometry inherits), empty text body.
        for sp in try slide.spTree().children(named: "p:sp") {
            #expect(sp.firstChild(named: "p:spPr")?.childElements.isEmpty == true)
            #expect(sp.firstChild(named: "p:txBody")?.textContent == "")
        }
    }

    @Test func titleAccessorMatchesIdxZeroAnyTitleType() throws {
        let deck = try Presentation()
        let slide = try deck.slides.add(clonedFrom: deck.layout(type: "title")!)
        slide.title?.textFrame?.text = "Hello from the placeholder"

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.slides[1].title?.textFrame?.text == "Hello from the placeholder")
        #expect(try reopened.slides[1].title?.placeholder?.type == "ctrTitle")
    }

    @Test func effectiveFrameResolvesThroughLayoutToMaster() throws {
        let deck = try Presentation()
        // Title Slide layout: explicit layout geometry wins.
        let title = try deck.slides.add(clonedFrom: deck.layout(type: "title")!)
        let titleFrame = title.effectiveFrame(of: title.title!)
        #expect(titleFrame?.x == EMU(1_524_000))
        #expect(titleFrame?.height == EMU(1_470_025))

        // Title and Content layout has no geometry: falls through to master.
        let content = try deck.slides.add(clonedFrom: deck.layout(type: "obj")!)
        let bodyFrame = content.effectiveFrame(of: content.placeholder(idx: 1)!)
        #expect(bodyFrame?.x == EMU(609_600))
        #expect(bodyFrame?.y == EMU(1_600_200))
        #expect(bodyFrame?.height == EMU(4_800_600))

        // A plain shape with its own xfrm reports it unchanged.
        let box = try content.shapes.addTextBox(
            Rect(x: .inches(2), y: .inches(2), width: .inches(3), height: .inches(1)))
        #expect(content.effectiveFrame(of: box)?.x == .inches(2))
    }

    @Test func untypedPhDefaultsToObjAndClones() throws {
        let deck = try Presentation()
        let slide = try deck.slides.add(clonedFrom: deck.layout(type: "obj")!)
        let content = slide.placeholder(idx: 1)
        #expect(content?.placeholder?.type == "obj")
        // The clone kept the idx attribute but no type attribute (default
        // omission preserved from the layout's own serialization).
        let ph = Placeholders.phElement(of: content!.element)
        #expect(ph?[attribute: "type"] == nil)
        #expect(ph?[attribute: "idx"] == "1")
    }
}
