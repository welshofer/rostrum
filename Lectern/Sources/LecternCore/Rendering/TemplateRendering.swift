import Foundation
import Rostrum
import RostrumLayout
#if canImport(CoreText)
import CoreText
import CoreGraphics
#endif

enum TemplateRendering {
    static var measurer: TextHeightMeasurer? {
        #if canImport(CoreText)
        return { request in
            var font = CTFontCreateWithName(request.font as CFString, request.size, nil)
            if request.bold, let bold = CTFontCreateCopyWithSymbolicTraits(font, request.size, nil, .boldTrait, .boldTrait) { font = bold }
            let text = NSAttributedString(string: request.text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTKernAttributeName as String): request.tracking
            ])
            let framesetter = CTFramesetterCreateWithAttributedString(text)
            let size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: 0, length: 0), nil,
                CGSize(width: max(1, request.width), height: 1_000_000), nil)
            return ceil(size.height)
        }
        #else
        return nil
        #endif
    }

    /// Reflow crowded panels and chart captions into supplied template layouts.
    /// Fit decisions use the same plans as final composition, without allocating
    /// probe slides or modifying the template's parts and relationships.
    static func prepare(_ input: DeckIR, in deck: Presentation, template: PowerPointTemplate,
                        warnings: inout [String], engine: TemplateLayoutEngine? = nil,
                        layoutVariants: [String: Int] = [:]) throws -> DeckIR {
        let engine = engine ?? TemplateLayoutEngine(presentation: deck, measure: measurer)
        var output = input
        output.slides = []
        var usedIDs = Set(input.slides.map(\.id))
        var expansions: [String: [String]] = [:]
        for slide in input.slides {
            try Task.checkCancellation()
            if PanelRendering.content(slide) != nil {
                func fits(_ candidate: IRSlide) throws -> Bool {
                    try Task.checkCancellation()
                    do {
                        let requested = layoutVariants[slide.id] ?? 0
                        // Recovery applies its choice to the original page;
                        // newly allocated continuations use the best-fit variant.
                        for variant in requested == 0 ? [0] : [requested, 0] {
                            let planned = try plan(candidate, template: template, image: nil, engine: engine,
                                                   variant: variant).slide
                            // These are overflow continuations: keep the template's
                            // existing body scale instead of packing more panels in
                            // by invoking another round of normal autofit.
                            if candidate.kind == .bullets {
                                for slot in planned.textSlots {
                                    let body = planned.layout.textDefaults(for: slot.index).body
                                    let stored = Int(body.firstChild(named: "a:normAutofit")?[attribute: "fontScale"] ?? "100000") ?? 100000
                                    let scale = Double(min(100000, max(100, stored))) / 100000
                                    if let fit = planned.textFits[slot.index], fit.fontScale + 0.000001 < scale { return false }
                                }
                            }
                        }
                        return true
                    } catch is LayoutError { return false }
                }
                if try fits(slide) { output.slides.append(slide); continue }
                var pages = try PanelPagination.reflow(slide, fits: fits)
                for index in pages.indices {
                    if index > 0 {
                        var id = slide.id + "-continued-\(index + 1)"
                        while usedIDs.contains(id) { id += "-next" }
                        usedIDs.insert(id); pages[index].id = id
                        expansions[slide.id, default: []].append(id)
                    }
                    output.slides.append(pages[index])
                }
                warnings.append("\(slide.title ?? "Slide"): crowded panels were reflowed across \(pages.count) template slides to keep all text readable.")
                continue
            }
            guard slide.kind == .chart,
                  let body = slide.body else { output.slides.append(slide); continue }
            let source = [body.kicker, body.lead, body.source].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
            guard !source.isEmpty else { output.slides.append(slide); continue }
            let kind = "chart"
            let preferred = [kind, "obj"]
            let minimum = 144.0
            func objectPlan(_ caption: String) throws -> TemplateSlidePlan {
                try engine.plan(title: slide.title ?? "", columns: [], preferredTypes: preferred,
                    object: kind, masterURI: template.selectedMasterID, objectCaption: caption,
                    minimumObjectHeight: minimum)
            }
            do {
                _ = try objectPlan(source)
                output.slides.append(slide)
                continue
            } catch is LayoutError {
                // A short pointer must fit too; an incompatible object/template
                // is a different failure and is not hidden by pagination.
                _ = try objectPlan("Full notes and sources follow.")
            }
            var objectSlide = slide
            objectSlide.body?.kicker = nil
            objectSlide.body?.lead = nil
            objectSlide.body?.source = "Full notes and sources follow."
            output.slides.append(objectSlide)
            let words = source.split(whereSeparator: \.isWhitespace)
            func paragraphs(start: Int, count: Int) -> [String] {
                let text = source[words[start].startIndex..<words[start + count - 1].endIndex]
                return text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            }
            var start = 0
            var additions: [String] = []
            while start < words.count {
                try Task.checkCancellation()
                let title = "Notes and sources (\(additions.count + 1))"
                var low = 1, high = words.count - start, accepted = 0
                while low <= high {
                    let count = (low + high) / 2
                    let text = paragraphs(start: start, count: count).map { LayoutParagraph($0) }
                    if (try? engine.plan(title: title, columns: [text], preferredTypes: ["obj", "tx"],
                                         masterURI: template.selectedMasterID)) != nil {
                        accepted = count; low = count + 1
                    } else { high = count - 1 }
                }
                guard accepted > 0 else { throw LayoutError.cannotFit("The template has no readable text layout for notes and sources.") }
                var id = "\(slide.id)-source-notes-\(additions.count + 1)"
                while usedIDs.contains(id) { id += "-next" }
                usedIDs.insert(id)
                let text = paragraphs(start: start, count: accepted)
                output.slides.append(IRSlide(id: id, sectionId: slide.sectionId, layout: "bullets", title: title,
                    body: Body(bullets: text.map { Bullet(text: $0) }), notes: "Notes and sources for: \(slide.title ?? "")"))
                additions.append(id)
                start += accepted
            }
            expansions[slide.id] = additions
            let unit = additions.count == 1 ? "slide" : "slides"
            warnings.append("\(slide.title ?? "Object slide"): full notes and sources continue on \(additions.count) following \(unit) to keep the object readable.")
        }
        output.sections = input.sections?.map { section in
            var updated = section
            updated.slideIds = section.slideIds.flatMap { [$0] + (expansions[$0] ?? []) }
            return updated
        }
        return output
    }

    private static func objectCaption(_ input: IRSlide) -> String {
        let body = input.body
        return [body?.kicker, body?.lead, body?.source, input.kind == .quadrant ? body?.xAxis : nil, input.kind == .quadrant ? body?.yAxis : nil]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private static func plan(_ input: IRSlide, template: PowerPointTemplate, image: Data?,
                             engine: TemplateLayoutEngine, variant: Int) throws
        -> (slide: TemplateSlidePlan, columns: [[LayoutParagraph]], warnings: [String]) {
        var warnings: [String] = []
        let body = input.body
        var columns = textColumns(input)
        let structure = structuredContent(input)
        let panel = PanelRendering.content(input)
        let object: String? = input.kind == .chart ? "chart" : (input.kind == .table ? "tbl" : (structure == nil && panel == nil ? nil : "obj"))
        if object != nil { columns = [] }
        let source = object == nil ? "" : objectCaption(input)
        let minimumObjectHeight = input.kind == .table ? max(144, Double(body?.table?.grid.count ?? 0) * 24) : 144
        let preferred: [String]
        switch input.kind {
        case .title: preferred = ["title", "secHead", "obj"]
        case .closing, .sectionHeader: preferred = ["secHead", "title", "obj"]
        case .twoColumn, .comparison: preferred = ["twoObj", "twoTxTwoObj", "obj"]
        case .chart: preferred = ["chart", "obj"]
        case .table: preferred = ["tbl", "obj"]
        default: preferred = image == nil ? ["obj", "tx"] : ["picTx", "objTx", "obj"]
        }
        let title = input.title ?? body?.claim ?? body?.quote ?? ""
        let validateObject: ((Rect, DeckStyle) throws -> Void)?
        if let panel {
            validateObject = { frame, style in try PanelLayout.validate(kind: panel.0, items: panel.1, in: frame, style: style, engine: engine) }
        } else if let structure {
            validateObject = { frame, style in try StructuredLayout.validate(kind: structure.0, items: structure.1, in: frame, style: style, engine: engine) }
        } else { validateObject = nil }
        let plan: TemplateSlidePlan
        do {
            plan = try engine.plan(title: title, columns: columns, preferredTypes: preferred, object: object,
                                   picture: image != nil, masterURI: template.selectedMasterID, objectCaption: source, minimumObjectHeight: minimumObjectHeight, imageAspect: image.flatMap { ImageSniffer.sniff($0) }.map { Double($0.pixelWidth) / Double($0.pixelHeight) }, variant: variant, table: input.kind == .table ? try body?.table.map { try $0.layoutContent() } : nil, validateObject: validateObject)
        } catch {
            // A single-body corporate layout can still express two columns as
            // two headed sections. Preserve every paragraph and report the change.
            guard columns.count > 1 else { throw error }
            columns = [columns.flatMap { $0 }]
            plan = try engine.plan(title: title, columns: columns, preferredTypes: preferred, object: object,
                                   picture: image != nil, masterURI: template.selectedMasterID, objectCaption: source, minimumObjectHeight: minimumObjectHeight, imageAspect: image.flatMap { ImageSniffer.sniff($0) }.map { Double($0.pixelWidth) / Double($0.pixelHeight) }, variant: variant, table: input.kind == .table ? try body?.table.map { try $0.layoutContent() } : nil, validateObject: validateObject)
            warnings.append("\(title): the template uses one content region; columns were arranged as headed sections.")
        }
        return (plan, columns, warnings)
    }

    static func build(_ input: IRSlide, in deck: Presentation, template: PowerPointTemplate,
                      image: Data?, warnings: inout [String], engine: TemplateLayoutEngine? = nil, variant: Int = 0) throws -> Slide {
        let engine = engine ?? TemplateLayoutEngine(presentation: deck, measure: measurer)
        let planned = try plan(input, template: template, image: image, engine: engine, variant: variant)
        warnings += planned.warnings
        let plan = planned.slide, columns = planned.columns
        let body = input.body
        let title = input.title ?? body?.claim ?? body?.quote ?? ""
        let source = objectCaption(input)
        let panel = PanelRendering.content(input)
        let structure = structuredContent(input)
        let slide = try engine.compose(plan, title: title, columns: columns)
        if let slot = plan.objectSlot, let objectFrame = plan.objectFrame {
            let style = engine.objectStyle(layout: plan.layout, slot: slot.index)
            if let panel {
                let shape = try PanelLayout.compose(kind: panel.0, items: panel.1,
                    in: objectFrame, on: slide, style: style, engine: engine)
                try slide.replacePlaceholder(index: slot.index, with: shape)
            } else if let structure {
                let shape = try StructuredLayout.compose(kind: structure.0, items: structure.1,
                    in: objectFrame, on: slide, style: style, engine: engine)
                try slide.replacePlaceholder(index: slot.index, with: shape)
            } else if let chart = body?.chart, input.kind == .chart {
                let kind: ChartKind
                switch chart.kind.lowercased() {
                case "line": kind = .line
                case "pie": kind = .pie
                case "doughnut": kind = .doughnut
                case "area": kind = .area
                case "radar": kind = .radar
                case "stackedbar": kind = .barStacked
                case "percentstackedbar": kind = .barPercentStacked
                default: kind = .barClustered
                }
                guard !chart.categories.isEmpty, !chart.series.isEmpty,
                      chart.series.allSatisfy({ $0.values.count == chart.categories.count }) else {
                    throw LayoutError.cannotFit("\(title): chart data is incomplete.")
                }
                let shape = try slide.shapes.addChart(kind,
                    data: ChartData(categories: chart.categories, series: chart.series.map { .init(name: $0.name, values: $0.values) }),
                    frame: objectFrame, options: ChartOptions(
                        title: chart.series.count == 1 ? chart.series[0].name : nil,
                        legend: chart.series.count > 1 || ["pie", "doughnut"].contains(chart.kind.lowercased()) ? .bottom : .none,
                        dataLabels: chart.kind == "bar" && chart.categories.count <= 8 ? DataLabelOptions(showValue: true) : nil,
                        valueAxis: AxisOptions(gridlines: false),
                        text: ChartTextStyle(font: style.bodyFont, color: style.ink, sizePt: 16 * engine.objectScale)))
                try slide.replacePlaceholder(index: slot.index, with: shape)
            }

            if let caption = plan.captionFrame {
                let shape = try slide.addText(source, in: caption, role: .caption, style: style)
                let report = try AuthoredLayoutEngine(presentation: deck, measure: measurer).fitText(in: slide, only: [shape.shapeID!])
                for skipped in report.skipped {
                    warnings.append("\(title): the caption was kept at its authored size because it \(skipped.reason)")
                }
            }
        }
        if let image {
            if let slot = plan.pictureSlot, let frame = slot.frame {
                // Generated images may include diagrams and labels. Preserve all
                // pixels; a photo-style cover crop can remove the explanation.
                let fitted = containedImageFrame(image, in: frame)
                let picture = try slide.shapes.addPicture(image, frame: fitted)
                picture.altText = input.image?.prompt
                try slide.replacePlaceholder(index: slot.index, with: picture)
            } else {
                warnings.append("\(title): the template has no picture placeholder; its artwork and background were preserved.")
            }
        }
        return slide
    }

    static func containedImageFrame(_ data: Data, in frame: Rect) -> Rect {
        guard let info = ImageSniffer.sniff(data) else { return frame }
        let scale = min(frame.width.points / Double(info.pixelWidth), frame.height.points / Double(info.pixelHeight))
        let width = Double(info.pixelWidth) * scale, height = Double(info.pixelHeight) * scale
        return Rect(x: .points(frame.x.points + (frame.width.points - width) / 2),
                    y: .points(frame.y.points + (frame.height.points - height) / 2),
                    width: .points(width), height: .points(height))
    }

    static func structuredContent(_ slide: IRSlide) -> (StructuredKind, [StructuredItem])? {
        guard let b = slide.body else { return nil }
        switch slide.kind {
        case .metrics: return (.metrics, (b.stats ?? []).map { StructuredItem($0.value, detail: $0.label) })
        case .bigNumber: return (.metrics, [StructuredItem(b.value ?? "", detail: b.label ?? "")])
        case .timeline: return (.timeline, (b.milestones ?? []).map { StructuredItem($0.label, detail: $0.detail) })
        case .quadrant: return (.quadrant, (b.quadrants ?? []).map { StructuredItem($0.heading, detail: $0.detail) })
        case .diagram: return (StructuredKind(rawValue: b.diagram?.kind ?? "process") ?? .process,
                              (b.diagram?.items ?? []).map { StructuredItem($0) })
        case .bands: return (.bands, (b.items ?? b.bullets?.map(\.text) ?? []).map { StructuredItem($0) })
        default: return nil
        }
    }

    private static func textColumns(_ slide: IRSlide) -> [[LayoutParagraph]] {
        guard let b = slide.body else { return [] }
        func bullets(_ values: [Bullet]?) -> [LayoutParagraph] {
            (values ?? []).flatMap { [LayoutParagraph($0.text)] + ($0.subBullets ?? []).map { LayoutParagraph($0, level: 1) } }
        }
        var before = [b.kicker, b.lead].compactMap { $0 }.filter { !$0.isEmpty }.map { LayoutParagraph($0) }
        var after = b.source.map { [LayoutParagraph($0, role: .caption)] } ?? []
        if slide.kind == .twoColumn || slide.kind == .comparison {
            let left = b.left.map { [LayoutParagraph($0.heading, role: .heading)] + $0.bullets.map { LayoutParagraph($0) } } ?? []
            let right = b.right.map { [LayoutParagraph($0.heading, role: .heading)] + $0.bullets.map { LayoutParagraph($0) } } ?? []
            return [before + left, right + after].filter { !$0.isEmpty }
        }
        switch slide.kind {
        case .title: before += b.subtitle.map { [LayoutParagraph($0)] } ?? []
        case .closing: before += [b.callToAction, b.contact].compactMap { $0 }.map { LayoutParagraph($0) }
        case .quote: before += [b.quote, b.attribution].compactMap { $0 }.map { LayoutParagraph($0) }
        case .bigNumber: before += [b.value, b.label].compactMap { $0 }.map { LayoutParagraph($0) }
        case .metrics: before += (b.stats ?? []).map { LayoutParagraph("\($0.value) — \($0.label)") }
        case .diagram: before += (b.diagram?.items ?? []).map { LayoutParagraph($0) }
        case .timeline: before += (b.milestones ?? []).map { LayoutParagraph("\($0.label) — \($0.detail)") }
        case .quadrant:
            before += (b.quadrants ?? []).map { LayoutParagraph("\($0.heading) — \($0.detail)") }
            after += [b.xAxis, b.yAxis].compactMap { $0 }.map { LayoutParagraph($0) }
        case .statement: before += b.claim.map { [LayoutParagraph($0)] } ?? []
        case .callout: before += b.band.map { [LayoutParagraph($0)] } ?? []; before += bullets(b.bullets)
        default:
            before += (b.items ?? []).map { LayoutParagraph($0) }
            before += bullets(b.bullets)
        }
        let all = before + after
        return all.isEmpty ? [] : [all]
    }
}
