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

public struct TemplateSlidePlan {
    public let layout: SlideLayout
    public let title: TemplatePlaceholder
    public let textSlots: [TemplatePlaceholder]
    public let objectSlot: TemplatePlaceholder?
    public let pictureSlot: TemplatePlaceholder?
    /// Some custom covers use one body placeholder with title/subtitle levels.
    public let combinesTitleAndBody: Bool
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
                     masterURI: String? = nil) throws -> TemplateSlidePlan {
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
            return typeRank * 10 + (picture == hasPicture ? 0 : 30)
        }
        let layouts = presentation.allLayouts.enumerated().filter {
            masterURI == nil || $0.element.master?.part.uri.value == masterURI
        }.sorted { a, b in
            let ar = rank(a.element), br = rank(b.element)
            return ar == br ? a.offset < b.offset : ar < br
        }
        for (_, layout) in layouts {
            let slots = layout.placeholders.filter { !$0.isFurniture }
            let cover = preferredTypes.first == "title" ? combinedCover(layout) : nil
            guard let titleSlot = slots.first(where: \.isTitle) ?? cover, let titleFrame = titleSlot.frame else { continue }
            if cover != nil {
                guard columns.count <= 1, object == nil, valid(titleFrame) else { continue }
                let paragraphs = [LayoutParagraph(title)] + (columns.first ?? []).map { LayoutParagraph($0.text, level: min(8, $0.level + 1)) }
                guard fits(paragraphs, in: titleFrame, layout: layout, slot: titleSlot.index) else {
                    failures.append("\(layout.name): cover text exceeds its placeholder"); continue
                }
                return TemplateSlidePlan(layout: layout, title: titleSlot, textSlots: [], objectSlot: nil,
                    pictureSlot: picture ? slots.first(where: { $0.type == "pic" }) : nil, combinesTitleAndBody: true)
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
            let texts = content.isEmpty ? available : content
            guard texts.count >= columns.count else { continue }
            let occupied = [titleSlot] + Array(texts.prefix(columns.count)) + [objectSlot, pictureSlot].compactMap { $0 }
            guard occupied.allSatisfy({ valid($0.frame) }), !overlaps(occupied.filter { $0.type != "pic" }) else {
                failures.append("\(layout.name): overlapping or invalid placeholder bounds"); continue
            }
            guard fits([LayoutParagraph(title)], in: titleFrame, layout: layout, slot: titleSlot.index) else {
                failures.append("\(layout.name): title exceeds its placeholder"); continue
            }
            var fitsBody = true
            for (paragraphs, slot) in zip(columns, texts) {
                if !fits(paragraphs, in: slot.frame!, layout: layout, slot: slot.index) { fitsBody = false; break }
            }
            guard fitsBody else { failures.append("\(layout.name): content exceeds its placeholder"); continue }
            return TemplateSlidePlan(layout: layout, title: titleSlot, textSlots: Array(texts.prefix(columns.count)),
                                     objectSlot: objectSlot, pictureSlot: pictureSlot, combinesTitleAndBody: false)
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
        return slide
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
        var height = 0.0
        let base = layout.textDefaults(for: slot)
        func inset(_ name: String, _ fallback: Double) -> Double {
            base.body[attribute: name].flatMap(Double.init).map { $0 / Double(EMU.perPoint) } ?? fallback
        }
        let width = frame.width.points - inset("lIns", 7.2) - inset("rIns", 7.2)
        let available = frame.height.points - inset("tIns", 3.6) - inset("bIns", 3.6)
        for item in paragraphs {
            let defaults = layout.textDefaults(for: slot, level: item.level).paragraph
            let run = defaults.firstChild(named: "a:defRPr")
            let size = min(4000, max(1, (run?[attribute: "sz"].flatMap(Double.init) ?? 1800) / 100))
            let rawFont = run?.firstChild(named: "a:latin")?[attribute: "typeface"] ?? "+mn-lt"
            let font = rawFont.hasPrefix("+mj") ? layout.master?.theme?.majorFont ?? "Arial"
                : rawFont.hasPrefix("+mn") ? layout.master?.theme?.minorFont ?? "Arial" : rawFont
            let margin = (defaults[attribute: "marL"].flatMap(Double.init) ?? 0) / Double(EMU.perPoint)
            let usable = width - margin
            guard usable > 0 else { return false }
            let request = TextMeasureRequest(text: item.text, font: font, size: size,
                                             bold: run?[attribute: "b"] == "1",
                                             tracking: (run?[attribute: "spc"].flatMap(Double.init) ?? 0) / 100,
                                             width: usable)
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
        return height.isFinite && height <= available
    }
}
