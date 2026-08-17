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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var section: LibrarySection = .recent
    @State private var query = ""
    @State private var preferredColumns: NavigationSplitViewVisibility = .all
    @State private var windowWidth: CGFloat = 1200

    /// How many deck columns to draw, decided by the **window** rather than by
    /// the space left over after the sidebar.
    ///
    /// `.adaptive` columns re-count themselves as the detail column narrows, so
    /// showing or hiding the sidebar moved every card into a different slot —
    /// and `LazyVGrid` does not animate that, it just re-places them. Deciding
    /// from the window keeps the count fixed across a sidebar toggle, and the
    /// flexible columns let the cards themselves narrow smoothly instead.
    private var deckColumnCount: Int {
        switch windowWidth {
        case ..<820: 1
        case ..<1180: 2
        case ..<1560: 3
        case ..<1960: 4
        default: 5
        }
    }
    @State private var droppingDeck = false
    /// A file-picker failure worth a word — an unmounted volume, a refused
    /// sandbox bookmark, an iCloud file that isn't downloaded yet. Nil the rest
    /// of the time. View-local because the failure is transient and belongs to
    /// this screen, not to shared app state.
    @State private var importError: String?
    /// How you like to read your own library, remembered between launches.
    @AppStorage("libraryLayout") private var layout: LibraryLayout = .grid
    #if os(iOS)
    @State private var showSettings = false
    #endif

    /// The extensions the inspector can actually open.
    static let deckExtensions = ["pptx", "potx", "ppsx"]

    /// The decks this app will open. A `.pptx` and nothing else — the
    /// inspector reads PresentationML, and offering the user a file it cannot
    /// open is a worse experience than not offering it.
    static let deckTypes: [UTType] = deckExtensions.compactMap {
        UTType(filenameExtension: $0)
    }

    var body: some View {
        @Bindable var app = app
        // One shell on every platform: a sidebar beside the work on a Mac and
        // an iPad, the same views pushed on a phone. NavigationSplitView is
        // what makes that one description rather than three.
        NavigationSplitView(columnVisibility: shellColumns) {
            LibrarySidebar(section: $section) { openSettings() }
                .navigationSplitViewColumnWidth(min: 240, ideal: 270, max: 320)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        // The window's own width, which — unlike the detail column's — does not
        // change when the sidebar comes and goes. Read from a background so it
        // observes the layout without taking part in it.
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { windowWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in windowWidth = width }
            }
        }
        // Dropping a deck on the window is the most natural way to open one,
        // and it belongs to the shell rather than to a screen — the target
        // moved out from under it once already when the home screen was
        // replaced by the library.
        .dropDestination(for: URL.self) { urls, _ in
            guard let deck = urls.first(where: {
                Self.deckExtensions.contains($0.pathExtension.lowercased())
            }) else { return false }
            app.inspect(deckAt: deck)
            return true
        } isTargeted: { droppingDeck = $0 }
        .overlay {
            if droppingDeck {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.tint, style: StrokeStyle(lineWidth: 2, dash: [7]))
                    .padding(10)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: droppingDeck)
        // Attached above the phase switch, not inside a phase: the menu bar
        // starts this flow too, and a picker owned by a view that isn't on
        // screen never opens.
        .fileImporter(isPresented: $app.isChoosingDeckToInspect,
                      allowedContentTypes: Self.deckTypes) { result in
            importError = FileImportOutcome.handle(result) { app.inspect(deckAt: $0) }
        }
        .alert("Couldn't open that deck",
               isPresented: Binding(get: { importError != nil },
                                    set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        #if os(iOS)
        .sheet(isPresented: $showSettings) { SettingsView().environment(app) }
        #endif
        .sheet(isPresented: $app.isShowingLibrary) { DeckLibrarySheet().environment(app) }
        // Creating and inspecting are both full-attention work, so they get the
        // whole window; the sidebar comes back with the library.
        .task { await app.start(); await app.loadStyles() }
    }

    /// The detail column. `home` is the library; every other phase is the work
    /// that replaced it, which is why they share the column rather than the
    /// library being one more destination.
    @ViewBuilder private var detail: some View {
        Group {
            switch app.phase {
            case .home:
                DeckGridView(section: section, query: $query, layout: layout,
                             columnCount: deckColumnCount)
                    .searchable(text: $query, placement: .toolbar, prompt: "Search")
                    .transition(phaseTransition)
            case .compose: ComposeView().transition(phaseTransition)
            case .generating: GeneratingView().transition(phaseTransition)
            case .result(let r): ResultView(result: r).transition(phaseTransition)
            case .failed(let m): FailedView(message: m).transition(phaseTransition)
            case .inspecting: InspectingView().transition(phaseTransition)
            case .inspected: InspectorView().transition(phaseTransition)
            }
        }
        .frame(minWidth: 520, minHeight: 480)
        .animation(shellMotion, value: app.phase)
        .sensoryFeedback(.success, trigger: app.phase) { _, newPhase in
            if case .result = newPhase { return true }
            if case .inspected = newPhase { return true }
            return false
        }
        .toolbar { toolbar }
    }

    // MARK: - Motion

    /// One curve for the whole shell.
    ///
    /// The sidebar and the content it makes room for are a single movement, so
    /// they cannot be two animations of different lengths.
    private var shellMotion: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.34)
    }

    /// Whether the sidebar is showing.
    ///
    /// Derived from the phase rather than set in reaction to it, and this is
    /// the whole point: `onChange` runs *after* the new phase has been laid
    /// out, so returning to the library laid the grid out twice — once at the
    /// full window width (four columns across), then again 270pt narrower once
    /// the sidebar arrived (three). A `LazyVGrid` does not animate a change of
    /// column count; the cards simply jump to new slots, in the middle of the
    /// transition that was supposed to be smooth.
    ///
    /// As a derived binding the visibility changes in the *same* update as the
    /// phase, so SwiftUI resolves one final width and lays the grid out once.
    ///
    /// The stored value is only the preference for when the library is showing,
    /// so hiding the sidebar by hand still sticks.
    private var shellColumns: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { app.phase == .home ? preferredColumns : .detailOnly },
            set: { newValue in
                // A drag or a toolbar toggle while the library is up is a
                // preference; the same thing during a task is not worth
                // remembering.
                if app.phase == .home { preferredColumns = newValue }
            })
    }

    /// A cross-fade, and nothing else.
    ///
    /// This was `.blurReplace`, then opacity with a small scale. Both make the
    /// compositor resample the entire subtree every frame — and that subtree is
    /// a dozen shadowed thumbnails. Opacity alone composites the layer without
    /// resampling it, which is the difference between a fade and a stutter.
    /// The scale was decoration; the frames are not.
    private var phaseTransition: AnyTransition { .opacity }

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
        } else {
            ToolbarItem {
                // A segmented picker rather than a single toggle: with one
                // button the icon has to mean either "what you have" or "what
                // you'll get", and every user reads it the other way. Showing
                // both, with one selected, cannot be misread — and it is what
                // Finder does.
                Picker("Layout", selection: $layout) {
                    ForEach(LibraryLayout.allCases, id: \.self) { option in
                        Label(option.label, systemImage: option.symbol)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help("Show your decks as a grid or a list")
                .accessibilityLabel("Library layout")
            }
        }
    }

    /// macOS opens the Settings scene through `SettingsLink` in the sidebar
    /// itself; only iOS, which has no such scene, needs a callback.
    private func openSettings() {
        #if !os(macOS)
        showSettings = true
        #endif
    }
}

// MARK: - File import

/// The one decision every `fileImporter` in the app shares: a `Result` is
/// either a URL to act on or an error to surface. `try? result.get()` collapsed
/// both a real failure and a plain Cancel into "do nothing" — no message, no
/// spinner, no explanation. This keeps the failure.
///
/// A user's Cancel never arrives here as a `.failure`: SwiftUI dismisses it
/// with no callback at all, so any `.failure` that does reach this point is a
/// genuine problem — an unmounted volume, a refused sandbox bookmark, an iCloud
/// file that isn't downloaded — and worth a word.
///
/// Factored out of the three call sites' closures so that once-silent failure
/// path is directly testable, without hosting the SwiftUI view that owns the
/// `@State` it drives (`@State` only takes effect inside a live hierarchy,
/// which a bare unit test cannot arrange).
enum FileImportOutcome {
    /// Run `onChosen` for a picked file and report no error; for a failure,
    /// skip the action and return the message the alert shows. The return value
    /// is exactly what the view assigns to its error state, so a success also
    /// clears any message left from a previous attempt.
    @MainActor
    @discardableResult
    static func handle(_ result: Result<URL, Error>,
                       onChosen: (URL) -> Void) -> String? {
        switch result {
        case .success(let url):
            onChosen(url)
            return nil
        case .failure(let error):
            return error.localizedDescription
        }
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
    /// A PDF-picker failure worth a word — the same transient, view-local shape
    /// the deck picker uses. Nil unless a `.failure` just came back.
    @State private var importError: String?
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
            importError = FileImportOutcome.handle(result) { url in
                Task { await app.attachPDF(url) }
            }
        }
        .alert("Couldn't open that PDF",
               isPresented: Binding(get: { importError != nil },
                                    set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            // A forever-repeating pulse is the exact thing Reduce Motion is
            // for. The tile still fills in; it just stops breathing.
            guard !reduceMotion else { return }
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
        case .noKey, .authFailed, .keyUnreadable:
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
