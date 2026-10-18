import Foundation
import Testing
import Rostrum
@testable import RostrumLayout

@Suite struct PanelLayoutTests {
    @Test(arguments: PanelKind.allCases)
    func measuredEditablePanelsAndAtomicRefusal(_ kind: PanelKind) throws {
        let deck = try Presentation()
        let fonts = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts")
        for name in ["DejaVuSans", "DejaVuSans-Bold"] {
            try deck.fonts.register(contentsOf: fonts.appendingPathComponent(name + ".ttf"))
        }
        var style = deck.style
        style.type = style.type.overriding(.heading) { $0.font = "DejaVu Sans" }
            .overriding(.body) { $0.font = "DejaVu Sans" }
        let slide = try deck.slides.add()
        let engine = TemplateLayoutEngine(presentation: deck)
        let region = Rect(x: .points(40), y: .points(100), width: .points(640), height: .points(360))
        let items = (1...3).map { StructuredItem("Heading \($0)", detail: "Exact supporting words \($0).") }
        let frames = try PanelLayout.frames(kind: kind, count: 3, in: region, scale: engine.objectScale)
        #expect(frames.count == 3)
        for frame in frames { #expect(frame.x >= region.x && frame.y >= region.y && frame.maxX <= region.maxX && frame.maxY <= region.maxY) }
        _ = try PanelLayout.compose(kind: kind, items: items, in: region, on: slide, style: style, engine: engine)
        for shape in slide.shapes.all {
            if shape.textFrame?.text.isEmpty == false, let body = shape.element.firstChild(named: "p:txBody"), let frame = slide.effectiveFrame(of: shape) {
                let layout = RichTextLayout(textBody: body, width: frame.width.points, height: frame.height.points,
                    fonts: deck.fonts, theme: deck.theme)
                #expect(layout.fits, "\(shape.textFrame?.text ?? "") must fit its saved frame")
            }
        }
        let data = try deck.serializedData()
        let saved = try Presentation(data: data)
        for item in items { #expect(saved.outline().markdown().contains(item.heading) && saved.outline().markdown().contains(item.detail)) }
        let before = try deck.serializedData()
        let tooLong = [StructuredItem("Too much", detail: String(repeating: "Original words ", count: 500))] + Array(items.dropFirst())
        #expect(throws: LayoutError.self) { try PanelLayout.compose(kind: kind, items: tooLong, in: region, on: slide, style: style, engine: engine) }
        #expect(try deck.serializedData() == before)
        #expect(throws: LayoutError.self) { try PanelLayout.frames(kind: kind, count: 1, in: region) }
    }
}
