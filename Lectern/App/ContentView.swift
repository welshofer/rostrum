import SwiftUI
#if os(macOS)
import AppKit
#else
import QuickLook
#endif
import UniformTypeIdentifiers
import LecternCore

struct ContentView: View {
    @Environment(AppState.self) private var app
    @State private var section: LibrarySection = .recent
    @State private var query = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #if os(iOS)
    @State private var showSettings = false
    #endif

    /// The decks this app will open. A `.pptx` and nothing else — the
    /// inspector reads PresentationML, and offering the user a file it cannot
    /// open is a worse experience than not offering it.
    static let deckTypes: [UTType] = ["pptx", "potx", "ppsx"].compactMap {
        UTType(filenameExtension: $0)
    }

    var body: some View {
        @Bindable var app = app
        // One shell on every platform: a sidebar beside the work on a Mac and
        // an iPad, the same views pushed on a phone. NavigationSplitView is
        // what makes that one description rather than three.
        NavigationSplitView(columnVisibility: $columnVisibility) {
            LibrarySidebar(section: $section) { openSettings() }
                .navigationSplitViewColumnWidth(min: 240, ideal: 270, max: 320)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        // Attached above the phase switch, not inside a phase: the menu bar
        // starts this flow too, and a picker owned by a view that isn't on
        // screen never opens.
        .fileImporter(isPresented: $app.isChoosingDeckToInspect,
                      allowedContentTypes: Self.deckTypes) { result in
            if let url = try? result.get() { app.inspect(deckAt: url) }
        }
        #if os(iOS)
        .sheet(isPresented: $showSettings) { SettingsView().environment(app) }
        #endif
        .sheet(isPresented: $app.isShowingLibrary) { DeckLibrarySheet().environment(app) }
        .task { await app.start(); await app.loadStyles() }
    }

    /// The detail column. `home` is the library; every other phase is the work
    /// that replaced it, which is why they share the column rather than the
    /// library being one more destination.
    @ViewBuilder private var detail: some View {
        Group {
            switch app.phase {
            case .home:
                DeckGridView(section: section, query: $query)
                    .searchable(text: $query, placement: .toolbar, prompt: "Search")
            case .compose: ComposeView().transition(.blurReplace)
            case .generating: GeneratingView().transition(.blurReplace)
            case .result(let r): ResultView(result: r).transition(.blurReplace)
            case .failed(let m): FailedView(message: m).transition(.blurReplace)
            case .inspecting: InspectingView().transition(.blurReplace)
            case .inspected: InspectorView().transition(.blurReplace)
            }
        }
        .frame(minWidth: 520, minHeight: 480)
        .animation(.smooth(duration: 0.35), value: app.phase)
        .sensoryFeedback(.success, trigger: app.phase) { _, newPhase in
            if case .result = newPhase { return true }
            if case .inspected = newPhase { return true }
            return false
        }
        .toolbar { toolbar }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        // Anything that is not the library is a task you finish and come back
        // from, so it gets a way back rather than a dead end.
        if app.phase != .home {
            ToolbarItem(placement: .navigation) {
                Button {
                    app.goHome()
                } label: {
                    Label("Library", systemImage: "chevron.backward")
                }
                .help("Back to your decks")
            }
        }
    }

    private func openSettings() {
        #if os(macOS)
        // The Settings scene is the native home for this on a Mac.
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        #else
        showSettings = true
        #endif
    }
}

// MARK: - Home

/// The fork. Lectern does two things, and this is where you say which.
///
/// Two buttons and nothing else on purpose: the compose form used to be the
/// launch screen, which quietly asserted that writing a deck was the only
/// thing here and left opening one with no door at all.
struct HomeView: View {
    @Environment(AppState.self) private var app
    @State private var dropTargeted = false
    /// Fixed point sizes ignore the user's text setting; @ScaledMetric is the
    /// API that actually tracks it.
    @ScaledMetric(relativeTo: .largeTitle) private var heroGlyph: CGFloat = 44

    var body: some View {
        @Bindable var app = app
        VStack(spacing: 30) {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: heroGlyph)).foregroundStyle(.tint)
                Text("Lectern").font(.largeTitle.weight(.semibold))
                Text("Write a deck, or take one apart.")
                    .font(.title3).foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                Button { app.startCreate() } label: {
                    HomeChoiceLabel(title: "Create", systemImage: "sparkles",
                                    blurb: "Describe it, and Lectern writes the .pptx.")
                }
                .buttonStyle(.glassProminent)

                Button { app.chooseDeckToInspect() } label: {
                    HomeChoiceLabel(title: "Inspect", systemImage: "magnifyingglass",
                                    blurb: "Open a deck, see what it's made of, export it.")
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)

            // Only once there is something to show — an empty library behind a
            // button is a dead end offered to someone who has never generated
            // anything.
            if !app.library.isEmpty {
                Button { app.isShowingLibrary = true } label: {
                    Label("\(app.library.count) deck\(app.library.count == 1 ? "" : "s") you've made",
                          systemImage: "rectangle.stack")
                }
                .buttonStyle(.glass)
            }
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Half the product is "open a deck", and the most natural gesture for
        // it did nothing. Accepts the same types as the file importer.
        .dropDestination(for: URL.self) { urls, _ in
            guard let deck = urls.first(where: {
                ["pptx", "potx", "ppsx"].contains($0.pathExtension.lowercased())
            }) else { return false }
            app.inspect(deckAt: deck)
            return true
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.tint, style: StrokeStyle(lineWidth: 2, dash: [7]))
                    .padding(18)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: dropTargeted)
        .sheet(isPresented: $app.isShowingLibrary) { DeckLibrarySheet().environment(app) }
        .task { app.refreshLibrary() }
    }
}

private struct HomeChoiceLabel: View {
    @ScaledMetric(relativeTo: .title) private var glyph: CGFloat = 28
    let title: String
    let systemImage: String
    let blurb: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage).font(.system(size: glyph))
            Text(title).font(.title3.weight(.semibold))
            Text(blurb).font(.caption)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 170)
                .opacity(0.75)
        }
        .padding(.vertical, 20).padding(.horizontal, 16)
        .frame(minWidth: 190)
    }
}

// MARK: - Inspecting

/// Opening a deck, walking every shape and drawing every slide is real work.
/// This is the window saying so, with the one step that has a denominator
/// driving a real bar.
struct InspectingView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text(app.inspectStage.isEmpty ? "Opening the deck" : app.inspectStage)
                .font(.title3.weight(.semibold)).contentTransition(.opacity)
            if app.inspectTotal > 0 {
                ProgressView(value: Double(app.inspectDone), total: Double(app.inspectTotal))
                    .frame(maxWidth: 280)
                Text("\(app.inspectDone) of \(app.inspectTotal) slides")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Button("Cancel", role: .cancel) { app.cancelInspection() }.buttonStyle(.glass)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - A reusable glass card

struct Card<Content: View>: View {
    var title: String?
    var systemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Label(title, systemImage: systemImage ?? "circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Compose

struct ComposeView: View {
    @Environment(AppState.self) private var app
    @State private var showStyles = false
    @State private var importing = false
    @State private var dropTargeted = false
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    /// The Arcus audience personas, after the neutral default. The generator
    /// receives the selected label verbatim.
    private static let audiences = [
        "General", "Executives", "Investors", "Government", "Customers",
        "Colleagues", "Students & Educators", "Conference / Public",
    ]

    /// iPhone-width layouts stack the Audience/Goal cards; everything wider
    /// keeps them side by side.
    private var isCompact: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }

    var body: some View {
        @Bindable var app = app
        ScrollView {
            VStack(spacing: 16) {
                if let notice = app.migrationNotice {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(notice).font(.callout)
                        Spacer()
                        Button { app.dismissMigrationNotice() } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Dismiss")
                    }
                    .padding(12)
                    .background(.regularMaterial, in: .rect(cornerRadius: 12, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
                Card(title: "PROMPT", systemImage: "text.alignleft") {
                    TextEditor(text: $app.prompt)
                        .font(.body).scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if app.prompt.isEmpty {
                                Text("What is this presentation about, and what should it accomplish?")
                                    .foregroundStyle(.tertiary).allowsHitTesting(false).padding(.top, 2)
                            }
                        }
                        // The Card heading and the placeholder are both
                        // decoration as far as VoiceOver is concerned — one is
                        // a sibling, the other is not hit-testable — so the
                        // field has to carry its own name and hint.
                        .accessibilityLabel("Prompt")
                        .accessibilityHint("What the presentation is about, and what it should accomplish")
                }

                let audienceGoalLayout = isCompact
                    ? AnyLayout(VStackLayout(spacing: 16))
                    : AnyLayout(HStackLayout(spacing: 16))
                audienceGoalLayout {
                    Card(title: "AUDIENCE", systemImage: "person.2") {
                        // `.labelsHidden()` hides a label from the eye; a label
                        // of "" was never there for VoiceOver to hide. Name the
                        // picker properly, then hide the visible copy.
                        Picker("Audience", selection: $app.audience) {
                            ForEach(Self.audiences, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu).labelsHidden()
                        .accessibilityLabel("Audience")
                    }
                    Card(title: "GOAL", systemImage: "target") {
                        Picker("Goal", selection: $app.goal) {
                            ForEach(["inform", "persuade", "entertain", "inspire"], id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden()
                        .accessibilityLabel("Goal")
                    }
                }

                Card(title: "LENGTH", systemImage: "rectangle.stack") {
                    // At iPhone widths the single row squeezes both labels into
                    // four-line wraps; stack the stepper and toggle instead.
                    (isCompact ? AnyLayout(VStackLayout(spacing: 14))
                               : AnyLayout(HStackLayout(spacing: 16))) {
                        Stepper("\(app.slideCount) slides  ·  ≈ \(Int(Double(app.slideCount) * 1.5)) min",
                                value: $app.slideCount, in: 3...40)
                        if !isCompact { Spacer() }
                        Toggle("Speaker notes", isOn: $app.includeNotes).toggleStyle(.switch)
                    }
                }

                Card(title: "STYLE", systemImage: "paintpalette") {
                    StyleButton(style: app.selectedStyle) { showStyles = true }
                }

                groundingCard
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) { generateBar }
        .sheet(isPresented: $showStyles) { StylePickerSheet().environment(app) }
        .sheet(isPresented: $app.isShowingLibrary) { DeckLibrarySheet().environment(app) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in
            if let url = try? result.get() { Task { await app.attachPDF(url) } }
        }
        .task { app.refreshLibrary() }
    }

    @ViewBuilder private var groundingCard: some View {
        Card(title: "GROUND ON A PDF (OPTIONAL)", systemImage: "doc.text.magnifyingglass") {
            if app.groundingLoading {
                HStack(spacing: 10) { ProgressView().controlSize(.small); Text("Reading PDF…").foregroundStyle(.secondary) }
            } else if let g = app.grounding {
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill").font(.title2).foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.name).font(.headline).lineLimit(1)
                        Text("\(g.pageCount) pages · grounding on\(g.truncated ? " (truncated)" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { app.clearPDF() } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .accessibilityLabel("Remove PDF")
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.down.doc").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Drop a PDF here to ground the deck on real facts")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Choose PDF…") { importing = true }.buttonStyle(.glass)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 22)
                .background(dropTargeted ? AnyShapeStyle(Color.accentColor.opacity(0.12)) : AnyShapeStyle(.clear),
                            in: .rect(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .foregroundStyle(dropTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
                )
                if let err = app.groundingError {
                    Label(err, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else { return false }
            Task { await app.attachPDF(url) }
            return true
        } isTargeted: { dropTargeted = $0 }
    }

    private var generateBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                if !app.hasKey {
                    Label("Add an API key in \(AppState.settingsHint) to generate", systemImage: "key")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("\(app.slideCount) slides · \(app.providerID.label)"
                         + (app.costEstimate.map { " · ~\($0) est." } ?? ""))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer()
            // Only once there is something to show. An empty library behind a
            // button is a dead end offered to someone who has never generated
            // anything.
            if !app.library.isEmpty {
                Button { app.isShowingLibrary = true } label: {
                    Label("\(app.library.count) deck\(app.library.count == 1 ? "" : "s")",
                          systemImage: "rectangle.stack")
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .help("Decks you've already generated")
            }
            Button { app.generate() } label: {
                Label("Generate", systemImage: "sparkles").font(.body.weight(.semibold)).padding(.horizontal, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!app.canGenerate)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.bar)
    }
}

// MARK: - Generating

struct GeneratingView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        VStack(spacing: 20) {
            // The deck assembling itself, rather than a spinner over an empty
            // pane. This is the longest wait in the app and the one the user
            // has paid for, so it gets a shape.
            if app.total > 0 {
                DraftingSheet(total: app.total, done: app.drafted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
                ProgressView().controlSize(.large)
                Spacer()
            }

            VStack(spacing: 10) {
                Text(app.stage).font(.title3.weight(.semibold)).contentTransition(.opacity)
                if app.total > 0 {
                    ProgressView(value: Double(app.drafted), total: Double(app.total))
                        .frame(maxWidth: 280)
                    Text("\(app.drafted) of \(app.total) \(app.progressNoun)")
                        .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Button("Cancel", role: .cancel) { app.cancel() }.buttonStyle(.glass)
            }
            .padding(.bottom, 28)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(app.total > 0
                                ? "\(app.stage). \(app.drafted) of \(app.total) \(app.progressNoun)."
                                : app.stage)
        }
        .animation(.smooth(duration: 0.3), value: app.drafted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Placeholder tiles that light up as slides land — the contact sheet the
/// result screen will show, drawn one slide ahead of the deck existing.
private struct DraftingSheet: View {
    let total: Int
    let done: Int
    @State private var pulse = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<total, id: \.self) { index in
                    DraftingTile(state: state(of: index), dimmed: index == done && pulse)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
        }
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func state(of index: Int) -> DraftingTile.State {
        index < done ? .written : .pending
    }
}

/// One placeholder slide. Its own view because a fill, a border, a badge and a
/// conditional opacity in one chain is more than the type checker will take.
private struct DraftingTile: View {
    enum State { case pending, written }

    let state: State
    let dimmed: Bool

    var body: some View {
        let written = state == .written
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(written ? AnyShapeStyle(.tint.opacity(0.22)) : AnyShapeStyle(.quaternary))
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay { border(written) }
            .overlay(alignment: .bottomTrailing) { badge(written) }
            .opacity(dimmed ? 0.55 : 1)
    }

    @ViewBuilder private func border(_ written: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(written ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 1)
    }

    @ViewBuilder private func badge(_ written: Bool) -> some View {
        if written {
            Image(systemName: "checkmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tint)
                .padding(6)
        }
    }
}

// MARK: - Result

struct ResultView: View {
    @Environment(AppState.self) private var app
    let result: DeckResult
    #if os(iOS)
    @State private var previewURL: URL?
    #endif
    var body: some View {
        VStack(spacing: 0) {
            // Title band, then the sheet takes the room, then the actions sit
            // where the hand already is.
            VStack(spacing: 6) {
                Text(result.url.lastPathComponent).font(.title3.weight(.semibold))
                    .lineLimit(1).truncationMode(.middle)
                Text("\(result.slideCount) slides · written by Rostrum")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 24).padding(.horizontal, 24).padding(.bottom, 12)

            if result.previews.isEmpty {
                // A green glyph floating in whitespace reads as a placeholder,
                // not a finish. Say what was made and why there is no picture.
                ContentUnavailableView {
                    Label("Deck written", systemImage: "checkmark.seal.fill")
                } description: {
                    Text("\(result.slideCount) slides are on disk. No previews were rendered for this deck.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Rendered by Rostrum from the deck on disk, so what you see
                // here is what PowerPoint will open — not a redraw of the plan.
                SlideContactSheet(previews: result.previews, titles: result.previewTitles)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
            }
            VStack(spacing: 14) {
            #if os(iOS)
            // No Finder to reveal in: Quick Look renders the deck in place, and
            // the share sheet exports it (Save to Files, AirDrop, Keynote…).
            // The deck also lives in Documents/Decks, visible in the Files app.
            HStack(spacing: 12) {
                Button { previewURL = result.url } label: { Label("Preview", systemImage: "eye") }
                    .buttonStyle(.glassProminent)
                ShareLink(item: result.url) { Label("Share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.glass)
                Button("New") { app.reset() }.buttonStyle(.glass)
            }
            .controlSize(.large)
            .quickLookPreview($previewURL)
            #else
            HStack(spacing: 12) {
                Button { NSWorkspace.shared.open(result.url) } label: { Label("Open", systemImage: "arrow.up.forward.app") }
                    .buttonStyle(.glassProminent)
                Button { NSWorkspace.shared.activateFileViewerSelecting([result.url]) } label: { Label("Reveal", systemImage: "folder") }
                    .buttonStyle(.glass)
                Button("New") { app.reset() }.buttonStyle(.glass)
            }
            .controlSize(.large)
            #endif
            if !result.warnings.isEmpty {
                DisclosureGroup("\(result.warnings.count) validation warning(s)") {
                    ForEach(result.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: 420)
            }
            if !result.droppedContent.isEmpty {
                // The model asked for more than the layout holds. Not a
                // validation warning and not our bug — a collision between the
                // plan and the slide, which the user is the one who can resolve.
                DisclosureGroup("\(result.droppedContent.count) slide(s) lost content to layout limits") {
                    ForEach(result.droppedContent, id: \.self) {
                        Text($0).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 420)
            }
            if !result.schemaIssues.isEmpty {
                // Rostrum's own lint on the file we just wrote. If this ever
                // has entries, the bug is Lectern's or Rostrum's — not the
                // model's — so it reads differently from the warnings above.
                DisclosureGroup("\(result.schemaIssues.count) schema issue(s) in the written deck") {
                    ForEach(result.schemaIssues, id: \.self) {
                        Text($0).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 420)
            }
            if !result.unmeasuredFonts.isEmpty {
                // Not a warning: the deck is fine, its text was just sized by
                // estimate because these faces aren't installed on this Mac.
                DisclosureGroup("\(result.unmeasuredFonts.count) font(s) not installed") {
                    Text("Text in \(result.unmeasuredFonts.joined(separator: ", ")) was fitted "
                        + "by estimate. Install the font and re-render to size it from real "
                        + "glyph metrics.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: 420)
            }
            }
            .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Failed

struct FailedView: View {
    @Environment(AppState.self) private var app
    @ScaledMetric(relativeTo: .largeTitle) private var failGlyph: CGFloat = 44
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: failGlyph)).foregroundStyle(.orange)
            Text(message).font(.title3).multilineTextAlignment(.center).frame(maxWidth: 420)
            // Every failure used to funnel into one button back to the form,
            // even though `describe` knew exactly which one had happened. The
            // most common — a rate limit — cost the user their place for no
            // reason.
            HStack(spacing: 12) {
                recovery
                // "Start over" rather than "back to compose": a failure now
                // arrives from opening a deck as well as from writing one, and
                // the compose form is the wrong place to land after the first.
                // Nothing typed is lost — Home keeps the form's contents.
                Button("Start Over") { app.goHome() }
                    .buttonStyle(.glass).controlSize(.large)
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var recovery: some View {
        switch app.lastFailure {
        case .rateLimited, .networkOffline, .providerError:
            // Nothing about the request was wrong, so the same request is the
            // right thing to send again.
            Button("Try Again") { app.generate() }
                .buttonStyle(.glassProminent).controlSize(.large)
        case .responseTruncated:
            // The deck did not fit. Shorten it here rather than making the user
            // find the stepper and guess.
            Button("Use Fewer Slides") {
                app.slideCount = max(3, Int(Double(app.slideCount) * 0.6))
                app.startCreate()
            }
            .buttonStyle(.glassProminent).controlSize(.large)
        case .noKey, .authFailed:
            #if os(macOS)
            SettingsLink { Text("Open Settings") }
                .buttonStyle(.glassProminent).controlSize(.large)
            #else
            EmptyView()
            #endif
        case .schemaInvalid:
            #if os(macOS)
            // The draft's path is already in the message as unclickable prose.
            Button("Show Diagnostics") {
                let directory = AppState.diagnosticsDirectory()
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                NSWorkspace.shared.open(directory)
            }
            .buttonStyle(.glassProminent).controlSize(.large)
            #else
            EmptyView()
            #endif
        case .requestTooLarge, .renderFailed, .cancelled, .none:
            EmptyView()
        }
    }
}
