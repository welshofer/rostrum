import Foundation
import Rostrum

/// Final composition pass for slides authored from a design system. Imported
/// templates use TemplateLayoutEngine instead: this pass may adjust typography
/// within the author's own regions, but never rewrites a supplied template.
public final class AuthoredLayoutEngine {
    private let presentation: Presentation
    private let measure: TextHeightMeasurer?
    public init(presentation: Presentation, measure: TextHeightMeasurer? = nil) {
        self.presentation = presentation; self.measure = measure
    }

    public func finish(_ slide: Slide, layoutName: String) throws {
        try fitText(in: slide)
        try presentation.publishLayout(of: slide, named: layoutName)
    }

    public func fitText(in slide: Slide, only ids: [Int]? = nil) throws {
        guard let tree = try slide.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree") else { return }
        for shape in slide.shapes.all {
            if let ids, !ids.contains(shape.shapeID ?? -1) { continue }
            guard let id = shape.shapeID, let node = tree.childElements.first(where: {
                $0.childElements.first?.firstChild(named: "p:cNvPr")?[attribute: "id"] == String(id)
            }), let text = node.firstChild(named: "p:txBody"), !shape.textFrame!.text.isEmpty,
                  let frame = slide.effectiveFrame(of: shape) else { continue }
            guard frame.x >= .zero, frame.y >= .zero, frame.maxX <= presentation.bounds.maxX,
                  frame.maxY <= presentation.bounds.maxY else {
                throw LayoutError.cannotFit("Text ‘\(shape.textFrame?.text.prefix(60) ?? "")’ is outside the slide.")
            }
            let body = text.firstChild(named: "a:bodyPr")
            func inset(_ name: String, _ fallback: Double) -> Double {
                (body?[attribute: name].flatMap(Double.init).map { $0 / Double(EMU.perPoint) }) ?? fallback
            }
            let width = frame.width.points - inset("lIns", 7.2) - inset("rIns", 7.2)
            let height = frame.height.points - inset("tIns", 3.6) - inset("bIns", 3.6)
            let paragraphs = text.children(named: "a:p")
            let runs = paragraphs.flatMap { $0.children(named: "a:r") }
            guard !runs.isEmpty else { continue }
            let originalSizes = runs.map { ($0.firstChild(named: "a:rPr")?[attribute: "sz"].flatMap(Double.init) ?? 1800) / 100 }
            let minimum = originalSizes.min() ?? 18
            // Preserve intentionally small captions; body never falls below 17pt.
            let floor = minimum < 17 ? minimum : (shape.placeholder?.type == "title" ? 24.0 : 17.0)
            func needed(_ scale: Double, compact: Bool) -> Double {
                var total = 0.0
                for p in paragraphs {
                    let rs = p.children(named: "a:r")
                    let value = rs.map { $0.firstChild(named: "a:t")?.textContent ?? "" }.joined()
                    let props = rs.first?.firstChild(named: "a:rPr")
                    let size = (props?[attribute: "sz"].flatMap(Double.init) ?? 1800) / 100 * scale
                    let font = props?.firstChild(named: "a:latin")?[attribute: "typeface"] ?? presentation.style.bodyFont
                    let pPr = p.firstChild(named: "a:pPr")
                    let margin = (pPr?[attribute: "marL"].flatMap(Double.init) ?? 0) / Double(EMU.perPoint)
                    let request = TextMeasureRequest(text: value, font: font, size: size,
                        bold: props?[attribute: "b"] == "1",
                        tracking: (props?[attribute: "spc"].flatMap(Double.init) ?? 0) / 100,
                        width: max(1, width - margin))
                    let measured: Double
                    if let measure { measured = measure(request) }
                    else if let metrics = presentation.fonts.metrics(for: font) {
                        measured = Double(max(1, TextMeasurer(metrics).wrap(value, pointSize: size, width: request.width * 0.94).count)) * max(size * 1.2, metrics.lineHeight(pointSize: size))
                    } else {
                        measured = max(1, ceil(Double(value.count) * size * 0.56 / request.width)) * size * 1.25
                    }
                    let spacing = pPr?.firstChild(named: "a:lnSpc")?.firstChild(named: "a:spcPct")?[attribute: "val"].flatMap(Double.init) ?? 100000
                    total += measured * (compact ? min(1.1, spacing / 100000) : spacing / 100000)
                    for name in ["a:spcBef", "a:spcAft"] {
                        let gap = (pPr?.firstChild(named: name)?.firstChild(named: "a:spcPts")?[attribute: "val"].flatMap(Double.init) ?? 0) / 100
                        total += compact ? min(gap, 4) : gap
                    }
                }
                return total
            }
            if needed(1, compact: false) <= height { continue }
            var scale = 1.0
            while needed(scale, compact: true) > height, minimum * (scale - 0.025) >= floor { scale -= 0.025 }
            guard needed(scale, compact: true) <= height else {
                throw LayoutError.cannotFit("‘\(shape.textFrame?.text.prefix(70) ?? "")’ does not fit at a readable size. Use a roomier layout or split this slide.")
            }
            for (run, size) in zip(shape.textFrame!.paragraphs.flatMap(\.runs), originalSizes) {
                run.fontSize = size * scale
            }
            for (paragraph, node) in zip(shape.textFrame!.paragraphs, paragraphs) {
                let properties = node.firstChild(named: "a:pPr")
                let line = properties?.firstChild(named: "a:lnSpc")?.firstChild(named: "a:spcPct")?[attribute: "val"].flatMap(Double.init) ?? 100000
                paragraph.setLineSpacing(min(1.1, line / 100000))
                let before = (properties?.firstChild(named: "a:spcBef")?.firstChild(named: "a:spcPts")?[attribute: "val"].flatMap(Double.init) ?? 0) / 100
                let after = (properties?.firstChild(named: "a:spcAft")?.firstChild(named: "a:spcPts")?[attribute: "val"].flatMap(Double.init) ?? 0) / 100
                paragraph.setSpacing(beforePoints: min(4, before), afterPoints: min(4, after))
            }
            slide.part.markDirty()
        }
    }
}
