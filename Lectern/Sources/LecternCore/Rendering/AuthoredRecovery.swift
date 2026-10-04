import Foundation
import Rostrum

extension DeckRenderer {
    /// Replace a continuation group while retaining existing slide identities,
    /// review annotations and section IDs. New pages join the original section.
    static func replaceAuthoredPages(in deck: Presentation, startingAt index: Int,
                                     with rendered: Presentation, input: IRSlide,
                                     savedIDs: Set<String>) throws {
        func name(_ slide: Slide) throws -> String {
            try slide.part.dom().firstChild(named: "p:cSld")?[attribute: "name"] ?? ""
        }
        var oldCount = 1
        while index + oldCount < deck.slides.count {
            let value = try name(deck.slides[index + oldCount])
            guard (value.hasPrefix("Lectern:" + input.id + "-continued-") || value.hasPrefix("Lectern:" + input.id + "-source-notes")),
                  !savedIDs.contains(String(value.dropFirst("Lectern:".count))) else { break }
            oldCount += 1
        }
        // A shorter alternative must not erase review work or leave inbound
        // links pointing at removed slides. Keep the original copy intact.
        if rendered.slides.count < oldCount {
            throw RenderError.renderFailed(underlying:
                "This alternative needs fewer continuation pages. Open the saved content to rebuild the whole deck; this copy and its review annotations were left unchanged.")
        }
        let main = try deck.package.mainDocumentPart()
        let dom = try main.dom()
        let idsBefore = dom.firstChild(named: "p:sldIdLst")?.childElements.compactMap { $0[attribute: "id"] } ?? []
        let sections = dom.firstChild(named: "p:extLst")?.children(named: "p:ext")
            .flatMap { $0.firstChild(named: "p14:sectionLst")?.children(named: "p14:section") ?? [] } ?? []
        let sectionList = sections.compactMap { $0.firstChild(named: "p14:sldIdLst") }.first {
            $0.childElements.contains { $0[attribute: "id"] == idsBefore[index] }
        }
        var names = Set(try deck.slides.map { try name($0) })
        var newIDs: [String] = []
        for offset in 0..<rendered.slides.count {
            try Task.checkCancellation()
            let imported = try deck.slides.import(from: rendered, at: offset)
            if offset < oldCount {
                let existing = try deck.slides[index + offset]
                let oldName = try name(existing)
                try existing.replaceVisualContents(with: imported)
                try existing.part.dom().firstChild(named: "p:cSld")?[attribute: "name"] = oldName
                existing.part.markDirty()
                try deck.slides.remove(at: deck.slides.count - 1)
            } else {
                var value = try name(rendered.slides[offset])
                while names.contains(value) { value += "-next" }
                names.insert(value)
                try imported.part.dom().firstChild(named: "p:cSld")?[attribute: "name"] = value
                imported.part.markDirty()
                if let id = dom.firstChild(named: "p:sldIdLst")?.childElements.last?[attribute: "id"] { newIDs.append(id) }
                try deck.slides.move(from: deck.slides.count - 1, to: index + offset)
            }
        }
        if let sectionList, !newIDs.isEmpty {
            // Slide import/move now maintains membership automatically. Remove
            // those provisional memberships before assigning continuation pages
            // to their original section, including insertion at its boundary.
            for section in sections {
                section.firstChild(named: "p14:sldIdLst")?.children.removeAll {
                    if case .element(let e) = $0 { return newIDs.contains(e[attribute: "id"] ?? "") }
                    return false
                }
            }
            var entries = sectionList.children
            let endID = idsBefore[index + oldCount - 1]
            if let end = entries.firstIndex(where: { node in
                if case .element(let element) = node { return element[attribute: "id"] == endID }
                return false
            }) {
                entries.insert(contentsOf: newIDs.map { .element(XML.Element("p14:sldId", attributes: [("id", $0)])) }, at: end + 1)
                sectionList.children = entries
                main.markDirty()
            }
        }
    }
}
