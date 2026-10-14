import Foundation
import Rostrum
import RostrumLayout

/// Keep a citation with its content when an unused band can hold it. Imported
/// templates and measured table captions retain their own placement rules.
enum AuthoredSourcePlacement {
    @discardableResult
    static func add(_ text: String, to slide: Slide, in deck: Presentation,
                    fitter: AuthoredLayoutEngine, reserved: [Rect] = []) throws -> Shape {
        let source = try deck.addSource(text, to: slide)
        do {
            do {
                try fitter.fitText(in: slide, only: [source.shapeID!])
                return source
            } catch is LayoutError {
                // Try a separate full-width band above the running furniture.
                // Use complete object frames, not estimated ink bounds: empty
                // space inside a chart, image or text frame is still occupied.
            }
            try Task.checkCancellation()
            let margin = deck.style.margin
            let left = deck.bounds.minX + margin, right = deck.bounds.maxX - margin
            let bottom = deck.bounds.maxY - .inches(0.55) - .points(6)
            var top = deck.bounds.minY + margin
            let occupied = slide.shapes.all.filter { $0.shapeID != source.shapeID }
                .compactMap { slide.effectiveFrame(of: $0) } + reserved
            for frame in occupied where frame.maxX > left && frame.minX < right {
                top = max(top, frame.maxY + .points(8))
            }
            let height = min(EMU.points(72), bottom - top)
            guard height >= .points(24), right > left else {
                throw LayoutError.cannotFit("The source has no unused readable band on this slide.")
            }
            source.frame = Rect(x: left, y: bottom - height, width: right - left, height: height)
            // Do not carry the narrow footer's 8–10pt fitting into a roomier
            // caption. Preserve its actual family, color and run content.
            for paragraph in source.textFrame?.paragraphs ?? [] {
                for run in paragraph.runs { run.fontSize = min(14, max(10, deck.style.type(.caption).sizePt)) }
            }
            try fitter.fitText(in: slide, only: [source.shapeID!])
            return source
        } catch {
            let tree = try slide.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")
            tree?.children.removeAll { node in
                if case .element(let element) = node {
                    return element.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "id"] == source.shapeID.map(String.init)
                }
                return false
            }
            slide.part.markDirty()
            throw error
        }
    }
}
