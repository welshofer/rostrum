import Foundation
import KeynoteInterchange

extension KeyxBackend {
    static func retrySlide(saved: RenderSnapshot, snapshotURL: URL, sourceURL: URL?, slideID: String,
                           variant: Int, into directory: URL) throws -> DeckResult {
        guard let index = saved.deck.slides.firstIndex(where: { $0.id == slideID }) else {
            throw RenderError.renderFailed(underlying: "This slide is not in the saved content.")
        }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: temporary) }
        let designURL = try saved.design.map { design -> URL in
            let url = temporary.appendingPathComponent("design.md")
            try Data(design.utf8).write(to: url); return url
        }
        let template = try saved.interchangeTemplate()
        var options = try options(designURL: template == nil ? designURL : nil, notesEnabled: saved.notesEnabled)
        if let template, variant > 0 {
            let layouts = try template.interchangeDocument().presentation["theme"]?["slide_layouts"]?.array ?? []
            if layouts.indices.contains(variant) {
                options.templateLayout = layouts[variant]["identifier"]?.string ?? layouts[variant]["name"]?.string
            }
        }
        let authored = try KeyxAuthor.render(saved.deck, options: options, images: saved.images,
                                             template: template?.interchangeDocument(), measure: measurer)
        var warnings = authored.warnings
        if variant > 0, template == nil {
            warnings.append("The interchange authoring backend has one measured default layout; the requested alternate uses that layout.")
        }
        var output = authored.document
        if let sourceURL {
            guard DeckFormat(url: sourceURL) == .keynoteInterchange else {
                throw RenderError.renderFailed(underlying: "The saved content targets Keynote Interchange, but the source is a different format.")
            }
            output = try KeyxDocument(contentsOf: sourceURL)
            var current = try output.slides
            let positions = current.indices.filter { current[$0].node["lectern_source_id"]?.string == slideID }
            guard !positions.isEmpty, positions == Array(positions[0]..<(positions[0] + positions.count)),
                  positions.enumerated().allSatisfy({ page, position in
                      current[position].identifier == "lectern-slide-\(index + 1)-\(page + 1)"
                  }) else {
                throw RenderError.renderFailed(underlying: "Keynote may have regenerated slide identifiers, or this slide group changed externally. Rebuild the entire deck from saved content instead; no slide was matched by position.")
            }
            let replacements = try authored.document.slides.filter { $0.node["lectern_source_id"]?.string == slideID }
            guard replacements.count >= positions.count else {
                throw RenderError.renderFailed(underlying: "This layout needs fewer pages. Use a whole-deck rebuild so existing continuation pages and edits are not silently removed.")
            }
            // A conflicting resource could be shared by untouched slides.
            // Refuse rather than overwrite those slides' bytes during recovery.
            var resources: Set<String> = []
            func referencedResources(_ value: KeyxValue) {
                if let indirect = value["indirect"],
                   let name = indirect["identifier"]?.string ?? indirect["filename"]?.string {
                    resources.insert("Data/" + name)
                }
                for child in value.object?.values ?? [:].values { referencedResources(child) }
                for child in value.array ?? [] { referencedResources(child) }
            }
            for slide in replacements { referencedResources(slide.node.value) }
            for name in resources.sorted() {
                guard let data = authored.document.entryData(named: name) else {
                    throw RenderError.renderFailed(underlying: "A recomposed slide references a missing resource: \(name).")
                }
                if let original = output.entryData(named: name), original != data {
                    throw RenderError.renderFailed(underlying: "A source resource changed externally. Rebuild from saved content to avoid changing resources used by untouched slides.")
                }
                try output.setEntry(named: name, data: data)
            }
            for (page, position) in positions.enumerated() {
                current[position].node["contents"] = replacements[page].node["contents"]
                current[position].node["layout"] = replacements[page].node["layout"]
                // Keep current notes, identity, depth and extension metadata.
            }
            if replacements.count > positions.count {
                current.insert(contentsOf: replacements.dropFirst(positions.count), at: positions[positions.count - 1] + 1)
            }
            output.replaceSlides(current)
            warnings.append("Recomposed the matched interchange slide group in a new copy; other slides and existing notes were retained.")
        } else {
            warnings.append("Rebuilt from the saved snapshot. Later external edits remain only in the original document.")
        }
        try Task.checkCancellation()
        let url = try outputURL(title: saved.deck.meta.title + " revised", in: directory)
        try output.save(to: url)
        return try result(at: url, recoveryURL: snapshotURL, warnings: warnings)
    }
}
