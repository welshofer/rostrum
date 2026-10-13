import Foundation
import Rostrum

public struct LayoutParagraph: Sendable, Equatable {
    public var text: String
    public var level: Int
    public var role: TypeRole?
    public init(_ text: String, level: Int = 0, role: TypeRole? = nil) { self.text = text; self.level = level; self.role = role }
}

/// A platform adapter may measure with a shaping engine (CoreText on Apple).
/// The portable engine never discovers fonts or consults the network itself.
public struct TextMeasureRequest: Sendable, Hashable {
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
    // Only present when planning writes a new scale; otherwise inheritance stays intact.
    var autofit: XML.Element? = nil
    var occupiedHeight: Double = 0
}

public struct CompositionScore: Sendable, Equatable {
    public let penalty: Double
    public let reasons: [String]
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
    public var score = CompositionScore(penalty: 0, reasons: [])
    public internal(set) var tableLayout: TableLayoutPlan? = nil
    var tableContent: TemplateTableContent? = nil
}

/// Chooses and fills actual template layouts. Geometry and typography belong
/// to the template. A failed fit tries another compatible layout, then fails
/// explicitly; it never paints a free-form slide over the master's artwork.
public final class TemplateLayoutEngine {
    public let presentation: Presentation
    /// Normalize generated object typography to a 540-point-high widescreen canvas.
    public var objectScale: Double { presentation.bounds.height.points / 540 }
    private let measure: TextHeightMeasurer?
    private var measurements: [TextMeasureRequest: Double] = [:]
    private struct ContextKey: Hashable { let layout: PackURI; let slot: Int }
    private var textContexts: [ContextKey: TemplateTextContext] = [:]
    private func context(_ layout: SlideLayout, slot: Int) -> TemplateTextContext? {
        let key = ContextKey(layout: layout.part.uri, slot: slot)
        if let value = textContexts[key] { return value }
        guard let value = TemplateTextContext(layout: layout, slot: slot, presentation: presentation) else { return nil }
        if textContexts.count < 64 { textContexts[key] = value }
        return value
    }
    public private(set) var measurementCacheHits = 0

    private func height(_ request: TextMeasureRequest) -> Double? {
        guard let measure else { return nil }
        if let cached = measurements[request] { measurementCacheHits += 1; return cached }
        let value = measure(request)
        guard value.isFinite, value >= 0 else { return value }
        // Bound memory on large decks; a cache miss never changes layout behavior.
        if measurements.count >= 8192 { measurements.removeAll(keepingCapacity: true) }
        measurements[request] = value
        return value
    }
    public init(presentation: Presentation, measure: TextHeightMeasurer? = nil) {
        self.presentation = presentation; self.measure = measure
    }

    /// Structured objects inherit the content placeholder's typeface as well
    /// as the master palette. Corporate templates often override theme fonts.
    public func objectStyle(layout: SlideLayout, slot: Int?) -> DeckStyle {
        var style = layout.master?.theme.map { DeckStyle(theme: $0) } ?? presentation.style
        for role in TypeRole.allCases { style.type = style.type.overriding(role) { $0.sizePt *= objectScale } }
        guard let slot else { return style }
        let run = layout.textDefaults(for: slot).paragraph.firstChild(named: "a:defRPr")
        guard let raw = run?.firstChild(named: "a:latin")?[attribute: "typeface"] else { return style }
        let font = raw.hasPrefix("+mj") ? style.headingFont : raw.hasPrefix("+mn") ? style.bodyFont : raw
        style.headingFont = font; style.bodyFont = font
        for role in TypeRole.allCases { style.type = style.type.overriding(role) { $0.font = font } }
        return style
    }

    public func plan(title: String, columns: [[LayoutParagraph]], preferredTypes: [String],
                     object: String? = nil, picture: Bool = false,
                     masterURI: String? = nil, objectCaption: String = "",
                     minimumObjectHeight: Double = 144,
                     measureObjectHeight: ((Double, DeckStyle) -> Double)? = nil,
                     imageAspect: Double? = nil, variant: Int = 0, layoutURI: String? = nil,
                     table: TemplateTableContent? = nil,
                     validateObject: ((Rect, DeckStyle) throws -> Void)? = nil) throws -> TemplateSlidePlan {
        guard table == nil || object == "tbl" else { throw LayoutError.cannotFit("Table content requires a table object slot.") }
        // Reject malformed content before selecting or mutating any slide.
        if let table { _ = try table.widths(for: presentation.bounds.width) }
        textContexts.removeAll(keepingCapacity: true)
        defer { textContexts.removeAll(keepingCapacity: true) }
        var failures: [String] = []
        var candidates: [TemplateSlidePlan] = []
        struct TableKey: Hashable { let width: EMU; let font: Data; let theme: PackURI; let availableHeight: EMU? }
        var tablePlans: [TableKey: TableLayoutPlan] = [:]
        var remainingTableCells = 8192
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
            (masterURI == nil || $0.element.master?.part.uri.value == masterURI) && (layoutURI == nil || $0.element.part.uri.value == layoutURI)
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
                let paragraphs = coverParagraphs(title: title, columns: columns)
                guard let fit = textFit(paragraphs, in: titleFrame, layout: layout, slot: titleSlot.index) else {
                    failures.append("\(layout.name): cover text exceeds its placeholder"); continue
                }
                candidates.append(TemplateSlidePlan(layout: layout, title: titleSlot, textSlots: [], objectSlot: nil,
                    pictureSlot: picture ? slots.first(where: { $0.type == "pic" }) : nil, objectFrame: nil, captionFrame: nil, combinesTitleAndBody: true, textFits: [titleSlot.index: fit]))
                continue
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
            let style = objectStyle(layout: layout, slot: objectSlot?.index)
            var tableLayout: TableLayoutPlan?
            if let table, let frame = objectFrame {
                let theme = layout.master?.theme ?? presentation.theme
                var availableHeight: EMU?
                if table.measuresColumns {
                    let caption = objectCaption.isEmpty ? 0 : measuredHeight(objectCaption, style: style.type(.caption), width: frame.width.points) + 8
                    guard caption.isFinite, caption < frame.height.points else {
                        failures.append("\(layout.name): caption leaves no table area"); continue
                    }
                    availableHeight = frame.height - .points(caption)
                }
                let key = TableKey(width: frame.width, font: Data(style.bodyFont.utf8), theme: theme.part.uri, availableHeight: availableHeight)
                do {
                    if let cached = tablePlans[key] { tableLayout = cached }
                    else {
                        tableLayout = try table.planned(in: presentation, width: frame.width, font: style.bodyFont,
                            size: 18 * objectScale, theme: theme, availableHeight: availableHeight)
                        if let tableLayout, tablePlans.count < 64, tableLayout.cells.count <= remainingTableCells {
                            tablePlans[key] = tableLayout; remainingTableCells -= tableLayout.cells.count
                        }
                    }
                } catch { failures.append("\(layout.name): \(error)"); continue }
                guard tableLayout?.fits == true else { failures.append("\(layout.name): unsupported or overflowing table cells"); continue }
            }
            let requiredObjectHeight = objectFrame.map {
                max(minimumObjectHeight, tableLayout?.totalHeight.points ?? measureObjectHeight?($0.width.points, style) ?? 0)
            } ?? minimumObjectHeight
            if let frame = objectFrame, frame.height.points < requiredObjectHeight {
                failures.append("\(layout.name): object region is too short"); continue
            }
            if let frame = objectFrame, !objectCaption.isEmpty {
                let style = objectStyle(layout: layout, slot: objectSlot?.index)
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
            if let objectFrame, let validateObject {
                do { try validateObject(objectFrame, style) }
                catch { failures.append("\(layout.name): \(error)"); continue }
            }
            var textFits = [titleSlot.index: titleFit]
            var fitsBody = true
            for (paragraphs, slot) in zip(columns, texts) {
                guard let fit = textFit(paragraphs, in: slot.frame!, layout: layout, slot: slot.index) else { fitsBody = false; break }
                textFits[slot.index] = fit
            }
            guard fitsBody else { failures.append("\(layout.name): content exceeds its placeholder"); continue }
            let frames = occupied.filter { $0.type != "pic" }.compactMap { textFits[$0.index]?.frame ?? $0.frame }
            guard !frames.indices.contains(where: { i in frames.indices.contains { j in
                j > i && min(frames[i].maxX, frames[j].maxX) > max(frames[i].x, frames[j].x)
                    && min(frames[i].maxY, frames[j].maxY) > max(frames[i].y, frames[j].y)
            } }) else { failures.append("\(layout.name): fitted content collides"); continue }
            var candidate = TemplateSlidePlan(layout: layout, title: titleSlot, textSlots: Array(texts.prefix(columns.count)),
                                     objectSlot: objectSlot, pictureSlot: pictureSlot, objectFrame: objectFrame, captionFrame: captionFrame, combinesTitleAndBody: false, textFits: textFits)
            candidate.tableLayout = tableLayout; candidate.tableContent = table
            candidates.append(candidate)
        }
        for i in candidates.indices {
            let candidate = candidates[i]
            var penalty = Double(rank(candidate.layout)) * 10
            var reasons: [String] = []
            // Custom templates can label a large callout as subTitle and its
            // small explanatory line as title. Prefer a layout whose visual
            // hierarchy matches the supplied headline without rewriting it.
            let titleSize = paragraphSize(LayoutParagraph(title), layout: candidate.layout, slot: candidate.title.index)
                * (candidate.textFits[candidate.title.index]?.fontScale ?? 1)
            let supportingSize = zip(columns, candidate.textSlots).flatMap { paragraphs, slot in
                paragraphs.map { paragraphSize($0, layout: candidate.layout, slot: slot.index)
                    * (candidate.textFits[slot.index]?.fontScale ?? 1) }
            }.max() ?? 0
            if supportingSize > titleSize {
                penalty += 2000 * (supportingSize / max(1, titleSize) - 1)
                reasons.append("Supporting text would dominate the headline")
            }
            let shrink = candidate.textFits.values.reduce(0) { $0 + (1 - $1.fontScale) * 300 }
            penalty += shrink
            if shrink > 0 { reasons.append("Text requires autofit") }
            let regions = candidate.textSlots.compactMap(\.frame) + [candidate.objectFrame].compactMap { $0 }
            let area = regions.reduce(0.0) { $0 + $1.width.points * $1.height.points }
            let canvas = presentation.bounds.width.points * presentation.bounds.height.points
            // Object slides benefit strongly from usable area, while body text
            // also considers column balance. Empty canvas is not itself a defect.
            penalty -= (object == nil ? 20 : 100) * area / max(1, canvas)
            // Fitting already measured each accepted body at its saved scale.
            // Ranking must not repeat shaping or measure an unfitted version.
            let heights = candidate.textSlots.compactMap { candidate.textFits[$0.index]?.occupiedHeight }
            if heights.count > 1, let hi = heights.max(), let lo = heights.min() {
                penalty += 15 * (hi - lo) / max(1, hi)
            }
            if picture && candidate.pictureSlot == nil { penalty += 500; reasons.append("No image placeholder") }
            if let aspect = imageAspect, aspect > 0, let frame = candidate.pictureSlot?.frame {
                let slotAspect = frame.width.points / frame.height.points
                penalty += 40 * (1 - min(aspect, slotAspect) / max(aspect, slotAspect))
            }
            reasons.append("Compared semantic match, readable text, content area and balance")
            candidates[i].score = CompositionScore(penalty: penalty, reasons: reasons)
        }
        let ranked = candidates.enumerated().sorted {
            $0.element.score.penalty == $1.element.score.penalty ? $0.offset < $1.offset : $0.element.score.penalty < $1.element.score.penalty
        }.map(\.element)
        if !ranked.isEmpty { return ranked[max(0, variant) % ranked.count] }
        let detail = failures.prefix(4).joined(separator: "; ")
        throw LayoutError.cannotFit("No template layout can fit ‘\(title)’. " + (detail.isEmpty
            ? "The selected master needs a title and enough compatible content placeholders."
            : detail) + " Shorten the content or choose a roomier template layout.")
    }

    private func coverParagraphs(title: String, columns: [[LayoutParagraph]]) -> [LayoutParagraph] {
        [LayoutParagraph(title)] + (columns.first ?? []).map {
            LayoutParagraph($0.text, level: max(0, min(7, $0.level) + 1))
        }
    }

    public func compose(_ plan: TemplateSlidePlan, title: String, columns: [[LayoutParagraph]]) throws -> Slide {
        try write(plan, prepared: prepare(plan, title: title, columns: columns))
    }

    struct PreparedSlide {
        let bodies: [(Int, XML.Element)]
        let tableStyle: DeckStyle?
        let tableLayout: TableLayoutPlan?
    }

    // Pagination prepares every page before inserting any slides. Its table
    // geometry was freshly measured as one complete operation.
    func prepare(_ plan: TemplateSlidePlan, title: String, columns: [[LayoutParagraph]],
                 measuredTable: TableLayoutPlan? = nil) throws -> PreparedSlide {
        textContexts.removeAll(keepingCapacity: true)
        defer { textContexts.removeAll(keepingCapacity: true) }
        guard plan.combinesTitleAndBody ? columns.count <= 1 : columns.count == plan.textSlots.count else {
            throw LayoutError.cannotFit("The supplied columns do not match the planned placeholders.")
        }
        let titleParagraphs = plan.combinesTitleAndBody ? coverParagraphs(title: title, columns: columns) : [LayoutParagraph(title)]
        var prepared: [(Int, XML.Element)] = []
        let contents = [(plan.title.index, titleParagraphs)] + zip(plan.textSlots, columns).map { ($0.index, $1) }
        // Validate the exact written bodies before adding a slide. Content,
        // template styles or registered fonts may have changed since planning.
        for (index, paragraphs) in contents {
            guard let context = context(plan.layout, slot: index), context.supported,
                  let fit = plan.textFits[index], valid(fit.frame) else {
                throw LayoutError.cannotFit("The planned text placeholder is unavailable or unsupported.")
            }
            let body = context.textBody(paragraphs, objectScale: objectScale).deepCopy()
            if let autofit = fit.autofit {
                body.firstChild(named: "a:bodyPr")?.appendElement(autofit.deepCopy())
            }
            guard measured(body, width: fit.frame.width.points, context: context).height <= fit.frame.height.points + 0.01 else {
                throw LayoutError.cannotFit("The supplied text no longer fits its plan. Plan the slide again before composing it.")
            }
            prepared.append((index, body))
        }
        var tableLayout: TableLayoutPlan?
        let tableStyle = plan.tableContent.map { _ in objectStyle(layout: plan.layout, slot: plan.objectSlot?.index) }
        if let table = plan.tableContent, let tableStyle {
            guard let frame = plan.objectFrame, valid(frame), let slot = plan.objectSlot,
                  plan.layout.placeholders.first(where: { $0.index == slot.index })?.frame == slot.frame else {
                throw LayoutError.cannotFit("The planned table slot is unavailable.")
            }
            let current = try measuredTable ?? table.planned(in: presentation, width: frame.width, font: tableStyle.bodyFont,
                size: 18 * objectScale, theme: plan.layout.master?.theme ?? presentation.theme,
                fixedColumnWidths: table.measuresColumns ? plan.tableLayout?.columnWidths : nil)
            guard current.fits, current.totalHeight <= frame.height else {
                throw LayoutError.cannotFit("The table no longer fits its plan. Plan the slide again before composing it.")
            }
            tableLayout = current
        }
        return PreparedSlide(bodies: prepared, tableStyle: tableStyle, tableLayout: tableLayout)
    }

    func write(_ plan: TemplateSlidePlan, prepared: PreparedSlide) throws -> Slide {
        let slide = try presentation.slides.add(clonedFrom: plan.layout)
        for (index, body) in prepared.bodies {
            guard let shape = slide.placeholder(idx: index) else { continue }
            shape.element.removeChildren(named: "p:txBody")
            shape.element.appendElement(body)
            if let fit = plan.textFits[index], fit.frame != plan.layout.placeholders.first(where: { $0.index == index })?.frame {
                shape.frame = fit.frame
            }
        }
        slide.part.markDirty()
        if let table = plan.tableContent, let tableStyle = prepared.tableStyle,
           let tableLayout = prepared.tableLayout, let frame = plan.objectFrame, let slot = plan.objectSlot {
            let native = try slide.shapes.addTable(rows: table.rows.count, columns: tableLayout.columnWidths.count,
                frame: Rect(x: frame.x, y: frame.y, width: frame.width, height: tableLayout.totalHeight))
            native.setLayoutContents(table.rows, font: tableStyle.bodyFont, size: 18 * objectScale)
            native.columnWidths(tableLayout.columnWidths).rowHeights(tableLayout.rowHeights)
            if let shape = slide.shapes.all.last { try slide.replacePlaceholder(index: slot.index, with: shape) }
        }
        return slide
    }

    /// Height for a zero-inset, styled text block, including explicit newlines.
    /// Uses shared rich-text geometry and an optional conservative host check.
    public func measuredHeight(_ text: String, style: TextStyle, width: Double) -> Double {
        guard width.isFinite, width > 0, style.sizePt.isFinite, (1...4000).contains(style.sizePt),
              style.trackingPt.isFinite, abs(style.trackingPt) <= 4000,
              style.lineHeight.isFinite, (0...100).contains(style.lineHeight) else { return .infinity }
        let properties = XML.Element("a:pPr", children: [.element(XML.Element("a:lnSpc", children: [
            .element(XML.Element("a:spcPct", attributes: [("val", String(Int((style.lineHeight * 100000).rounded())))]))]))])
        let run = XML.Element("a:r", children: [.element(XML.Element("a:rPr", attributes: [
            ("sz", String(Int((style.sizePt * 100).rounded()))), ("b", style.bold ? "1" : "0"),
            ("spc", String(Int((style.trackingPt * 100).rounded())))], children: [
                .element(XML.Element("a:latin", attributes: [("typeface", style.font)]))])),
            .element(XML.Element("a:t", children: [.text(style.uppercase ? text.uppercased() : text)]))])
        let body = XML.Element("p:txBody", children: [
            .element(XML.Element("a:bodyPr", attributes: [("lIns", "0"), ("rIns", "0"), ("tIns", "0"), ("bIns", "0")])),
            .element(XML.Element("a:lstStyle")), .element(XML.Element("a:p", children: [.element(properties), .element(run)]))])
        return ceil(measured(body, width: width, context: nil).height)
    }

    private func measured(_ body: XML.Element, width: Double, context: TemplateTextContext?, preparation: RichTextLayout.Preparation? = nil) -> (layout: RichTextLayout, height: Double) {
        let geometry = RichTextLayout(textBody: body, width: width, height: 1e9,
            fonts: presentation.fonts, theme: context?.theme ?? presentation.theme,
            inheritedStyles: context?.styles ?? [], maxLines: 65, preparation: preparation)
        // The renderer emits at most 64 lines. Height is measured independently
        // of the candidate frame so native vertical flow can grow into safe space.
        guard geometry.fits, geometry.lines.count <= 64 else { return (geometry, .infinity) }
        let left = context?.inset("lIns", default: 7.2) ?? 0
        let right = context?.inset("rIns", default: 7.2) ?? 0
        var height = geometry.contentHeight
        if measure != nil {
            for line in geometry.lines {
                var hostHeight = line.height
                for span in line.spans where !span.run.text.isEmpty {
                    let run = span.run
                    guard let value = self.height(TextMeasureRequest(text: run.text,
                        font: run.fontFamily ?? context?.theme?.minorFont ?? presentation.theme.minorFont ?? "Arial",
                        size: run.fontSize, bold: run.bold, tracking: run.tracking, width: max(0, width - left - right))),
                          value.isFinite, value >= 0 else { return (geometry, .infinity) }
                    hostHeight = max(hostHeight, value)
                }
                height += hostHeight - line.height
            }
        }
        height += (context?.inset("tIns", default: 3.6) ?? 0) + (context?.inset("bIns", default: 3.6) ?? 0)
        return (geometry, height)
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
        textContexts.removeAll(keepingCapacity: true)
        defer { textContexts.removeAll(keepingCapacity: true) }
        return textFit(paragraphs, in: frame, layout: layout, slot: slot) != nil
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
        guard valid(frame), let context = context(layout, slot: slot), context.supported else { return nil }
        let text = context.textBody(paragraphs, objectScale: objectScale)
        let body = context.body
        let original = measured(text, width: frame.width.points, context: context)
        let required = original.height
        let scale = context.storedScale
        if required <= frame.height.points + 0.01 {
            return TemplateTextFit(frame: frame, fontScale: Double(scale) / 100000, occupiedHeight: required)
        }
        if context.autofit != nil {
            let minimum = original.layout.lines.lazy.flatMap(\.spans).map(\.run.fontSize).min()
                .map { $0 / (Double(scale) / 100000) } ?? 18
            let readable = context.isTitle ? 18.0 : 12.0
            let lower = min(scale, max(60000, Int(ceil(readable / max(1, minimum) * 100000))))
            let preparation = RichTextLayout.Preparation()
            func height(_ scale: Int) -> Double {
                let candidate = context.scaled(text, scale: scale).body
                return measured(candidate, width: frame.width.points, context: context, preparation: preparation).height
            }
            var lowHeight = height(lower)
            guard lowHeight <= frame.height.points + 0.01 else { return nil }
            var low = lower, high = scale
            for _ in 0..<12 where low < high {
                let mid = (low + high + 1) / 2
                let candidateHeight = height(mid)
                if candidateHeight <= frame.height.points + 0.01 { low = mid; lowHeight = candidateHeight }
                else { high = mid - 1 }
            }
            // low is an accepted integer scale at the exact saved precision.
            return TemplateTextFit(frame: frame, fontScale: Double(low) / 100000,
                autofit: context.scaled(text, scale: low).autofit, occupiedHeight: lowHeight)
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
        return TemplateTextFit(frame: expanded, fontScale: Double(scale) / 100000, occupiedHeight: required)
    }

    private func paragraphSize(_ item: LayoutParagraph, layout: SlideLayout, slot: Int) -> Double {
        context(layout, slot: slot)?.size(item, objectScale: objectScale) ?? 18
    }

}
