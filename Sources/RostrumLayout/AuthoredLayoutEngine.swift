import Foundation
import Rostrum

/// Final composition pass for slides authored from a design system. Imported
/// templates use TemplateLayoutEngine instead: this pass may adjust typography
/// within the author's own regions, but never rewrites a supplied template.
public final class AuthoredLayoutEngine {
    private let presentation: Presentation
    private let measure: TextHeightMeasurer?

    private struct FitKey: Hashable {
        let text: Data
        let inherited: [Data]
        let width: EMU
        let height: EMU
        let title: Bool
    }
    private enum FitChange {
        case unchanged
        case autofit(XML.Element)
    }

    /// Portable fitting uses the same rich-text geometry as SVG rendering.
    /// An optional host measurement adds a conservative height check for each
    /// positioned span; it cannot approve text rejected by the shared layout.
    public init(presentation: Presentation, measure: TextHeightMeasurer? = nil) {
        self.presentation = presentation
        self.measure = measure
    }

    public func finish(_ slide: Slide, layoutName: String) throws {
        try fitText(in: slide)
        try presentation.publishLayout(of: slide, named: layoutName)
    }

    /// Fit complete rich-text bodies, preserving run properties and fields.
    /// A selected scale is saved as normal autofit. Explicit percentage line
    /// spacing and point paragraph gaps may be compacted; exact line spacing
    /// and inherited styles are preserved. An unfit body is left unchanged.
    public func fitText(in slide: Slide, only ids: [Int]? = nil) throws {
        let theme = slide.master?.theme ?? presentation.theme
        let selected = ids.map(Set.init)
        // Reuse only within this operation: font registration, theme changes
        // and later text edits cannot leave stale fit decisions in an engine.
        // Bound both entry count and serialized key bytes. Large bodies bypass
        // the cache. Custom host callbacks retain their per-shape invocation.
        var fits: [FitKey: FitChange] = [:]
        var keyBytes = 0
        var ordinaryStyles: [XML.Element]?
        var slideNumber: Int?
        var resolvedSlideNumber = false
        for shape in slide.shapes.all {
            try Task.checkCancellation()
            if let selected, !selected.contains(shape.shapeID ?? -1) { continue }
            let node = shape.element
            guard let text = node.firstChild(named: "p:txBody"),
                  text.children(named: "a:p").contains(where: { paragraph in
                      paragraph.childElements.contains { ["a:r", "a:fld", "a:br"].contains($0.name) }
                  }), let frame = slide.effectiveFrame(of: shape) else { continue }
            func cannotFit(_ reason: String) -> LayoutError {
                .cannotFit("‘\(shape.textFrame?.text.prefix(70) ?? "")’ \(reason)")
            }
            guard frame.width > .zero, frame.height > .zero,
                  frame.x >= .zero, frame.y >= .zero, frame.maxX <= presentation.bounds.maxX,
                  frame.maxY <= presentation.bounds.maxY else {
                throw cannotFit("is outside the slide or has an empty frame.")
            }
            if !resolvedSlideNumber, text.children(named: "a:p").contains(where: { paragraph in
                paragraph.children(named: "a:fld").contains { $0[attribute: "type"] == "slidenum" }
            }) {
                // Preserve declared positions, including malformed preceding
                // entries, without opening every slide or rescanning by index.
                let part = try presentation.package.mainDocumentPart()
                let ids = Set(part.rels.items.filter {
                    $0.type == RelType.slide && PackURI.resolve(target: $0.target, relativeTo: part.uri.baseURI) == slide.part.uri
                }.map(\.rId))
                slideNumber = try part.dom().firstChild(named: "p:sldIdLst")?.childElements.firstIndex {
                    $0[attribute: "r:id"].map(ids.contains) ?? false
                }.map { $0 + 1 }
                resolvedSlideNumber = true
            }
            var inherited: [XML.Element]
            if shape.placeholder == nil, let ordinaryStyles { inherited = ordinaryStyles }
            else {
                inherited = RichTextLayout.inheritedStyles(for: node, owner: slide.part, package: presentation.package)
                if shape.placeholder == nil { ordinaryStyles = inherited }
            }
            // Match the renderer's shape-level theme font reference precedence.
            if let index = node.firstChild(named: "p:style")?.firstChild(named: "a:fontRef")?[attribute: "idx"],
               ["major", "minor"].contains(index) {
                let style = XML.Element("a:lstStyle")
                for level in 1...9 {
                    style.appendElement(XML.Element("a:lvl\(level)pPr", children: [.element(
                        XML.Element("a:defRPr", children: [.element(XML.Element("a:latin", attributes: [
                            ("typeface", index == "major" ? "+mj-lt" : "+mn-lt")]))]))]))
                }
                inherited.insert(style, at: 0)
            }
            let key: FitKey? = measure == nil ? FitKey(text: XML.document(text), inherited: inherited.map(XML.document),
                width: frame.width, height: frame.height,
                title: ["title", "ctrTitle"].contains(shape.placeholder?.type ?? "")) : nil
            if let key, let cached = fits[key] {
                if case .autofit(let fit) = cached { apply(fit, to: text); slide.part.markDirty() }
                continue
            }
            func remember(_ change: FitChange) {
                guard let key, fits.count < 64 else { return }
                let bytes = key.text.count + key.inherited.reduce(0) { $0 + $1.count }
                guard bytes <= 65536, bytes <= 262144 - keyBytes else { return }
                fits[key] = change
                keyBytes += bytes
            }
            let bodies = [text.firstChild(named: "a:bodyPr")].compactMap { $0 }
                + inherited.filter { $0.name == "a:bodyPr" }
            func bodyAttribute(_ name: String) -> String? {
                bodies.lazy.compactMap { $0[attribute: name] }.first
            }
            func inset(_ name: String, default fallback: Double) -> Double {
                bodies.first { $0[attribute: name] != nil }?.coordinate(name)
                    .map { Double($0) / Double(EMU.perPoint) } ?? fallback
            }
            let availableWidth = max(0, frame.width.points - inset("lIns", default: 7.2) - inset("rIns", default: 7.2))
            guard (bodyAttribute("vert") ?? "horz") == "horz",
                  (bodyAttribute("numCol") ?? "1") == "1" else {
                throw cannotFit("uses vertical or multi-column text that authored fitting does not support.")
            }
            func layout(_ body: XML.Element) -> RichTextLayout {
                RichTextLayout(textBody: body, width: frame.width.points, height: frame.height.points,
                    fonts: presentation.fonts, theme: theme, inheritedStyles: inherited,
                    slideNumber: slideNumber, maxLines: 4096)
            }
            func accepted(_ value: RichTextLayout) -> Bool {
                // SVG currently emits at most 64 lines. Never approve content
                // that would be truncated in that consumer.
                guard value.fits, value.lines.count <= 64 else { return false }
                guard let measure else { return true }
                var extraHeight = 0.0
                for line in value.lines {
                    var hostHeight = line.height
                    for span in line.spans where !span.run.text.isEmpty {
                        let run = span.run
                        // A tight glyph advance from one shaping policy can
                        // wrap in another. Give the host the actual text-box
                        // width; shared layout already checks line geometry.
                        let height = measure(TextMeasureRequest(text: run.text,
                            font: run.fontFamily ?? theme.minorFont ?? "Arial", size: run.fontSize,
                            bold: run.bold, tracking: run.tracking, width: availableWidth))
                        guard height.isFinite, height >= 0 else { return false }
                        hostHeight = max(hostHeight, height)
                    }
                    extraHeight += hostHeight - line.height
                }
                let top = inset("tIns", default: 3.6)
                let bottom = inset("bIns", default: 3.6)
                return value.contentHeight + extraHeight <= frame.height.points - top - bottom + 0.01
            }
            let original = layout(text)
            if accepted(original) { remember(.unchanged); continue }
            guard !original.truncated else { throw cannotFit("exceeds the bounded text-layout limit.") }
            let minimum = original.lines.lazy.flatMap(\.spans).map(\.run.fontSize).min() ?? 18
            // Preserve intentionally small captions; body never falls below 17pt.
            let floor = minimum < 17 ? minimum : (["title", "ctrTitle"].contains(shape.placeholder?.type ?? "") ? 24.0 : 17.0)
            let minimumRatio = min(1, floor / minimum)
            let autofit = bodies.lazy.compactMap { source in
                source.childElements.first { ["a:normAutofit", "a:noAutofit", "a:spAutoFit"].contains($0.name) }
            }.first
            let storedScale = autofit?.name == "a:normAutofit" ? autofit?[attribute: "fontScale"] : nil
            let currentScale = min(100000, max(100, Int(storedScale ?? "100000") ?? 100000))
            let minimumScale = min(currentScale, Int(ceil(Double(currentScale) * minimumRatio)))
            let candidate = text.deepCopy()
            compact(candidate)
            let body = candidate.getOrAddChild("a:bodyPr", beforeAnyOf: ["a:lstStyle", "a:p"])
            for name in ["a:noAutofit", "a:normAutofit", "a:spAutoFit"] { body.removeChildren(named: name) }
            let fit = body.getOrAddChild("a:normAutofit", beforeAnyOf: ["a:scene3d", "a:sp3d", "a:flatTx", "a:extLst"])
            // Retain line reduction and unmodeled content of normal autofit.
            if let autofit, autofit.name == "a:normAutofit" {
                fit.attributes = autofit.attributes
                fit.children = autofit.deepCopy().children
            }
            var scale = currentScale
            while true {
                try Task.checkCancellation()
                fit[attribute: "fontScale"] = String(scale)
                if accepted(layout(candidate)) { break }
                guard scale > minimumScale else {
                    throw cannotFit("does not fit at a readable size. Use a roomier layout or split this slide.")
                }
                scale = max(minimumScale, scale - 2500)
            }
            // Apply only the measured edits. Retain paragraph/run identities so
            // previously obtained facades still edit the document after fitting.
            apply(fit, to: text)
            remember(.autofit(fit))
            slide.part.markDirty()
        }
    }

    private func apply(_ fit: XML.Element, to text: XML.Element) {
        compact(text)
        let body = text.getOrAddChild("a:bodyPr", beforeAnyOf: ["a:lstStyle", "a:p"])
        for name in ["a:noAutofit", "a:normAutofit", "a:spAutoFit"] { body.removeChildren(named: name) }
        let saved = body.getOrAddChild("a:normAutofit", beforeAnyOf: ["a:scene3d", "a:sp3d", "a:flatTx", "a:extLst"])
        saved.attributes = fit.attributes
        saved.children = fit.deepCopy().children
    }

    private func compact(_ text: XML.Element) {
        for paragraph in text.children(named: "a:p") {
            guard let properties = paragraph.firstChild(named: "a:pPr") else { continue }
            if let percentage = properties.firstChild(named: "a:lnSpc")?.firstChild(named: "a:spcPct"),
               let value = Int(percentage[attribute: "val"] ?? ""), value > 110000 {
                percentage[attribute: "val"] = "110000"
            }
            for name in ["a:spcBef", "a:spcAft"] {
                if let points = properties.firstChild(named: name)?.firstChild(named: "a:spcPts"),
                   let value = Int(points[attribute: "val"] ?? ""), value > 400 {
                    points[attribute: "val"] = "400"
                }
            }
        }
    }
}
