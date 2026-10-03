import SwiftUI
import LecternCore

/// Preview a local recomposition before saving a new document. No model request.
struct RecoveryView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let snapshotURL: URL
    let sourceURL: URL?
    @State private var slides: [IRSlide] = []
    @State private var selected = ""
    @State private var variant = 1
    @State private var candidate: DeckResult?
    @State private var problem: String?
    @State private var busy = false
    @State private var task: Task<Void, Never>?
    @State private var scratch: URL?
    @State private var rebuildDeck = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(sourceURL == nil ? "Recover saved content" : "Recompose a slide").font(.title2.bold())
            Text("Uses your saved text, images and design. No generation cost. Your original deck stays intact.")
                .foregroundStyle(.secondary)
            if sourceURL != nil {
                Toggle("Rebuild the entire deck from saved content", isOn: $rebuildDeck)
                    .disabled(busy)
                    .onChange(of: rebuildDeck) { candidate = nil; problem = nil }
                Text(rebuildDeck
                     ? "Creates a new deck and allows the page count to change. Edits and review comments added after generation are kept only in your original file."
                     : "Changes the selected slide and its continuation pages. Other slides, notes and review comments are preserved.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Picker("Slide", selection: $selected) {
                ForEach(slides) { Text($0.title ?? $0.id).tag($0.id) }
            }.disabled(busy).onChange(of: selected) { candidate = nil }
            Picker("Layout", selection: $variant) {
                Text("Best fit").tag(0)
                Text("Alternative 1").tag(1)
                Text("Alternative 2").tag(2)
            }.disabled(busy).onChange(of: variant) { candidate = nil }
            Text("Some templates have only one compatible layout. Preview is approximate; check the saved deck in PowerPoint.")
                .font(.caption).foregroundStyle(.secondary)
            if busy { ProgressView("Composing saved content…") }
            if let candidate {
                Text("\(candidate.slideCount) slides in the revised copy").font(.headline)
                if !candidate.previewWarnings.isEmpty {
                    DisclosureGroup("Preview limitations (\(candidate.previewWarnings.count))") {
                        ForEach(candidate.previewWarnings, id: \.self) { Text($0).font(.caption) }
                    }
                }
                if !candidate.warnings.isEmpty {
                    DisclosureGroup("Layout adjustments (\(candidate.warnings.count))") {
                        ForEach(Array(candidate.warnings.enumerated()), id: \.offset) { _, warning in
                            Text(warning).font(.caption)
                        }
                    }
                }
                SlideContactSheet(previews: candidate.previews, titles: candidate.previewTitles)
                    .frame(minHeight: 280)
            }
            if let problem { Text(problem).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Button("Cancel") { task?.cancel(); dismiss() }
                Spacer()
                Button("Preview Layout") { preview() }.disabled(busy || selected.isEmpty)
                Button("Save Revised Copy") { save() }.disabled(busy || candidate == nil)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24).frame(minWidth: 580, minHeight: 380)
        .task {
            do {
                let saved = try await Task.detached { try RenderSnapshot.load(snapshotURL) }.value
                slides = saved.deck.slides; selected = slides.first?.id ?? ""
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700])
                scratch = dir
            } catch { problem = String(describing: error) }
        }
        .onDisappear {
            task?.cancel()
            // Cleanup is performed after the renderer exits, not while it writes.
            let running = task, directory = scratch
            Task { await running?.value; if let directory { try? FileManager.default.removeItem(at: directory) } }
        }
    }

    private func preview() {
        guard let scratch else { return }
        candidate = nil; problem = nil; busy = true
        let id = selected, choice = variant, source = rebuildDeck ? nil : sourceURL
        task = Task {
            defer { busy = false }
            do {
                let result = try await DeckRenderer().retrySlide(snapshotURL: snapshotURL, sourceURL: source,
                    slideID: id, variant: choice, into: scratch)
                try Task.checkCancellation()
                candidate = result
            } catch is CancellationError { }
            catch { problem = String(describing: error) }
        }
    }

    private func save() {
        guard let candidate else { return }
        busy = true
        task = Task {
          defer { busy = false }
          do {
            let directory = AppState.decksDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let stem = candidate.url.deletingPathExtension().lastPathComponent
            let destination = directory.appendingPathComponent(stem + "-" + UUID().uuidString.prefix(8) + ".pptx")
            try await Task.detached { try FileManager.default.copyItem(at: candidate.url, to: destination) }.value
            if Task.isCancelled {
                try? FileManager.default.removeItem(at: destination)
                return
            }
            let saved = DeckResult.savedCopy(of: candidate, at: destination)
            app.acceptRecoveredDeck(saved); dismiss()
          } catch { problem = String(describing: error) }
        }
    }
}
