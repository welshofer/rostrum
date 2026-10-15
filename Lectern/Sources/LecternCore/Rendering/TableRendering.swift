import Foundation
import Rostrum
import RostrumLayout

/// Production table composition shares the library's measured width search and
/// row pagination. Plans live for one render and are rechecked before writing.
enum TableRendering {
    struct Group {
        let plan: TemplateTablePaginationPlan
        let ids: [String]
    }
    struct Notes {
        let plan: TemplateSlidePlan
        let columns: [[LayoutParagraph]]
    }
    struct Prepared {
        var deck: DeckIR
        var groups: [String: Group] = [:]
        var notes: [String: Notes] = [:]
        var warnings: [String] = []
    }

    static func prepare(_ input: DeckIR, engine: TemplateLayoutEngine,
                        masterURI: String? = nil, templateBacked: Bool = true) throws -> Prepared {
        var result = Prepared(deck: input)
        result.deck.slides = []
        var usedIDs = Set(input.slides.map(\.id))
        var expansions: [String: [String]] = [:]
        func uniqueID(_ proposed: String) -> String {
            var id = proposed
            while usedIDs.contains(id) { id += "-next" }
            usedIDs.insert(id)
            return id
        }
        for original in input.slides {
            try Task.checkCancellation()
            guard original.kind == .table, let table = original.body?.table else {
                result.deck.slides.append(original); continue
            }
            // Retain ragged input cells, including values beyond the headers.
            let width = table.grid.map(\.count).max() ?? 0
            let rows = table.grid.map { $0 + Array(repeating: "", count: width - $0.count) }
            let content = TemplateTableContent(rows: rows, columnSizing: .measured())
            let title = original.title ?? ""
            let caption = [original.body?.kicker, original.body?.lead, original.body?.source]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
            func plan(_ caption: String) throws -> TemplateTablePaginationPlan {
                try PipelineTrace.measure("layout.tablePlan") {
                    try engine.planTablePages(title: title, table: content, caption: caption,
                        preferredTypes: ["tbl", "obj"], masterURI: masterURI)
                }
            }
            let pagination: TemplateTablePaginationPlan
            var spilledCaption: String?
            do { pagination = try plan(caption) }
            catch let error as LayoutError {
                guard !caption.isEmpty else { throw error }
                // A row that cannot fit even with a short pointer must fail;
                // never truncate or squeeze it into an accepted deck.
                pagination = try plan("Full notes and sources follow.")
                spilledCaption = caption
            }
            var ids: [String] = []
            for (index, page) in pagination.pages.enumerated() {
                var slide = original
                if index > 0 { slide.id = uniqueID(original.id + "-continued-\(index + 1)") }
                slide.body?.table = IRTable(headers: rows[0], rows: page.bodyRows.map { rows[$0] })
                if spilledCaption != nil {
                    slide.body?.kicker = nil; slide.body?.lead = nil
                    slide.body?.source = pagination.caption
                }
                result.deck.slides.append(slide)
                ids.append(slide.id)
            }
            result.groups[original.id] = Group(plan: pagination, ids: ids)
            if ids.count > 1 {
                result.warnings.append("\(title): table rows continue across \(ids.count) slides with repeated headers and consistent measured columns.")
            }
            if let spilledCaption {
                let noteTitle = "Notes and sources"
                let paragraphs = spilledCaption.components(separatedBy: .newlines)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                // Planning this one source block is synchronous and does not
                // mutate the deck/fonts. Reuse accepted decisions when the
                // paginator probes a boundary that final page construction asks
                // for again. Composition still freshly validates every page.
                // Exact UTF-8 keys avoid conflating canonically equivalent text.
                var notePlans: [[Data]: TemplateSlidePlan] = [:]
                var retainedBytes = 0
                func notePlan(_ text: [String]) throws -> TemplateSlidePlan {
                    try Task.checkCancellation()
                    let key = text.map { Data($0.utf8) }
                    if let cached = notePlans[key] {
                        return PipelineTrace.measure("layout.tableSourceNotes.cacheHit") { cached }
                    }
                    let plan = try PipelineTrace.measure("layout.tableSourceNotes") {
                        try engine.plan(title: noteTitle, columns: [text.map { LayoutParagraph($0) }],
                            preferredTypes: ["obj", "tx"], masterURI: masterURI)
                    }
                    let bytes = key.reduce(0) { $0 + $1.count }
                    if notePlans.count < 128, bytes <= 256 * 1024 - retainedBytes {
                        notePlans[key] = plan; retainedBytes += bytes
                    }
                    return plan
                }
                if !templateBacked {
                    // Authored notes must use the ordinary text builder's content
                    // area, which reserves space for running footers and numbers.
                    let id = uniqueID(original.id + "-source-notes-1")
                    result.deck.slides.append(IRSlide(id: id, sectionId: original.sectionId,
                        layout: "bullets", title: noteTitle,
                        body: Body(bullets: paragraphs.map { Bullet(text: $0) }), notes: original.notes))
                    ids.append(id)
                } else {
                    func fits(_ text: [String]) throws -> Bool {
                        try Task.checkCancellation()
                        do { _ = try notePlan(text); return true }
                        catch is LayoutError { return false }
                    }
                    let pieces = try paragraphs.flatMap { paragraph in
                        try MeasuredPaginator.text(paragraph) { try fits([$0]) }
                    }
                    let pages = try MeasuredPaginator.pages(pieces, fits: fits)
                    for (index, text) in pages.enumerated() {
                        let id = uniqueID(original.id + "-source-notes-\(index + 1)")
                        let columns = [text.map { LayoutParagraph($0) }]
                        result.notes[id] = Notes(plan: try notePlan(text), columns: columns)
                        result.deck.slides.append(IRSlide(id: id, sectionId: original.sectionId,
                            layout: "bullets", title: noteTitle,
                            body: Body(bullets: text.map { Bullet(text: $0) }), notes: original.notes))
                        ids.append(id)
                    }
                }
                result.warnings.append("\(title): full notes and sources follow the table at a readable size.")
            }
            expansions[original.id] = ids
        }
        result.deck.sections = input.sections?.map { section in
            var updated = section
            updated.slideIds = section.slideIds.flatMap { expansions[$0] ?? [$0] }
            return updated
        }
        return result
    }
}
