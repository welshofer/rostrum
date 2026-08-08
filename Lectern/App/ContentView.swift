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
    #if os(iOS)
    @State private var showSettings = false
    #endif

    var body: some View {
        #if os(iOS)
        // iOS/iPadOS: no Settings scene exists, so a NavigationStack hosts the
        // toolbar gear that presents Settings as a sheet.
        NavigationStack {
            phaseView
                .navigationTitle("Lectern")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showSettings = true } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $showSettings) { SettingsView().environment(app) }
        }
        .task { await app.start(); await app.loadStyles() }
        #else
        // No sidebar — there's no deck History to show, so a single pane is honest.
        phaseView
            .frame(minWidth: 640, minHeight: 560)
            .task { await app.start(); await app.loadStyles() }
        #endif
    }

    /// The four principal states used to cut hard — a bare `switch` with no
    /// transition, so a two-minute paid generation resolved as an instant
    /// view swap. One soft cross-blur per phase change and a success tap when
    /// the deck lands; the states themselves are untouched.
    @ViewBuilder private var phaseView: some View {
        ZStack {
            switch app.phase {
            case .compose: ComposeView().transition(.blurReplace)
            case .generating: GeneratingView().transition(.blurReplace)
            case .result(let r): ResultView(result: r).transition(.blurReplace)
            case .failed(let m): FailedView(message: m).transition(.blurReplace)
            }
        }
        .animation(.smooth(duration: 0.35), value: app.phase)
        .sensoryFeedback(.success, trigger: app.phase) { _, newPhase in
            if case .result = newPhase { return true }
            return false
        }
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
                }

                let audienceGoalLayout = isCompact
                    ? AnyLayout(VStackLayout(spacing: 16))
                    : AnyLayout(HStackLayout(spacing: 16))
                audienceGoalLayout {
                    Card(title: "AUDIENCE", systemImage: "person.2") {
                        Picker("", selection: $app.audience) {
                            ForEach(Self.audiences, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu).labelsHidden()
                    }
                    Card(title: "GOAL", systemImage: "target") {
                        Picker("", selection: $app.goal) {
                            ForEach(["inform", "persuade", "entertain", "inspire"], id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden()
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
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text(app.stage).font(.title3.weight(.semibold)).contentTransition(.opacity)
            if app.total > 0 {
                ProgressView(value: Double(app.drafted), total: Double(app.total))
                    .frame(maxWidth: 280)
                Text("\(app.drafted) of \(app.total) \(app.progressNoun)").font(.callout).foregroundStyle(.secondary)
            }
            Button("Cancel", role: .cancel) { app.cancel() }.buttonStyle(.glass)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Spacer()
                Image(systemName: "checkmark.seal.fill").font(.system(size: 52)).foregroundStyle(.green)
                Spacer()
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
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundStyle(.orange)
            Text(message).font(.title3).multilineTextAlignment(.center).frame(maxWidth: 420)
            // Every failure used to funnel into one button back to the form,
            // even though `describe` knew exactly which one had happened. The
            // most common — a rate limit — cost the user their place for no
            // reason.
            HStack(spacing: 12) {
                recovery
                Button("Back to Compose") { app.reset() }
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
                app.reset()
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
