import Foundation
import Rostrum

extension PlatformLabRecipes {
    static func design(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Design and builders"), before = try deck.serializedData()
        let spec = """
        # Library Lab
        ## Fonts
        - Heading: DejaVu Sans
        - Body: DejaVu Sans
        ## Palette
        - Background: #\(options.alternative ? "152330" : "FFFFFF")
        - Text: #\(options.alternative ? "FFFFFF" : "172738")
        - Accent 1: #\(options.accentHex)
        ## Spacing
        - md: 16px
        - lg: 24px
        ## Radius
        - lg: 12px
        ## Direction
        Clear offline component examples.
        """
        let design = Design.parse(spec)
        deck.applyDesign(design)
        try deck.fonts.register(resource("DejaVuSans", "ttf"))
        let style = deck.style, n = options.sampleSize
        let items = (1...n).map { "Item \($0)" }
        let heading = label(options)
        try deck.slides.remove(at: 0)
        try deck.titleSlide(heading, subtitle: "Title builder", kicker: "LIBRARY LAB")
        try deck.sectionSlide("Section", subtitle: heading)
        try deck.closingSlide("Closing", callToAction: heading)
        try deck.bulletSlide("Bullets", items)
        try deck.twoColumnSlide("Two columns", left: items, right: Array(items.reversed()))
        try deck.comparisonSlide("Comparison", leftHeader: "Before", left: items, rightHeader: "After", right: [heading])
        try deck.processSlide("Process", steps: items)
        try deck.pyramidSlide("Pyramid", levels: items)
        try deck.smartArtSlide("Editable diagram", kind: .process, items: items)
        try deck.bandsSlide("Bands", bands: items)
        try deck.metricsSlide("Metrics", metrics: (1...n).map { (value: "\($0 * 10)", label: "Metric \($0)") })
        try deck.chartSlide("Chart", .barClustered, ChartData(categories: items, values: (1...n).map(Double.init)))
        try deck.calloutSlide(stat: "\(n)", caption: "Inputs provided")
        try deck.quoteSlide("A recipe should prove what it produces.", attribution: heading)
        try deck.timelineSlide("Timeline", milestones: items.map { (label: $0, detail: "Verified") })
        try deck.quadrantSlide("Quadrants", quadrants: (1...4).map { (heading: "Q\($0)", detail: heading) }, xAxis: "Effort", yAxis: "Impact")
        try deck.statementSlide("A concrete outcome", detail: heading)
        try deck.calloutBandSlide("Callout band", band: heading, bullets: Array(items.prefix(3)))
        try deck.tableSlide("Table", rows: [["Item", "Count"]] + (1...n).map { ["Item \($0)", "\($0)"] })
        let components = try deck.slides.add()
        try components.setBackground(.solid(style.background))
        let grid = Grid(in: deck.bounds, columns: 3, rows: 3, gutter: .inches(0.2), margin: .inches(0.5))
        let card = try components.addCard(in: grid.cell(column: 0), style: style)
        try components.addText("Card", in: card.content, role: .heading, style: style)
        try components.shapes.addParagraphs([heading, "Paragraph component"], in: grid.cell(column: 1), role: .caption, style: style)
        try components.addBulletList(Array(items.prefix(2)), in: grid.cell(column: 2), style: style, size: 18)
        try components.addKicker("Kicker", in: grid.cell(column: 0, row: 1), style: style)
        try components.addStatTile("\(n)", caption: "Sample size", in: grid.cell(column: 1, row: 1), style: style)
        let cells = grid.cell(column: 2, row: 1).rows(2, gutter: .inches(0.1))
        try components.addButton("Button", in: cells[0], style: style)
        try components.addChip("Chip", in: cells[1], style: style)
        let rule = grid.cell(column: 0, row: 2, columnSpan: 3).split(.vertical, ratio: 0.03)
        try components.addAccentRule(in: rule.0, style: style)
        try components.addText("Components share typography, spacing and contrast tokens.", in: rule.1, role: .caption, style: style)
        let imagePanel = deck.sideImagePanel(options.alternative ? .left : .right)
        let contrast = Color.bestTextColor(on: style.primary)
        let expectedSlides = 20
        // Parsing normalizes attribute order; compare all XML content with both
        // sides at the same representation boundary.
        let emitted = try (0..<deck.slides.count).map { try XML.document(XML.parse(XML.document(deck.slides[$0].part.dom()))) }
        return LibraryLabDraft(deck: deck, before: before, checks: [
            .init("Every shipped builder ran", deck.slides.count == expectedSlides, "19 builders plus a component canvas; requested \(n) items. Process retains \(min(n, SlideCapacity.process)), metrics \(min(n, SlideCapacity.metrics)), table \(min(n + 1, SlideCapacity.tableRows)) rows."),
            .init("Design parser and tokens", design.headingFont == "DejaVu Sans" && design.space("md") == .pixels(16) && design.cornerRadius("lg") == .pixels(12), "Font, spacing and radius tokens parsed from the exported design.md."),
            .init("Automatic contrast and geometry", contrast.contrastRatio(with: style.primary) >= 4.5 && imagePanel.width.rawValue > 0 && card.content.width < card.bounds.width, "Button ink is selected by contrast; grid/card/image-panel geometry is concrete.")
        ], extraFiles: ["design.md": Data(spec.utf8)], verify: { reopened in
            let reopenedXML = try (0..<reopened.slides.count).map { try XML.document(reopened.slides[$0].part.dom()) }
            let outline = reopened.outline()
            return [
                .init("All authored slide content reopened", reopened.slides.count == expectedSlides && reopenedXML == emitted, "Every builder's shape/text XML is preserved, comparing normalized attribute order."),
                .init("Builder chart and table semantics", outline.chartCount == 1 && outline.slides.flatMap(\.tables).first?.rows.count == min(n + 1, SlideCapacity.tableRows), "Actual chart and capped table data are readable."),
                .init("Theme and component text reopened", reopened.theme.majorFont == "DejaVu Sans" && outline.markdown().contains("Components share"), "Theme fonts and component copy survived; in-memory design tokens are not claimed as stored metadata.")
            ]
        })
    }
}
