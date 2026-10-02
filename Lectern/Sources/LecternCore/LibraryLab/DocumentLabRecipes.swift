import Foundation
import Rostrum

/// Document operations use only locally authored examples and public Rostrum APIs.
enum DocumentLabRecipes {
    static let catalog: [LibraryLabRecipe] = [
        .init(.slides, title: "Slide lifecycle", summary: "Add, duplicate, move and remove slides, then add live furniture.",
              operations: ["slides.add", "slides.duplicate", "slides.move", "slides.remove", "showDate", "showSlideNumbers", "footer", "addSource"],
              inputs: [.text, .sampleSize, .alternative], alternativeLabel: "Move the copy to the end"),
        .init(.charts, title: "Chart gallery", summary: "Native category, XY and combo charts with editable workbooks.",
              operations: ["addChart", "addScatterChart", "addBubbleChart", "addComboChart", "Chart.series", "Chart.xySeries", "Chart.workbookPart"],
              limitations: ["Preview support varies by chart kind; the saved file retains native charts and embedded workbooks."],
              inputs: [.text, .accent, .sampleSize, .alternative], alternativeLabel: "Include gaps in category data"),
        .init(.chartEditing, title: "Chart editing", summary: "Replace data, append and remove series, and prove invalid edits are atomic.",
              operations: ["Chart.replaceData", "Chart.addSeries", "Chart.removeSeries", "Chart.replacementProblem", "Chart.addSeriesProblem", "Chart.removeSeriesProblem"],
              inputs: [.text, .accent, .sampleSize, .alternative], alternativeLabel: "Edit a line chart"),
        .init(.smartArt, title: "SmartArt", summary: "Create a native Basic Block List and extract its labels.",
              operations: ["addSmartArt", "Slide.smartArtTexts"],
              limitations: ["The local preview does not run PowerPoint’s SmartArt layout engine. Open the PPTX in PowerPoint to see the native diagram; extracted labels are verified here."],
              inputs: [.text, .accent, .sampleSize, .alternative], alternativeLabel: "Also create a Process diagram"),
        .init(.notes, title: "Rich speaker notes", summary: "Format, duplicate, import and independently edit speaker notes.",
              operations: ["setNotes", "appendNote", "notesTextFrame", "notesParagraphs", "slides.duplicate", "slides.import"],
              inputs: [.text, .accent, .sampleSize, .alternative], alternativeLabel: "Replace the copied notes"),
        .init(.comments, title: "Comments and anchors", summary: "Modern threads and legacy comments with editing, replies, resolution and deletion.",
              operations: ["addComment", "Comment.setText", "Comment.addReply", "Comment.resolve", "Comment.reopen", "Comment.setAnchor", "Comment.setPosition", "Comment.delete", "addLegacyComment", "LegacyComment.setText", "LegacyComment.setPosition", "LegacyComment.delete"],
              limitations: ["Comments are verified and included in the report; slide previews do not display a PowerPoint review pane."],
              inputs: [.text, .sampleSize, .alternative], alternativeLabel: "Leave the thread resolved"),
        .init(.sections, title: "Sections", summary: "Maintain section membership through slide edits, reorder sections and remove one.",
              operations: ["setSections", "addSection", "Section.name", "Sections.move", "Sections.remove", "slides.add", "slides.duplicate", "slides.move", "slides.remove"],
              inputs: [.text, .sampleSize, .alternative], alternativeLabel: "Move the first section last"),
        .init(.slideImport, title: "Import slides", summary: "Import one slide and a whole deck, preserving images, notes, comments, layouts and table styles.",
              operations: ["slides.import", "slides.importAll", "addPicture", "setNotes", "addComment", "addLegacyComment", "Table.applyBuiltInStyle"],
              inputs: [.text, .accent, .sampleSize, .alternative], alternativeLabel: "Insert the single import before the destination slide")
    ]

    static func make(_ id: LibraryDemoID, options: LibraryLabOptions) throws -> LibraryLabDraft {
        switch id {
        case .slides: return try slides(options)
        case .charts: return try charts(options)
        case .chartEditing: return try chartEditing(options)
        case .smartArt: return try smartArt(options)
        case .notes: return try notes(options)
        case .comments: return try comments(options)
        case .sections: return try sections(options)
        case .slideImport: return try slideImport(options)
        default: throw RostrumError.packageInvalid("Not a document recipe: \(id.rawValue)")
        }
    }

    private static func count(_ options: LibraryLabOptions) -> Int { min(12, max(2, options.sampleSize)) }
    private static func color(_ options: LibraryLabOptions) -> Color {
        Color(validating: options.accentHex) ?? Color("276D89")
    }
    private static func text(_ slide: Slide) -> String {
        slide.shapes.all.compactMap { $0.textFrame?.text }.joined(separator: "\n")
    }
    private static func firstChart(_ slide: Slide) throws -> Chart {
        guard let chart = slide.charts.first else { throw RostrumError.packageInvalid("Recipe chart missing") }
        return chart
    }
    private static func refusal(_ name: String, deck: Presentation, operation: () throws -> Void) throws -> LibraryLabCheck {
        let before = try deck.serializedData()
        var rejected = false
        do { try operation() } catch { rejected = true }
        let after = try deck.serializedData()
        return LibraryLabCheck(name, rejected && after == before,
                               "The operation must throw and leave every package byte unchanged.")
    }

    private static func slides(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Slide lifecycle")
        let n = count(options)
        for i in 0..<n {
            let slide = i == 0 ? try deck.slides[0] : try deck.slides.add()
            try LibraryLabSupport.text("\(options.text) · Slide \(i + 1)", on: slide)
        }
        let before = try deck.serializedData()
        let original = try deck.slides[0]
        let copied = try deck.slides.duplicate(at: 0)
        copied.shapes.all.first?.textFrame?.text = "\(options.text) · Independent copy"
        var expected = (1...n).map { "\(options.text) · Slide \($0)" }
        expected.insert("\(options.text) · Independent copy", at: 1)
        let destination = options.alternative ? n : 0
        try deck.slides.move(from: 1, to: destination)
        let copyLabel = expected.remove(at: 1)
        expected.insert(copyLabel, at: destination)
        let removed = options.alternative ? 1 : n
        try deck.slides.remove(at: removed)
        expected.remove(at: removed)
        var checks = [LibraryLabCheck("Original text independent", text(original) == "\(options.text) · Slide 1", "Editing the duplicate did not edit the original.")]
        checks.append(try refusal("Out-of-range removal refused", deck: deck) { try deck.slides.remove(at: -1) })
        try deck.showDate()
        try deck.showSlideNumbers()
        try deck.footer("Lectern Library Lab")
        // Keep the source line above the furniture band for a legible preview.
        let source = try deck.addSource("Source: authored lab data", to: deck.slides[0])
        source.frame = LibraryLabSupport.frame(0.6, 5.7, 8, 0.4)
        return LibraryLabDraft(deck: deck, before: before, checks: checks, verify: { reopened in
            let actual = Array(reopened.slides)
            let labels = actual.map { $0.shapes.all.first?.textFrame?.text ?? "" }
            let fields = try actual.map { try $0.part.dom().serialized() }
            return [
                .init("Slide order survives reopen", labels == expected, labels.joined(separator: " → ")),
                .init("Live fields and footer survive", fields.allSatisfy { $0.contains("type=\"slidenum\"") && $0.contains("type=\"datetime\"") } && actual.allSatisfy { text($0).contains("Lectern Library Lab") }, "Every retained slide carries date, slide number and footer."),
                .init("Source line survives", actual.first.map { text($0).contains("Source: authored lab data") } == true, "The first final slide carries the source line.")
            ]
        })
    }

    private static func categoryData(_ options: LibraryLabOptions) -> ChartData {
        let n = count(options)
        return ChartData(categories: (1...n).map { "Sample \($0)" }, series: [
            .init(name: options.text, values: (1...n).map { i -> Double? in options.alternative && i == 2 ? nil : Double(i * 3) }),
            .init(name: "Comparison", values: (1...n).map { Double(n + $0) })
        ])
    }

    private static func charts(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Native chart gallery")
        let data = categoryData(options)
        let palette = [color(options), Color("E2A34A")]
        let styles = ChartOptions(title: options.text, legend: .bottom,
                                  dataLabels: .init(showValue: true, numberFormat: "0"),
                                  valueAxis: .init(min: 0, max: Double(max(48, count(options) * count(options))), majorUnit: 12, title: "Units", gridlines: true),
                                  categoryAxisTitle: "Samples", secondaryValueAxis: .init(title: "Secondary units"),
                                  text: .init(font: "Arial", color: color(options), sizePt: 14))
        let kinds = ChartKind.allCases
        for (index, kind) in kinds.enumerated() {
            let slide = index == 0 ? try deck.slides[0] : try deck.slides.add()
            try LibraryLabSupport.text("\(kind) · \(options.text)", on: slide)
            try slide.shapes.addChart(kind, data: data, frame: LibraryLabSupport.frame(), colors: palette, options: styles)
        }
        let xy = try deck.slides.add()
        try LibraryLabSupport.text("Scatter · \(options.text)", on: xy)
        let points = (1...count(options)).map { (x: Double($0), y: Double($0 * $0)) }
        try xy.shapes.addScatterChart(.init(name: options.text, points: points), frame: LibraryLabSupport.frame(), colors: palette, options: styles)
        let bubbles = try deck.slides.add()
        try LibraryLabSupport.text("Bubble · \(options.text)", on: bubbles)
        let bubblePoints = points.map { BubbleChartData.Point(x: $0.x, y: $0.y, size: $0.x * 5) }
        try bubbles.shapes.addBubbleChart(.init(name: options.text, points: bubblePoints), frame: LibraryLabSupport.frame(), colors: palette, options: styles)
        let combo = try deck.slides.add()
        try LibraryLabSupport.text("Combo · primary bars, secondary line", on: combo)
        try combo.shapes.addComboChart(.init(categories: data.categories, groups: [
            .init(kind: .barClustered, series: [data.series[0]], colors: palette, dataLabels: .init(showValue: true)),
            .init(kind: .line, series: [data.series[1]], axis: .secondary, colors: [palette[1]])
        ]), frame: LibraryLabSupport.frame(), options: styles)
        return LibraryLabDraft(deck: deck, verify: { reopened in
            let all = reopened.charts
            var checks = [LibraryLabCheck("Complete chart gallery", all.count == kinds.count + 3, "Nine category kinds, scatter, bubble and combo.")]
            for (index, kind) in kinds.enumerated() {
                let chart = try firstChart(reopened.slides[index])
                let expected = (kind == .pie || kind == .doughnut) ? [data.series[0]] : data.series
                checks.append(.init("\(kind) data readback", chart.categories == data.categories && chart.series.map(\.name) == expected.map(\.name) && chart.series.map(\.values) == expected.map(\.values), "Categories, series names, values and gaps match the authored dataset."))
            }
            let scatter = try firstChart(reopened.slides[kinds.count])
            let bubble = try firstChart(reopened.slides[kinds.count + 1])
            checks.append(.init("XY points read back", scatter.xySeries.first?.points == points.map { Chart.XYPoint(x: $0.x, y: $0.y) } && bubble.xySeries.first?.points == bubblePoints.map { Chart.XYPoint(x: $0.x, y: $0.y, size: $0.size) }, "Scatter coordinates and bubble sizes survive."))
            let last = try firstChart(reopened.slides[kinds.count + 2])
            checks.append(.init("Combo groups read back", last.isCombo && last.plotTypes == ["barChart", "lineChart"] && last.series.map(\.values) == data.series.map(\.values), "Primary bars and secondary line share categories."))
            checks.append(.init("Titles and workbooks survive", all.allSatisfy { $0.title == options.text && $0.workbookPart?.blob.isEmpty == false }, "Every chart has its authored title and editable workbook."))
            let xml = try firstChart(reopened.slides[0]).part.dom().serialized()
            checks.append(.init("Chart appearance survives", xml.contains("Units") && xml.contains("Samples") && xml.contains("showVal") && xml.contains(color(options).hex), "Axis titles, labels and selected series color survive."))
            return checks
        })
    }

    private static func chartEditing(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Edit native chart data")
        let slide = try deck.slides[0]
        try LibraryLabSupport.text("Replace, add and remove series", on: slide)
        let initial = categoryData(options)
        try slide.shapes.addChart(options.alternative ? .line : .barClustered, data: initial,
                                  frame: LibraryLabSupport.frame(), colors: [color(options)], options: .init(title: options.text))
        let chart = try firstChart(slide)
        let before = try deck.serializedData()
        let replacement = ChartData(categories: initial.categories.map { "Revised \($0)" }, series: initial.series.map {
            .init(name: "Updated \($0.name)", values: $0.values.map { $0.map { $0 + 10 } })
        })
        let problem = chart.replacementProblem(for: replacement)
        try chart.replaceData(replacement)
        let workbookBeforeAdd = chart.workbookPart?.blob
        let appended = (1...count(options)).map { Double($0 * 7) as Double? }
        let addProblem = chart.addSeriesProblem(name: "Added", values: appended)
        try chart.addSeries(name: "Added", values: appended)
        var checks: [LibraryLabCheck] = [
            .init("Replacement and addition preflight", problem == nil && addProblem == nil, "Both valid operations are permitted."),
            .init("Existing series preserved by append", Array(chart.series.prefix(2)).map(\.values) == replacement.series.map(\.values), "Appending preserves both previously edited series."),
            .init("Workbook updated on append", chart.workbookPart?.blob != workbookBeforeAdd, "The embedded workbook changes together with the series caches.")
        ]
        let removeProblem = chart.removeSeriesProblem(at: 1)
        try chart.removeSeries(at: 1)
        checks.append(.init("Removal preflight", removeProblem == nil, "The comparison series can be removed."))
        let bad = ChartData(categories: ["Wrong count"], name: "Rejected", values: [1])
        checks.append(.init("Replacement mismatch diagnosed", chart.replacementProblem(for: bad) != nil, "The preflight identifies incompatible replacement dimensions."))
        checks.append(try refusal("Replacement refusal is atomic", deck: deck) { try chart.replaceData(bad) })
        checks.append(try refusal("Add-series refusal is atomic", deck: deck) { try chart.addSeries(name: "Rejected", values: [1]) })
        checks.append(try refusal("Remove-series refusal is atomic", deck: deck) { try chart.removeSeries(at: 99) })
        return LibraryLabDraft(deck: deck, before: before, checks: checks, verify: { reopened in
            let saved = try firstChart(reopened.slides[0])
            return [.init("Edited categories and series survive", saved.categories == replacement.categories && saved.series.map(\.name) == [replacement.series[0].name, "Added"] && saved.series.map(\.values) == [replacement.series[0].values, appended], "Updated first series and appended series remain; comparison is absent."),
                    .init("Chart formatting survives edits", try saved.title == options.text && saved.part.dom().serialized().contains(color(options).hex), "Title and original series color remain after data edits.")]
        })
    }

    private static func smartArt(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "SmartArt and text extraction")
        let labels = (1...count(options)).map { "\(options.text) · Step \($0)" }
        let layouts: [SmartArt.Layout] = options.alternative ? [.blockList, .process] : [.blockList]
        for (index, layout) in layouts.enumerated() {
            let slide = index == 0 ? try deck.slides[0] : try deck.slides.add()
            try LibraryLabSupport.text("SmartArt \(layout) — native diagram in PPTX", on: slide)
            try slide.shapes.addSmartArt(items: labels, frame: LibraryLabSupport.frame(0.7, 1.1, 8, 4.4), colors: [color(options)], layout: layout)
            try LibraryLabSupport.text("Preview: labels verified; PowerPoint runs the diagram layout.", on: slide, frame: LibraryLabSupport.frame(0.6, 6, 12, 0.5))
        }
        return LibraryLabDraft(deck: deck, extraFiles: ["smartart-labels.txt": Data(labels.joined(separator: "\n").utf8)], verify: { reopened in
            [.init("Native SmartArt labels survive", Array(reopened.slides).map(\.smartArtTexts) == layouts.map { _ in [labels] }, "Every item is extracted in order from the saved diagram data."),
             .init("SmartArt dependency parts survive", reopened.package.parts.values.filter { $0.contentType.contains("drawingml.diagram") }.count == layouts.count * 4, "Each diagram retains data, layout, quick style and colors.")]
        })
    }

    private static func notes(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Independent rich notes")
        let original = try deck.slides[0]
        try LibraryLabSupport.text("Original notes", on: original)
        let paragraphs = (1...count(options)).map { "\(options.text) · Cue \($0)" }
        try original.setNotes(paragraphs)
        let run = try original.notesTextFrame().paragraphs[0].runs[0]
        run.bold = true
        run.fontSize = 22
        run.color = color(options)
        let before = try deck.serializedData()
        let copied = try deck.slides.duplicate(at: 0)
        copied.shapes.all.first?.textFrame?.text = "Duplicated notes"
        if options.alternative { try copied.setNotes("Replacement on copy") } else { try copied.appendNote("Copy only") }
        let source = try LibraryLabSupport.deck(title: "Notes import source")
        let sourceSlide = try source.slides[0]
        try LibraryLabSupport.text("Imported notes", on: sourceSlide)
        try sourceSlide.setNotes(["Import source", options.text])
        try sourceSlide.notesTextFrame().paragraphs[0].runs[0].italic = true
        let sourceBefore = try source.serializedData()
        let imported = try deck.slides.import(from: source, at: 0)
        try imported.appendNote("Imported only")
        try original.appendNote("Original only")
        let expectedCopy = options.alternative ? ["Replacement on copy"] : paragraphs + ["Copy only"]
        return LibraryLabDraft(deck: deck, before: before,
                               checks: [.init("Source notes unchanged", try source.serializedData() == sourceBefore, "Import and editing the imported notes did not change the source package.")],
                               extraFiles: ["notes-source.pptx": sourceBefore], verify: { reopened in
            let slides = Array(reopened.slides)
            let originalRun = try slides[0].notesTextFrame().paragraphs[0].runs[0]
            let importedRun = try slides[2].notesTextFrame().paragraphs[0].runs[0]
            return [.init("Notes remain independent", slides.map(\.notesParagraphs) == [paragraphs + ["Original only"], expectedCopy, ["Import source", options.text, "Imported only"]], "The three slides have distinct expected paragraphs."),
                    .init("Rich formatting survives", originalRun.bold && originalRun.fontSize == 22 && originalRun.color == color(options) && importedRun.italic, "Original bold/color/size and imported italic remain."),
                    .init("Duplicated rich formatting survives", try options.alternative || slides[1].notesTextFrame().paragraphs[0].runs[0].bold, "The append variant retains the copied rich run; replacement deliberately replaces it.")]
        })
    }

    private static func comments(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Comment editing")
        let slide = try deck.slides[0]
        let box = try slide.shapes.addTextBox(LibraryLabSupport.frame(1, 1, 10, 2))
        box.textFrame?.text = "Review 😀 \(options.text)"
        let thread = try slide.addComment("Original comment", author: "Lab Reviewer", initials: "LR")
        guard case .slide(let slideID) = thread.anchor, let shapeID = box.shapeID else {
            throw RostrumError.packageInvalid("Authored comment anchor missing")
        }
        let id = thread.id
        let timestamp = thread.createdTimestamp
        let legacy = try slide.addLegacyComment("Original legacy", author: "Legacy Reviewer", initials: "LC")
        let before = try deck.serializedData()
        try thread.setText("\(options.text)\nEdited thread")
        try thread.setAnchor(.shape(slideID: slideID, shapeID: shapeID))
        let shapeAnchorWorked = thread.anchor == .shape(slideID: slideID, shapeID: shapeID)
        let anchor = CommentAnchor.text(slideID: slideID, shapeID: shapeID, start: 7, length: 2)
        try thread.setAnchor(anchor)
        try thread.setPosition(x: .inches(2), y: .inches(1))
        for i in 1...count(options) {
            let reply = try thread.addReply("Reply \(i)", author: "Lab Editor", initials: "LE")
            try reply.setText("Edited reply \(i)")
        }
        let temporaryReply = try thread.addReply("Delete this reply", author: "Lab Editor")
        try temporaryReply.delete()
        let resolved = thread.resolve() && thread.isResolved
        let reopened = thread.reopen() && !thread.isResolved
        if options.alternative { _ = thread.resolve() }
        let deleted = try slide.addComment("Delete this thread", author: "Lab Reviewer")
        try deleted.delete()
        try legacy.setText("\(options.text) · Edited legacy")
        try legacy.setPosition(x: .inches(3), y: .inches(2))
        let temporaryLegacy = try slide.addLegacyComment("Delete this legacy", author: "Legacy Reviewer")
        try temporaryLegacy.delete()
        var checks: [LibraryLabCheck] = [
            .init("Resolve and reopen execute", resolved && reopened, "Both status transitions were observed before choosing the final status."),
            .init("Shape anchor executes", shapeAnchorWorked, "The thread first targeted the text box, then its emoji text range.")
        ]
        checks.append(try refusal("Invalid anchor refused atomically", deck: deck) { try thread.setAnchor(.shape(slideID: slideID, shapeID: Int.max)) })
        checks.append(try refusal("Nested reply refused atomically", deck: deck) { _ = try thread.replies[0].addReply("Invalid", author: "No author added") })
        return LibraryLabDraft(deck: deck, before: before, checks: checks, verify: { reopened in
            let savedSlide = try reopened.slides[0]
            let saved = savedSlide.comments.first
            let old = savedSlide.legacyComments.first
            return [.init("Edited modern thread survives", savedSlide.comments.count == 1 && saved?.text == "\(options.text)\nEdited thread" && saved?.id == id && saved?.createdTimestamp == timestamp && saved?.authorName == "Lab Reviewer", "Identity and author are preserved; the temporary thread is gone."),
                    .init("Replies and status survive", saved?.replies.map(\.text) == (1...count(options)).map { "Edited reply \($0)" } && saved?.isResolved == options.alternative, "Edited replies remain; the deleted reply is absent."),
                    .init("Text anchor and position survive", saved?.anchor == anchor && saved?.position?.x == .inches(2) && saved?.position?.y == .inches(1), "The UTF-16 range selects the emoji, with explicit slide position."),
                    .init("Legacy edit and deletion survive", savedSlide.legacyComments.count == 1 && old?.text == "\(options.text) · Edited legacy" && old?.position?.x == .inches(3) && old?.position?.y == .inches(2) && old?.authorName == "Legacy Reviewer", "Legacy text, author and position remain; the temporary legacy comment is gone.")]
        })
    }

    private static func sections(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Section lifecycle")
        for i in 0..<(count(options) + 2) {
            let slide = i == 0 ? try deck.slides[0] : try deck.slides.add()
            try LibraryLabSupport.text("\(options.text) · Slide \(i + 1)", on: slide)
        }
        try deck.setSections([("Opening", 0), ("Body", 2)])
        try deck.addSection("Closing", startingAtSlide: deck.slides.count - 1)
        try deck.sections[0].name = "\(options.text) · Opening"
        let before = try deck.serializedData()
        let openingID = try deck.sections[0].id
        try deck.slides.duplicate(at: 0)
        let duplicationCorrect = try deck.sections[0].slideIndices == [0, 1, 2]
        try deck.slides.add()
        let appendCorrect = try deck.sections[2].slideCount == 2
        try LibraryLabSupport.text("Appended in Closing", on: deck.slides[deck.slides.count - 1])
        try deck.slides.move(from: 0, to: 2)
        let moveCorrect = try deck.sections[0].slideIndices == [0, 1] && deck.sections[1].slideIndices.contains(2)
        try deck.slides.remove(at: 1)
        let removeCorrect = try deck.sections[0].slideCount == 1
        let sectionOrder = Array(deck.sections)
        let expectedOrder: [Section] = options.alternative ? [sectionOrder[1], sectionOrder[2], sectionOrder[0]] : [sectionOrder[2], sectionOrder[0], sectionOrder[1]]
        let expectedTexts = expectedOrder.flatMap(\.slides).map(text)
        try deck.sections.move(from: options.alternative ? 0 : 2, to: options.alternative ? 2 : 0)
        let movedCorrect = Array(deck.slides).map(text) == expectedTexts
        let namesBeforeRemove = Array(deck.sections).map(\.name)
        try deck.sections.remove(at: 1)
        var names = namesBeforeRemove
        names.remove(at: 1)
        var checks: [LibraryLabCheck] = [
            .init("Slide membership maintained", duplicationCorrect && appendCorrect && moveCorrect && removeCorrect, "Duplicate joins original section; append joins last; move transfers ownership; remove updates membership."),
            .init("Section move carries its slides", movedCorrect, "Moving the entire section produces the independently predicted slide order."),
            .init("Original section identity stable", sectionOrder[0].id == openingID, "Slide operations preserve the section identity.")
        ]
        checks.append(try refusal("Invalid section move is atomic", deck: deck) { try deck.sections.move(from: 99, to: 0) })
        return LibraryLabDraft(deck: deck, before: before, checks: checks, verify: { reopened in
            let indices = Array(reopened.sections).flatMap(\.slideIndices)
            return [.init("Sections survive reorder and removal", Array(reopened.sections).map(\.name) == names && Array(reopened.slides).map(text) == expectedTexts, "Removing a section preserves slide order and transfers its membership."),
                    .init("Every slide belongs exactly once", indices == Array(0..<reopened.slides.count) && Set(indices).count == indices.count, "The remaining sections form a complete ordered partition.")]
        })
    }

    private static func slideImport(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let source = try LibraryLabSupport.deck(title: "Import source")
        let n = count(options)
        let style: BuiltInTableStyle = .themedStyle1Accent1
        for i in 0..<n {
            let slide = i == 0 ? try source.slides[0] : try source.slides.add(clonedFrom: source.layouts[0])
            try LibraryLabSupport.text("\(options.text) · Source \(i + 1)", on: slide)
            try slide.setBackground(.solid(color(options)))
            for run in slide.shapes.all.flatMap({ $0.textFrame?.paragraphs.flatMap(\.runs) ?? [] }) {
                run.color = Color.bestTextColor(on: color(options))
            }
            try slide.shapes.addPicture(LibraryLabSupport.pixels, frame: LibraryLabSupport.frame(0.8, 1.1, 2, 2))
            let table = try slide.shapes.addTable(rows: 2, columns: 2, frame: LibraryLabSupport.frame(3.2, 1.1, 6, 2))
            table.applyBuiltInStyle(style)
            try table.cell(0, 0).text = "Source \(i + 1)"
            try table.cell(1, 1).text = options.text
            try slide.setNotes(["Speaker notes \(i + 1)", options.text])
            try slide.addComment("Review source \(i + 1)", author: "Source Reviewer")
            try slide.addLegacyComment("Legacy source \(i + 1)", author: "Source Archivist")
        }
        let sourceData = try source.serializedData()
        let deck = try LibraryLabSupport.deck(title: "Slide import destination")
        try LibraryLabSupport.text("Destination original", on: deck.slides[0])
        let before = try deck.serializedData()
        let singleIndex = options.alternative ? 0 : 1
        let single = try deck.slides.import(from: source, at: 0, insertAt: singleIndex)
        let imported = try deck.slides.importAll(from: source)
        try single.appendNote("Single import only")
        try single.comments[0].setText("Single import edited")
        let checks = [LibraryLabCheck("Import source unchanged", try source.serializedData() == sourceData, "Single and bulk imports plus destination edits leave the complete source package byte-identical.")]
        return LibraryLabDraft(deck: deck, before: before, checks: checks, extraFiles: ["import-source.pptx": sourceData], verify: { reopened in
            let all = Array(reopened.slides)
            let savedSingle = try reopened.slides[singleIndex]
            let bulk = Array(all.suffix(imported.count))
            let copiedSlides = [savedSingle] + bulk
            let destinationIndex = options.alternative ? 1 : 0
            let images = copiedSlides.flatMap { $0.shapes.all.compactMap { $0 as? Picture } }
            let tables = copiedSlides.flatMap { $0.shapes.all.compactMap { ($0 as? TableFrame)?.table } }
            let layouts = try copiedSlides.map { try $0.part.related(by: RelType.slideLayout, in: reopened.package) }
            return [.init("Import ordering and destination survive", all.count == n + 2 && text(all[destinationIndex]) == "Destination original" && bulk.enumerated().allSatisfy { text($0.element).contains("\(options.text) · Source \($0.offset + 1)") }, "Single import uses the selected position; bulk import preserves source order."),
                    .init("Images and table styles survive", images.count == n + 1 && images.allSatisfy { $0.imageData == LibraryLabSupport.pixels } && tables.count == n + 1 && tables.allSatisfy { $0.builtInStyle == style }, "All imported slides retain exact image bytes and the native table style."),
                    .init("Layouts and backgrounds survive", layouts.count == n + 1 && layouts.allSatisfy { $0.contentType == ContentType.slideLayout } && copiedSlides.allSatisfy { $0.solidBackground == color(options) }, "Every imported slide resolves its copied layout and selected background."),
                    .init("Notes and modern comments independent", savedSingle.notesParagraphs == ["Speaker notes 1", options.text, "Single import only"] && savedSingle.comments.first?.text == "Single import edited" && bulk.enumerated().allSatisfy { $0.element.notesParagraphs == ["Speaker notes \($0.offset + 1)", options.text] && $0.element.comments.first?.text == "Review source \($0.offset + 1)" }, "Editing the single import did not change any bulk import."),
                    .init("Legacy comments survive import", copiedSlides.allSatisfy { $0.legacyComments.count == 1 && $0.legacyComments[0].authorName == "Source Archivist" }, "Legacy comment parts and author mappings remain reachable.")]
        })
    }
}
