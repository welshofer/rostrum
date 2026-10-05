import SwiftUI
import LecternCore
#if os(macOS)
import AppKit
#endif

struct LibraryLabView: View {
    @Environment(AppState.self) private var app
    @Bindable var model: LibraryLabModel
    @State private var showingFiles = false

    private var recipe: LibraryLabRecipe {
        LibraryLab.catalog.first { $0.id == model.selection }!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Library Lab").font(.largeTitle.bold())
                    Text("Run Rostrum’s features, inspect the results, and open the actual PowerPoint files. All demos work offline. Completed decks are saved to your library.")
                        .foregroundStyle(.secondary)
                }
                Picker("Demonstration", selection: $model.selection) {
                    ForEach(LibraryLab.catalog) { recipe in
                        Text(catalogTitle(recipe)).tag(recipe.id)
                    }
                }
                .accessibilityIdentifier("libraryLab.recipe")
                VStack(alignment: .leading, spacing: 12) {
                    Text(recipe.title).font(.title2.bold())
                    Text(recipe.summary)
                    inputs
                    ViewThatFits(in: .horizontal) {
                        HStack { actions }
                        VStack(alignment: .leading) { actions }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 14))

                if model.isRunning {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: Double(model.completed), total: Double(max(model.total, 1)))
                        Text("\(model.completed) of \(model.total) complete · \(activeTitle)")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Cancel", role: .cancel) { model.cancel() }
                    }
                    .accessibilityIdentifier("libraryLab.progress")
                }
                if !savedRecipes.isEmpty || !unsavedRecipes.isEmpty { savedResults }
                if let failure = model.failures[recipe.id] {
                    Label("Couldn’t finish this demo", systemImage: "exclamationmark.triangle")
                        .font(.headline).foregroundStyle(.orange)
                    Text(failure).textSelection(.enabled)
                }
                if let result = model.results[recipe.id] { resultView(result) }
                if !recipe.limitations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Support boundaries").font(.headline)
                        ForEach(recipe.limitations, id: \.self) { Text($0).font(.callout) }
                    }
                    .foregroundStyle(.secondary)
                }
                DisclosureGroup("Operations exercised (\(recipe.operations.count))") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(recipe.operations, id: \.self) { Text($0).font(.callout).textSelection(.enabled) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }
                if model.total > 1, !model.isRunning {
                    Label("\(model.results.count) completed · \(model.failures.count) could not finish · \(unsavedRecipes.count) could not save",
                          systemImage: model.failures.isEmpty && unsavedRecipes.isEmpty ? "checkmark.circle" : "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("Choose any demonstration above to inspect its result. A checkmark means file checks passed; preview findings are reported separately.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Library Lab")
        .sheet(isPresented: $showingFiles) {
            if let result = model.results[recipe.id] {
                NavigationStack {
                    List(result.artifacts, id: \.self) { url in
                        #if os(macOS)
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } label: {
                            HStack {
                                Label(artifactName(url, in: result.directory), systemImage: "doc")
                                Spacer()
                                Text("Reveal in Finder").foregroundStyle(.secondary)
                            }
                            .font(.callout)
                        }
                        .buttonStyle(.plain)
                        #else
                        ShareLink(item: url) {
                            Label(artifactName(url, in: result.directory), systemImage: "doc")
                                .font(.callout)
                        }
                        #endif
                    }
                    .navigationTitle("Demo Files")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingFiles = false } } }
                }
                .frame(minWidth: 360, minHeight: 400)
            }
        }
    }

    @ViewBuilder private var inputs: some View {
        if recipe.inputs.contains(.text) {
            TextField("Sample text", text: $model.options.text, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(1...3)
        }
        if recipe.inputs.contains(.accent) {
            HStack {
                Text("Accent color")
                TextField("Six hex digits", text: $model.options.accentHex)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 140)
                    .accessibilityLabel("Accent color, six hexadecimal digits")
            }
        }
        if recipe.inputs.contains(.sampleSize) {
            Stepper("Sample size: \(model.options.sampleSize)", value: $model.options.sampleSize, in: 2...12)
        }
        if recipe.inputs.contains(.alternative), let label = recipe.alternativeLabel {
            Toggle(label, isOn: $model.options.alternative)
        }
    }

    @ViewBuilder private var actions: some View {
        Button("Run Demo", systemImage: "play.fill") { app.runLibraryDemos([recipe.id], model: model) }
            .buttonStyle(.borderedProminent).disabled(model.isRunning)
            .accessibilityIdentifier("libraryLab.run")
        Button("Run All \(LibraryLab.catalog.count) Demos") { app.runLibraryDemos(LibraryLab.catalog.map(\.id), model: model) }
            .disabled(model.isRunning).accessibilityIdentifier("libraryLab.runAll")
    }

    private var activeTitle: String {
        LibraryLab.catalog.first { $0.id == model.activeID }?.title ?? "Finishing"
    }

    private var savedRecipes: [LibraryLabRecipe] {
        LibraryLab.catalog.filter { model.savedDecks[$0.id] != nil }
    }

    private var unsavedRecipes: [LibraryLabRecipe] {
        LibraryLab.catalog.filter { model.results[$0.id] != nil && model.saveFailures[$0.id] != nil }
    }

    private var savedResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            let slides = savedRecipes.reduce(0) { $0 + (model.results[$1.id]?.slideCount ?? 0) }
            Label("\(savedRecipes.count) PowerPoint files saved · \(slides) slides", systemImage: "folder.fill")
                .font(.headline)
                .accessibilityIdentifier("libraryLab.savedSummary")
            Text("Each demo has its own PowerPoint file. Earlier runs are kept too.")
                .font(.callout).foregroundStyle(.secondary)
            #if os(macOS)
            Button("Reveal All in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting(savedRecipes.compactMap { model.savedDecks[$0.id] })
            }
            .disabled(savedRecipes.isEmpty)
            .accessibilityIdentifier("libraryLab.revealAll")
            #endif
            ForEach(unsavedRecipes) { recipe in
                if let result = model.results[recipe.id] {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Couldn’t save “\(recipe.title)”", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text(model.saveFailures[recipe.id] ?? "")
                                .font(.caption).textSelection(.enabled)
                        }
                        Spacer()
                        retrySaveButton(result)
                    }
                }
            }
            DisclosureGroup("Saved decks") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(savedRecipes) { recipe in
                        if let url = model.savedDecks[recipe.id] {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recipe.title).font(.callout.bold())
                                    Text("\(model.results[recipe.id]?.slideCount ?? 0) slides · " + url.lastPathComponent)
                                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                }
                                Spacer()
                                Button("Inspect") { app.inspect(deckAt: url) }
                                #if os(macOS)
                                Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                    .help("Reveal in Finder")
                                #endif
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
    }

    private func catalogTitle(_ recipe: LibraryLabRecipe) -> String {
        if model.failures[recipe.id] != nil || model.saveFailures[recipe.id] != nil { return "! " + recipe.title }
        if let result = model.results[recipe.id] { return (result.passed ? "✓ " : "! ") + recipe.title }
        return recipe.title
    }

    @ViewBuilder private func resultView(_ result: LibraryLabResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(result.passed ? "All \(result.checks.count) file checks passed" : "Some file checks failed",
                  systemImage: result.passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.headline).foregroundStyle(result.passed ? .green : .orange)
                .accessibilityIdentifier("libraryLab.result")
            Text("\(result.slideCount) slides · \(result.elapsedSeconds, format: .number.precision(.fractionLength(2))) seconds to create, save, reopen, render and extract")
                .font(.caption).foregroundStyle(.secondary)
            if result.options != LibraryLab.effectiveOptions(model.options, for: recipe.id) {
                Text("These results use the previous input settings. Run the demo again to apply your changes.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if let svg = result.coverSVG {
                SlidePreview(svg: svg)
                    .aspectRatio(SlidePreviewGeometry(svg: svg)?.aspectRatio ?? 16.0 / 9.0, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 8))
                    .accessibilityLabel("Slide \(result.coverSlideNumber ?? 1) of \(recipe.title)")
            }
            if let saved = model.savedDecks[result.id] {
                Label("Saved: " + saved.path, systemImage: "checkmark.circle")
                    .font(.callout).textSelection(.enabled)
                    .accessibilityIdentifier("libraryLab.savedDeck")
            } else if let failure = model.saveFailures[result.id] {
                Label("Couldn’t save this deck to your library", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(failure + " Use Retry Save below. You can still inspect this result.")
                    .font(.callout).textSelection(.enabled)
                    .accessibilityIdentifier("libraryLab.saveFailure")
            }
            ViewThatFits(in: .horizontal) {
                HStack { artifactActions(result) }
                VStack(alignment: .leading) { artifactActions(result) }
            }
            if !result.findings.isEmpty {
                DisclosureGroup("Preview and export findings (\(result.findings.count))") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("These findings describe preview limitations, render failures or export problems. File checks do not establish PowerPoint visual parity.")
                        ForEach(Array(result.findings.enumerated()), id: \.offset) { _, finding in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(finding.stage + (finding.slideNumber.map { " · Slide \($0)" } ?? ""))
                                    .fontWeight(.semibold)
                                Text(finding.message)
                            }
                        }
                    }
                    .font(.callout).textSelection(.enabled).padding(.top, 8)
                }
            }
            DisclosureGroup("Saved-file checks") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(result.checks.enumerated()), id: \.offset) { _, check in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(check.name, systemImage: check.passed ? "checkmark.circle" : "xmark.circle")
                                .fontWeight(.semibold).foregroundStyle(check.passed ? Color.primary : Color.orange)
                            Text(check.detail).foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.callout).textSelection(.enabled).padding(.top, 8)
            }
        }
    }

    @ViewBuilder private func artifactActions(_ result: LibraryLabResult) -> some View {
        Button("Inspect Result") { app.inspect(deckAt: model.savedDecks[result.id] ?? result.afterURL) }
            .accessibilityIdentifier("libraryLab.inspectAfter")
        if let before = result.beforeURL {
            Button("Inspect Before") { app.inspect(deckAt: before) }
                .accessibilityIdentifier("libraryLab.inspectBefore")
        }
        if model.saveFailures[result.id] != nil {
            retrySaveButton(result)
        }
        #if os(macOS)
        if let saved = model.savedDecks[result.id] {
            Button("Reveal in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([saved])
            }
            .accessibilityIdentifier("libraryLab.revealDeck")
        }
        Button("Reveal Report") { NSWorkspace.shared.activateFileViewerSelecting([result.reportURL]) }
        #else
        ShareLink("Share Deck", item: model.savedDecks[result.id] ?? result.afterURL)
        ShareLink("Share Report", item: result.reportURL)
        #endif
        Button("All Files") { showingFiles = true }
        #if !os(macOS)
        ShareLink("Extracted Text", item: result.markdownURL)
        #endif
    }

    private func retrySaveButton(_ result: LibraryLabResult) -> some View {
        Button(model.savingIDs.contains(result.id) ? "Saving…" : "Retry Save") {
            app.retrySavingLibraryDemo(result, model: model)
        }
        .disabled(model.savingIDs.contains(result.id))
        .accessibilityIdentifier("libraryLab.retrySave")
    }

    private func artifactName(_ url: URL, in directory: URL) -> String {
        let root = directory.resolvingSymlinksInPath().path + "/"
        let path = url.resolvingSymlinksInPath().path
        return path.hasPrefix(root) ? String(path.dropFirst(root.count)) : url.lastPathComponent
    }
}
