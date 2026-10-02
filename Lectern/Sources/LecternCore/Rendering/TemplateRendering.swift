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

    static func build(_ input: IRSlide, in deck: Presentation, template: PowerPointTemplate,
                      image: Data?, warnings: inout [String]) throws -> Slide {
        let engine = TemplateLayoutEngine(presentation: deck, measure: measurer)
        let body = input.body
        var columns = textColumns(input)
        let object: String? = input.kind == .chart ? "chart" : (input.kind == .table ? "tbl" : nil)
        if object != nil { columns = [] }
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
                                   picture: image != nil, masterURI: template.selectedMasterID)
        } catch {
            // A single-body corporate layout can still express two columns as
            // two headed sections. Preserve every paragraph and report the change.
            guard columns.count > 1 else { throw error }
            columns = [columns.flatMap { $0 }]
            plan = try engine.plan(title: title, columns: columns, preferredTypes: preferred, object: object,
                                   picture: image != nil, masterURI: template.selectedMasterID)
            warnings.append("\(title): the template uses one content region; columns were arranged as headed sections.")
        }
        if [.metrics, .diagram, .timeline, .quadrant, .bands].contains(input.kind) {
            warnings.append("\(title): structured content was arranged as text within the template's content placeholders.")
        }
        let slide = try engine.compose(plan, title: title, columns: columns)
        if let slot = plan.objectSlot, let frame = slot.frame {
            let source = [body?.kicker, body?.lead, body?.source].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
            let captionHeight: Double = source.isEmpty ? 0 : min(72, frame.height.points * 0.22)
            let objectFrame = Rect(x: frame.x, y: frame.y, width: frame.width,
                                   height: frame.height - .points(captionHeight))
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
                // Retain native table styles/theme references rather than baking
                // per-cell RGB values into a corporate template.
                let shape = slide.shapes.all.last!
                try slide.replacePlaceholder(index: slot.index, with: shape)
            }
            if !source.isEmpty {
                let caption = Rect(x: frame.x, y: objectFrame.maxY + .points(4), width: frame.width,
                                   height: .points(captionHeight - 4))
                let shape = try slide.addText(source, in: caption, role: .caption, style: style)
                try AuthoredLayoutEngine(presentation: deck, measure: measurer).fitText(in: slide, only: [shape.shapeID!])
            }
        }
        if let image {
            if let slot = plan.pictureSlot, let frame = slot.frame {
                let picture = try slide.shapes.addPicture(image, frame: frame, fit: .fill)
                picture.altText = input.image?.prompt
                try slide.replacePlaceholder(index: slot.index, with: picture)
            } else {
                warnings.append("\(title): the template has no picture placeholder; its artwork and background were preserved.")
            }
        }
        return slide
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
