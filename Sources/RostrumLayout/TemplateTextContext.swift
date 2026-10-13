import Foundation
import Rostrum

/// Read-only template inheritance, retained only during one engine operation.
/// The generated body is shared by planning and composition. Template prompt
/// runs and shape-level overrides are not cloned onto a new slide.
final class TemplateTextContext {
    let styles: [XML.Element]
    let body: XML.Element
    let theme: Theme?
    let isTitle: Bool
    private var prepared: (paragraphs: [LayoutParagraph], scale: Double, body: XML.Element)?

    init?(layout: SlideLayout, slot: Int, presentation: Presentation) {
        guard presentation.package.parts[layout.part.uri] === layout.part else { return nil }
        guard let node = try? layout.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?
            .children(named: "p:sp").first(where: { shape in
                guard let ph = shape.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph") else { return false }
                return (Int(ph[attribute: "idx"] ?? "0") ?? 0) == slot
            }) else { return nil }
        styles = RichTextLayout.inheritedStyles(for: node, layout: layout.part, package: presentation.package)
        theme = layout.master?.theme
        let kind = node.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph")?[attribute: "type"] ?? "obj"
        isTitle = ["title", "ctrTitle"].contains(kind)
        body = XML.Element("a:bodyPr")
        let bodies = styles.filter { $0.name == "a:bodyPr" }
        for source in bodies.reversed() {
            for attribute in source.attributes { body[attribute: attribute.name] = attribute.value }
        }
        if let fit = bodies.lazy.compactMap({ source in
            source.childElements.first { ["a:normAutofit", "a:noAutofit", "a:spAutoFit"].contains($0.name) }
        }).first { body.appendElement(fit) }
    }

    var supported: Bool {
        (body[attribute: "vert"] ?? "horz") == "horz" && Int(body[attribute: "numCol"] ?? "1") == 1
    }
    var autofit: XML.Element? { body.firstChild(named: "a:normAutofit") }
    var storedScale: Int { min(100000, max(100, Int(autofit?[attribute: "fontScale"] ?? "100000") ?? 100000)) }
    func inset(_ name: String, default fallback: Double) -> Double {
        body.coordinate(name).map { Double($0) / Double(EMU.perPoint) } ?? fallback
    }

    func size(_ item: LayoutParagraph, objectScale: Double) -> Double {
        let level = min(8, max(0, item.level)) + 1
        let defaults = styles.flatMap { style in
            [style.firstChild(named: "a:lvl\(level)pPr"), style.firstChild(named: "a:defPPr")].compactMap { $0 }
        }
        let raw = defaults.lazy.compactMap { $0.firstChild(named: "a:defRPr")?[attribute: "sz"] }.first.flatMap(Double.init) ?? 1800
        let inherited = raw.isFinite ? min(4000, max(1, raw / 100)) : 18
        let size: Double
        switch item.role {
        case .caption: size = 14 * objectScale
        case .some: size = max(24, inherited * 1.15)
        case .none: return inherited
        }
        // Resolve at the same hundredth-point precision that is written.
        return (min(4000, max(1, size)) * 100).rounded() / 100
    }

    func textBody(_ paragraphs: [LayoutParagraph], objectScale: Double) -> XML.Element {
        if let prepared, prepared.paragraphs == paragraphs, prepared.scale == objectScale { return prepared.body }
        let text = XML.Element("p:txBody", children: [.element(XML.Element("a:bodyPr")), .element(XML.Element("a:lstStyle"))])
        for item in paragraphs {
            let level = min(8, max(0, item.level))
            let properties = XML.Element("a:pPr", attributes: level == 0 ? [] : [("lvl", String(level))])
            var runProperties: XML.Element?
            if let role = item.role {
                properties.appendElement(XML.Element("a:buNone"))
                // An absent b inherits the template; caption explicitly turns
                // bold off, matching the style that the planner measures.
                runProperties = XML.Element("a:rPr", attributes: [
                    ("sz", String(Int((size(item, objectScale: objectScale) * 100).rounded()))),
                    ("b", role == .caption ? "0" : "1")])
            }
            text.appendElement(XML.Element("a:p", children: [.element(properties)]
                + Paragraph.textChildren(item.text, properties: runProperties)))
        }
        if paragraphs.isEmpty { text.appendElement(XML.Element("a:p")) }
        prepared = (paragraphs, objectScale, text)
        return text
    }

    /// Borrow immutable paragraph nodes while replacing only body properties.
    /// Each composed slide receives its own structural copy afterwards.
    func scaled(_ text: XML.Element, scale: Int) -> (body: XML.Element, autofit: XML.Element) {
        let fit = autofit?.deepCopy() ?? XML.Element("a:normAutofit")
        fit[attribute: "fontScale"] = String(scale)
        let body = XML.Element("a:bodyPr", children: [.element(fit)])
        return (XML.Element("p:txBody", children: [.element(body)] + text.children.filter {
            if case .element(let element) = $0 { return element.name != "a:bodyPr" }
            return true
        }), fit)
    }
}
