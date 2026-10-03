import Foundation
import Rostrum

public struct LayoutParagraph: Sendable, Equatable {
    public var text: String
    public var level: Int
    public init(_ text: String, level: Int = 0) { self.text = text; self.level = level }
}

/// A platform adapter may measure with a shaping engine (CoreText on Apple).
/// The portable engine never discovers fonts or consults the network itself.
public struct TextMeasureRequest: Sendable {
    public let text: String
    public let font: String
    public let size: Double
    public let bold: Bool
    public let tracking: Double
    public let width: Double
}

public typealias TextHeightMeasurer = (TextMeasureRequest) -> Double

public enum LayoutError: Error, CustomStringConvertible {
    case cannotFit(String)
    public var description: String {
        switch self { case .cannotFit(let message): return message }
    }
}

public struct TemplateTextFit {
    public let frame: Rect
    public let fontScale: Double
}

public struct TemplateSlidePlan {
    public let layout: SlideLayout
    public let title: TemplatePlaceholder
    public let textSlots: [TemplatePlaceholder]
    public let objectSlot: TemplatePlaceholder?
    public let pictureSlot: TemplatePlaceholder?
    public let objectFrame: Rect?
    public let captionFrame: Rect?
    /// Some custom covers use one body placeholder with title/subtitle levels.
    public let combinesTitleAndBody: Bool
    public let textFits: [Int: TemplateTextFit]
}

/// Chooses and fills actual template layouts. Geometry and typography belong
/// to the template. A failed fit tries another compatible layout, then fails
/// explicitly; it never paints a free-form slide over the master's artwork.
public final class TemplateLayoutEngine {
    public let presentation: Presentation
    private let measure: TextHeightMeasurer?
    public init(presentation: Presentation, measure: TextHeightMeasurer? = nil) {
        self.presentation = presentation; self.measure = measure
    }

    public func plan(title: String, columns: [[LayoutParagraph]], preferredTypes: [String],
                     object: String? = nil, picture: Bool = false,
                     masterURI: String? = nil, objectCaption: String = "",
                     minimumObjectHeight: Double = 144,
                     measureObjectHeight: ((Double, DeckStyle) -> Double)? = nil) throws -> TemplateSlidePlan {
        var failures: [String] = []
        func combinedCover(_ layout: SlideLayout) -> TemplatePlaceholder? {
            let text = layout.placeholders.filter { !$0.isFurniture && ["title", "ctrTitle", "body", "obj", "subTitle"].contains($0.type) }
            guard text.count == 1, let slot = text.first, slot.type == "body" else { return nil }
            let title = layout.textDefaults(for: slot.index).paragraph.firstChild(named: "a:defRPr")?[attribute: "sz"].flatMap(Double.init) ?? 0
            let subtitle = layout.textDefaults(for: slot.index, level: 1).paragraph.firstChild(named: "a:defRPr")?[attribute: "sz"].flatMap(Double.init) ?? title
            return title >= 3600 && subtitle < title ? slot : nil
        }
        func rank(_ layout: SlideLayout) -> Int {
            let slots = layout.placeholders
            let bodyCount = slots.filter { ["body", "obj"].contains($0.type) }.count
            let hasPicture = slots.contains { $0.type == "pic" }
            let inferred: String
            if combinedCover(layout) != nil || (bodyCount == 0 && slots.contains(where: { $0.type == "subTitle" })) { inferred = "title" }
            else if bodyCount == 0 { inferred = "secHead" }
            else if bodyCount >= 2 { inferred = "twoObj" }
            else if hasPicture { inferred = "picTx" }
            else { inferred = "obj" }
            let typeRank = preferredTypes.firstIndex(of: layout.type ?? inferred)
                ?? preferredTypes.firstIndex(of: inferred) ?? preferredTypes.count
            // Match content cardinality before falling back to a layout that
            // leaves a column unused. Small heading slots do not count as bodies.
            let objects = slots.filter { $0.type == "obj" }
            let count = objects.isEmpty ? bodyCount : objects.count
            let required = columns.count + (object == nil ? 0 : 1)
            return typeRank * 10 + (picture == hasPicture ? 0 : 100)
                + max(0, count - required) * 40
        }
        let layouts = presentation.allLayouts.enumerated().filter {
            masterURI == nil || $0.element.master?.part.uri.value == masterURI
        }.sorted { a, b in
            let ar = rank(a.element), br = rank(b.element)
            if ar != br { return ar < br }
            // Templates often ship narrow and full-width variants of the same
            // layout type. Use their available content area, not package order.
            func area(_ layout: SlideLayout) -> Double {
                layout.placeholders.filter { ["obj", "body", "tbl", "chart"].contains($0.type) }
                    .compactMap(\.frame).reduce(0) { $0 + $1.width.points * $1.height.points }
            }
            let aa = area(a.element), ba = area(b.element)
            return aa == ba ? a.offset < b.offset : aa > ba
        }
        for (_, layout) in layouts {
            let slots = layout.placeholders.filter { !$0.isFurniture }
            let cover = preferredTypes.first == "title" ? combinedCover(layout) : nil
            guard let titleSlot = slots.first(where: \.isTitle) ?? cover, let titleFrame = titleSlot.frame else { continue }
            if cover != nil {
                guard columns.count <= 1, object == nil, valid(titleFrame) else { continue }
                let paragraphs = [LayoutParagraph(title)] + (columns.first ?? []).map { LayoutParagraph($0.text, level: min(8, $0.level + 1)) }
                guard let fit = textFit(paragraphs, in: titleFrame, layout: layout, slot: titleSlot.index) else {
                    failures.append("\(layout.name): cover text exceeds its placeholder"); continue
                }
                return TemplateSlidePlan(layout: layout, title: titleSlot, textSlots: [], objectSlot: nil,
                    pictureSlot: picture ? slots.first(where: { $0.type == "pic" }) : nil, objectFrame: nil, captionFrame: nil, combinesTitleAndBody: true, textFits: [titleSlot.index: fit])
            }
            let body = slots.filter { !$0.isTitle && ["body", "obj", "subTitle"].contains($0.type) }
                .sorted { a, b in
                    guard let af = a.frame, let bf = b.frame else { return a.index < b.index }
                    return af.x == bf.x ? af.y < bf.y : af.x < bf.x
                }
            let objectSlot = object.flatMap { kind in slots.first { $0.type == kind } ?? body.first { $0.type == "obj" } }
            if object != nil && objectSlot == nil { continue }
            let pictureSlot = picture ? slots.first(where: { $0.type == "pic" }) : nil
            let available = body.filter { $0.index != objectSlot?.index && $0.index != pictureSlot?.index }
            // A subtitle above a real content region is not a body column.
            let content = available.filter { $0.type != "subTitle" }
            let objects = content.filter { $0.type == "obj" }
            // Comparison layouts often have separate small column-heading slots.
            // Prefer the actual content regions for complete headed columns.
            let texts = objects.count >= columns.count && !objects.isEmpty ? objects : (content.isEmpty ? available : content)
            guard texts.count >= columns.count else { continue }
            let occupied = [titleSlot] + Array(texts.prefix(columns.count)) + [objectSlot, pictureSlot].compactMap { $0 }
            guard occupied.allSatisfy({ valid($0.frame) }), !overlaps(occupied.filter { $0.type != "pic" }) else {
                failures.append("\(layout.name): overlapping or invalid placeholder bounds"); continue
            }
            guard let titleFit = titleFit(title, frame: titleFrame, layout: layout, slot: titleSlot.index) else {
                failures.append("\(layout.name): title exceeds its placeholder"); continue
            }
            // Allocate explanatory text before accepting the layout, not after
            // placing an object in a fixed-height region.
            var objectFrame = objectSlot?.frame
            var captionFrame: Rect?
            let style = layout.master?.theme.map { DeckStyle(theme: $0) } ?? presentation.style
            let requiredObjectHeight = objectFrame.map {
                max(minimumObjectHeight, measureObjectHeight?($0.width.points, style) ?? 0)
            } ?? minimumObjectHeight
            if let frame = objectFrame, frame.height.points < requiredObjectHeight {
                failures.append("\(layout.name): object region is too short"); continue
            }
            if let frame = objectFrame, !objectCaption.isEmpty {
                let style = layout.master?.theme.map { DeckStyle(theme: $0) } ?? presentation.style
                let height = measuredHeight(objectCaption, style: style.type(.caption), width: frame.width.points)
                let gap = 8.0
                guard height.isFinite, frame.height.points - height - gap >= requiredObjectHeight else {
                    failures.append("\(layout.name): object and caption need more space"); continue
                }
                objectFrame = Rect(x: frame.x, y: frame.y, width: frame.width,
                                   height: .points(frame.height.points - height - gap))
                captionFrame = Rect(x: frame.x, y: objectFrame!.maxY + .points(gap),
                                    width: frame.width, height: .points(height))
            }
            var textFits = [titleSlot.index: titleFit]
            var fitsBody = true
            for (paragraphs, slot) in zip(columns, texts) {
                guard let fit = textFit(paragraphs, in: slot.frame!, layout: layout, slot: slot.index) else { fitsBody = false; break }
                textFits[slot.index] = fit
            }
            guard fitsBody else { failures.append("\(layout.name): content exceeds its placeholder"); continue }
            return TemplateSlidePlan(layout: layout, title: titleSlot, textSlots: Array(texts.prefix(columns.count)),
                                     objectSlot: objectSlot, pictureSlot: pictureSlot, objectFrame: objectFrame, captionFrame: captionFrame, combinesTitleAndBody: false, textFits: textFits)
        }
        let detail = failures.prefix(4).joined(separator: "; ")
        throw LayoutError.cannotFit("No template layout can fit ‘\(title)’. " + (detail.isEmpty
            ? "The selected master needs a title and enough compatible content placeholders."
            : detail) + " Shorten the content or choose a roomier template layout.")
    }

    public func compose(_ plan: TemplateSlidePlan, title: String, columns: [[LayoutParagraph]]) throws -> Slide {
        let slide = try presentation.slides.add(clonedFrom: plan.layout)
        let titleParagraphs = [(title, 0)] + (plan.combinesTitleAndBody
            ? (columns.first ?? []).map { ($0.text, min(8, $0.level + 1)) } : [])
        try slide.fillPlaceholder(index: plan.title.index, paragraphs: titleParagraphs)
        for (slot, paragraphs) in zip(plan.textSlots, columns) {
            try slide.fillPlaceholder(index: slot.index, paragraphs: paragraphs.map { ($0.text, $0.level) })
        }
        for (index, fit) in plan.textFits {
            guard let shape = slide.placeholder(idx: index) else { continue }
            if fit.frame != plan.layout.placeholders.first(where: { $0.index == index })?.frame {
                shape.frame = fit.frame
            }
            if fit.fontScale < 1 { shape.textFrame?.setAutoFit(fontScale: fit.fontScale) }
        }
        return slide
    }

    /// Height for a zero-inset, styled text block, including explicit newlines.
    /// Uses the same shaping adapter as placeholder fitting and preserves type size.
    public func measuredHeight(_ text: String, style: TextStyle, width: Double) -> Double {
        guard width > 0 else { return .infinity }
        let value = style.uppercase ? text.uppercased() : text
        let request = TextMeasureRequest(text: value, font: style.font, size: style.sizePt,
            bold: style.bold, tracking: style.trackingPt, width: width)
        let measured: Double
        if let measure { measured = measure(request) }
        else if let metrics = presentation.fonts.metrics(for: style.font) {
            measured = Double(max(1, TextMeasurer(metrics).wrap(value, pointSize: style.sizePt,
                width: width * (style.bold ? 0.94 : 1)).count)) * max(style.sizePt * 1.2, metrics.lineHeight(pointSize: style.sizePt))
        } else {
            let lines = value.components(separatedBy: "\n").reduce(0) { total, line in
                total + max(1, Int(ceil(Double(line.count) * style.sizePt * 0.56 / width)))
            }
            measured = Double(lines) * style.sizePt * 1.25
        }
        return ceil(measured * style.lineHeight) + 2
    }

    private func valid(_ frame: Rect?) -> Bool {
        guard let f = frame else { return false }
        let b = presentation.bounds
        return f.width > .zero && f.height > .zero && f.x >= .zero && f.y >= .zero
            && f.maxX <= b.maxX && f.maxY <= b.maxY
    }

    private func overlaps(_ slots: [TemplatePlaceholder]) -> Bool {
        for i in slots.indices {
            for j in slots.indices where j > i {
                guard let a = slots[i].frame, let b = slots[j].frame else { continue }
                if min(a.maxX, b.maxX) > max(a.x, b.x) && min(a.maxY, b.maxY) > max(a.y, b.y) { return true }
            }
        }
        return false
    }

    public func fits(_ paragraphs: [LayoutParagraph], in frame: Rect, layout: SlideLayout, slot: Int) -> Bool {
        textFit(paragraphs, in: frame, layout: layout, slot: slot) != nil
    }

    private func titleFit(_ title: String, frame: Rect, layout: SlideLayout, slot: Int) -> TemplateTextFit? {
        let paragraphs = [LayoutParagraph(title)]
        if let fit = textFit(paragraphs, in: frame, layout: layout, slot: slot) { return fit }
        // Some templates provide a narrow title above a full-width content area.
        // Grow only into that area's horizontal span, bounded by fixed artwork
        // and other placeholders. The original master/layout remains untouched.
        let content = layout.placeholders.filter { ["obj", "body", "tbl", "chart"].contains($0.type) }.compactMap(\.frame)
        var right = min(presentation.bounds.maxX.points, content.map { $0.maxX.points }.max() ?? frame.maxX.points)
        let barriers = layout.placeholders.filter { $0.index != slot }.compactMap(\.frame) + layout.artworkFrames
        for other in barriers where min(frame.maxY, other.maxY) > max(frame.y, other.y) && other.x >= frame.maxX {
            right = min(right, other.x.points - 4)
        }
        guard right > frame.maxX.points else { return nil }
        var wider = frame
        wider.width = .points(right - frame.x.points)
        return textFit(paragraphs, in: wider, layout: layout, slot: slot)
    }

    private func textFit(_ paragraphs: [LayoutParagraph], in frame: Rect, layout: SlideLayout, slot: Int) -> TemplateTextFit? {
        let body = layout.textDefaults(for: slot).body
        let required = textHeight(paragraphs, frame: frame, layout: layout, slot: slot, scale: 1)
        if required <= frame.height.points { return TemplateTextFit(frame: frame, fontScale: 1) }
        if body.firstChild(named: "a:normAutofit") != nil {
            // Keep native autofit on the slide, without flattening the template's
            // font, bullet or theme properties into individual runs.
            let sizes = paragraphs.map { item in
                (layout.textDefaults(for: slot, level: item.level).paragraph.firstChild(named: "a:defRPr")?[attribute: "sz"].flatMap(Double.init) ?? 1800) / 100
            }
            let minimum = sizes.min() ?? 18
            let readable = layout.placeholders.first(where: { $0.index == slot })?.isTitle == true ? 18.0 : 12.0
            let lower = max(0.6, min(1, readable / max(1, minimum)))
            guard textHeight(paragraphs, frame: frame, layout: layout, slot: slot, scale: lower) <= frame.height.points else { return nil }
            var low = lower, high = 1.0
            for _ in 0..<12 {
                let mid = (low + high) / 2
                if textHeight(paragraphs, frame: frame, layout: layout, slot: slot, scale: mid) <= frame.height.points { low = mid }
                else { high = mid }
            }
            return TemplateTextFit(frame: frame, fontScale: floor(low * 100000) / 100000)
        }
        // noAutofit means do not shrink, not prohibit wrapping. Default vertical
        // overflow may flow into available space; spAutoFit explicitly grows the
        // box. Materialize the measured height on this slide only so other clients
        // and subsequent editing see the same occupied region.
        guard body.firstChild(named: "a:spAutoFit") != nil || !["clip", "ellipsis"].contains(body[attribute: "vertOverflow"] ?? "overflow"),
              required.isFinite else { return nil }
        var bottom = presentation.bounds.maxY.points
        let barriers = layout.placeholders.filter { $0.index != slot }.compactMap(\.frame) + layout.artworkFrames
        for other in barriers where min(frame.maxX, other.maxX) > max(frame.x, other.x) {
            // Ignore existing enclosing/background artwork; prevent new collisions.
            if other.y >= frame.maxY { bottom = min(bottom, other.y.points - 4) }
        }
        guard frame.y.points + required <= bottom else { return nil }
        var expanded = frame
        expanded.height = .points(ceil(required))
        guard expanded.maxY.points <= bottom else { return nil }
        return TemplateTextFit(frame: expanded, fontScale: 1)
    }

    private func textHeight(_ paragraphs: [LayoutParagraph], frame: Rect, layout: SlideLayout, slot: Int, scale: Double) -> Double {
        var height = 0.0
        let base = layout.textDefaults(for: slot)
        func inset(_ name: String, _ fallback: Double) -> Double {
            base.body[attribute: name].flatMap(Double.init).map { $0 / Double(EMU.perPoint) } ?? fallback
        }
        let width = frame.width.points - inset("lIns", 7.2) - inset("rIns", 7.2)

        for item in paragraphs {
            let defaults = layout.textDefaults(for: slot, level: item.level).paragraph
            let run = defaults.firstChild(named: "a:defRPr")
            let size = min(4000, max(1, (run?[attribute: "sz"].flatMap(Double.init) ?? 1800) / 100)) * scale
            let rawFont = run?.firstChild(named: "a:latin")?[attribute: "typeface"] ?? "+mn-lt"
            let font = rawFont.hasPrefix("+mj") ? layout.master?.theme?.majorFont ?? "Arial"
                : rawFont.hasPrefix("+mn") ? layout.master?.theme?.minorFont ?? "Arial" : rawFont
            let margin = (defaults[attribute: "marL"].flatMap(Double.init) ?? 0) / Double(EMU.perPoint)
            let usable = width - margin
            guard usable > 0 else { return .infinity }
            let request = TextMeasureRequest(text: item.text, font: font, size: size,
                                             bold: run?[attribute: "b"] == "1",
                                             tracking: (run?[attribute: "spc"].flatMap(Double.init) ?? 0) / 100,
                                             width: usable)
            if base.body[attribute: "wrap"] == "none" {
                let widest = item.text.components(separatedBy: "\n").map {
                    presentation.fonts.metrics(for: font)?.width(of: $0, pointSize: size) ?? Double($0.count) * size * 0.56
                }.max() ?? 0
                if widest > usable { return .infinity }
            }
            let measured: Double
            if let measure { measured = measure(request) }
            else if let metrics = presentation.fonts.metrics(for: font) {
                let lines = TextMeasurer(metrics).wrap(item.text, pointSize: size, width: usable * (request.bold ? 0.94 : 1)).count
                measured = Double(max(1, lines)) * max(size * 1.2, metrics.lineHeight(pointSize: size))
            } else {
                // Conservative portable fallback; callers should register fonts
                // or provide a shaping adapter for final-client acceptance.
                let lines = item.text.components(separatedBy: "\n").reduce(0) { total, line in
                    total + max(1, Int(ceil(Double(line.count) * size * 0.56 / usable)))
                }
                measured = Double(lines) * size * 1.25
            }
            let lineSpacing = defaults.firstChild(named: "a:lnSpc")
            let multiple = (lineSpacing?.firstChild(named: "a:spcPct")?[attribute: "val"].flatMap(Double.init) ?? 100000) / 100000
            let fixed = lineSpacing?.firstChild(named: "a:spcPts")?[attribute: "val"].flatMap(Double.init).map { $0 / 100 }
            height += fixed.map { measured * $0 / (size * 1.2) } ?? measured * multiple
            for name in ["a:spcBef", "a:spcAft"] {
                let spacing = defaults.firstChild(named: name)
                height += (spacing?.firstChild(named: "a:spcPts")?[attribute: "val"].flatMap(Double.init) ?? 0) / 100
                height += size * (spacing?.firstChild(named: "a:spcPct")?[attribute: "val"].flatMap(Double.init) ?? 0) / 100000
            }
        }
        return height + inset("tIns", 3.6) + inset("bIns", 3.6)
    }
}
