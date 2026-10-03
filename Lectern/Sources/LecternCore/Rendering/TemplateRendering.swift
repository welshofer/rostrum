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

    /// Expand an object slide only when its complete caption cannot coexist with
    /// a readable chart/table in any supplied layout. Retain all text visibly on
    /// following template slides instead of discarding it or failing the deck.
    static func prepare(_ input: DeckIR, in deck: Presentation, template: PowerPointTemplate,
                        warnings: inout [String]) throws -> DeckIR {
        let engine = TemplateLayoutEngine(presentation: deck, measure: measurer)
        var output = input
        output.slides = []
        var usedIDs = Set(input.slides.map(\.id))
        var expansions: [String: [String]] = [:]
        for slide in input.slides {
            try Task.checkCancellation()
            guard slide.kind == .chart || slide.kind == .table,
                  let body = slide.body else { output.slides.append(slide); continue }
            let source = [body.kicker, body.lead, body.source].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
            guard !source.isEmpty else { output.slides.append(slide); continue }
            let kind = slide.kind == .chart ? "chart" : "tbl"
            let preferred = [kind, "obj"]
            let minimum = slide.kind == .table ? max(144, Double(body.table?.grid.count ?? 0) * 24) : 144
            func objectPlan(_ caption: String) throws -> TemplateSlidePlan {
                try engine.plan(title: slide.title ?? "", columns: [], preferredTypes: preferred,
                    object: kind, masterURI: template.selectedMasterID, objectCaption: caption,
                    minimumObjectHeight: minimum, measureObjectHeight: tableMeasurer(body.table, engine: engine))
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
                var id = "\(slide.id)-notes-\(additions.count + 1)"
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

    static func build(_ input: IRSlide, in deck: Presentation, template: PowerPointTemplate,
                      image: Data?, warnings: inout [String]) throws -> Slide {
        let engine = TemplateLayoutEngine(presentation: deck, measure: measurer)
        let body = input.body
        var columns = textColumns(input)
        let object: String? = input.kind == .chart ? "chart" : (input.kind == .table ? "tbl" : nil)
        if object != nil { columns = [] }
        let source = object == nil ? "" : [body?.kicker, body?.lead, body?.source]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
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
        let plan: TemplateSlidePlan
        do {
            plan = try engine.plan(title: title, columns: columns, preferredTypes: preferred, object: object,
                                   picture: image != nil, masterURI: template.selectedMasterID, objectCaption: source, minimumObjectHeight: minimumObjectHeight, measureObjectHeight: tableMeasurer(body?.table, engine: engine))
        } catch {
            // A single-body corporate layout can still express two columns as
            // two headed sections. Preserve every paragraph and report the change.
            guard columns.count > 1 else { throw error }
            columns = [columns.flatMap { $0 }]
            plan = try engine.plan(title: title, columns: columns, preferredTypes: preferred, object: object,
                                   picture: image != nil, masterURI: template.selectedMasterID, objectCaption: source, minimumObjectHeight: minimumObjectHeight, measureObjectHeight: tableMeasurer(body?.table, engine: engine))
            warnings.append("\(title): the template uses one content region; columns were arranged as headed sections.")
        }
        if [.metrics, .diagram, .timeline, .quadrant, .bands].contains(input.kind) {
            warnings.append("\(title): structured content was arranged as text within the template's content placeholders.")
        }
        let slide = try engine.compose(plan, title: title, columns: columns)
        if let slot = plan.objectSlot, let objectFrame = plan.objectFrame {
            let style = plan.layout.master?.theme.map { DeckStyle(theme: $0) } ?? deck.style
            if let chart = body?.chart, input.kind == .chart {
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
                    frame: objectFrame)
                try slide.replacePlaceholder(index: slot.index, with: shape)
            } else if let table = body?.table, input.kind == .table {
                guard !table.headers.isEmpty else { throw LayoutError.cannotFit("\(title): table has no columns.") }
                let native = try slide.shapes.addTable(rows: table.grid.count, columns: table.headers.count, frame: objectFrame)
                native.setContents(table.grid)
                let heights = tableRowHeights(table, width: objectFrame.width.points, style: style, engine: engine)
                let extra = max(0, objectFrame.height.points - heights.reduce(0, +)) / Double(max(1, heights.count))
                native.rowHeights(heights.map { .points($0 + extra) })
                for r in 0..<native.rowCount {
                    for c in 0..<native.columnCount {
                        for p in try native.cell(r, c).textFrame.paragraphs {
                            for run in p.runs { run.fontSize = 18; run.fontName = "+mn-lt" }
                        }
                    }
                }
                // Retain native table styles/theme references rather than baking
                // per-cell RGB values into a corporate template.
                let shape = slide.shapes.all.last!
                try slide.replacePlaceholder(index: slot.index, with: shape)
            }
            if let caption = plan.captionFrame {
                let shape = try slide.addText(source, in: caption, role: .caption, style: style)
                try AuthoredLayoutEngine(presentation: deck, measure: measurer).fitText(in: slide, only: [shape.shapeID!])
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

    private static func tableMeasurer(_ table: IRTable?, engine: TemplateLayoutEngine) -> ((Double, DeckStyle) -> Double)? {
        guard let table else { return nil }
        return { width, style in tableRowHeights(table, width: width, style: style, engine: engine).reduce(0, +) }
    }

    static func tableRowHeights(_ table: IRTable, width: Double, style: DeckStyle, engine: TemplateLayoutEngine) -> [Double] {
        let columnWidth = width / Double(max(1, table.headers.count))
        return table.grid.enumerated().map { index, row in
            var textStyle = style.type(.body)
            textStyle.sizePt = 18
            textStyle.weight = index == 0 ? 700 : 400
            textStyle.lineHeight = 1.2
            // PowerPoint's default table-cell margins: 7.2pt horizontally,
            // 3.6pt vertically. Leave additional rounding/font fallback slack.
            return max(30, row.map {
                engine.measuredHeight($0, style: textStyle, width: max(1, columnWidth - 14.4)) + 10
            }.max() ?? 30)
        }
    }

    private static func textColumns(_ slide: IRSlide) -> [[LayoutParagraph]] {
        guard let b = slide.body else { return [] }
        func bullets(_ values: [Bullet]?) -> [LayoutParagraph] {
            (values ?? []).flatMap { [LayoutParagraph($0.text)] + ($0.subBullets ?? []).map { LayoutParagraph($0, level: 1) } }
        }
        var before = [b.kicker, b.lead].compactMap { $0 }.filter { !$0.isEmpty }.map { LayoutParagraph($0) }
        var after = b.source.map { [LayoutParagraph($0)] } ?? []
        if slide.kind == .twoColumn || slide.kind == .comparison {
            let left = b.left.map { [LayoutParagraph($0.heading)] + $0.bullets.map { LayoutParagraph($0) } } ?? []
            let right = b.right.map { [LayoutParagraph($0.heading)] + $0.bullets.map { LayoutParagraph($0) } } ?? []
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
