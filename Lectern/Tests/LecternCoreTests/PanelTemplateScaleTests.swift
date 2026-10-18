import Foundation
import Testing
import Rostrum
import RostrumLayout
@testable import LecternCore

@Suite struct PanelTemplateScaleTests {
    @Test(arguments: [100000, 85000])
    func continuationsKeepTheTemplatesExistingTextScale(storedScale: Int) throws {
        let source = try Presentation()
        source.documentKind = .template
        for part in source.package.parts.values where [ContentType.slideMaster, ContentType.slideLayout].contains(part.contentType) {
            let shapes = try part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.children(named: "p:sp") ?? []
            for shape in shapes {
                guard let type = shape.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph")?[attribute: "type"],
                      ["obj", "body"].contains(type), let body = shape.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr") else { continue }
                body.children.removeAll {
                    if case .element(let node) = $0 { return ["a:noAutofit", "a:spAutoFit", "a:normAutofit"].contains(node.name) }
                    return false
                }
                body.appendElement(XML.Element("a:normAutofit", attributes: [("fontScale", String(storedScale))]))
            }
            part.markDirty()
        }
        let template = try PowerPointTemplate(data: source.serializedData(), name: "Existing scale")
        let deck = try Presentation.fromTemplate(data: template.data)
        let text = String(repeating: "Every original word needs readable space. ", count: 50)
        let input = DeckIR(meta: Meta(title: "Full size"), slides: [IRSlide(id: "a", layout: "cards", title: "Evidence",
            body: Body(panels: [.init(heading: "First", detail: text), .init(heading: "Second", detail: text)]))])
        let engine = TemplateLayoutEngine(presentation: deck, measure: TemplateRendering.measurer)
        var warnings: [String] = []
        let prepared = try TemplateRendering.prepare(input, in: deck, template: template,
            warnings: &warnings, engine: engine, layoutVariants: ["a": 1])
        #expect(prepared.slides.count > 1)
        for (index, page) in prepared.slides.enumerated() {
            let slide = try TemplateRendering.build(page, in: deck, template: template, image: nil,
                warnings: &warnings, engine: engine, variant: index == 0 ? 1 : 0)
            let shapes = try slide.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.children(named: "p:sp") ?? []
            for shape in shapes {
                let type = shape.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph")?[attribute: "type"] ?? "obj"
                guard ["obj", "body"].contains(type) else { continue }
                let fit = shape.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit")
                if let scale = fit?[attribute: "fontScale"].flatMap(Int.init) { #expect(scale >= storedScale) }
            }
        }
    }
}
