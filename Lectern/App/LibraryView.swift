import SwiftUI
#if os(macOS)
import AppKit
#else
import QuickLook
#endif
import LecternCore

/// Which set of decks the detail column is showing.
enum LibrarySection: Hashable, CaseIterable {
    case recent, all

    var title: String {
        switch self {
        case .recent: "Recent"
        case .all: "All Decks"
        }
    }

    var heading: String {
        switch self {
        case .recent: "Recent Decks"
        case .all: "All Decks"
        }
    }

    var symbol: String {
        switch self {
        case .recent: "clock"
        case .all: "folder"
        }
    }
}

// MARK: - Sidebar

/// The app's identity, its two verbs, and where the decks are.
///
/// The verbs sit above the navigation rather than inside it because they are
/// actions, not places: pressing New Deck does not select anything.
struct LibrarySidebar: View {
    @Environment(AppState.self) private var app
    @Binding var section: LibrarySection
    var onSettings: () -> Void

    /// `List(selection:)` takes an optional on iOS and a plain value on macOS.
    /// One optional-backed proxy lets both platforms share the same list, and
    /// a deselect (which only iOS can produce) keeps the current section
    /// rather than emptying the detail column.
    private var selectionProxy: Binding<LibrarySection?> {
        Binding(get: { section },
                set: { newValue in if let newValue { section = newValue } })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text("Lectern").font(.title2.weight(.semibold))
            } icon: {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.title2).foregroundStyle(.tint)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 22)

            VStack(spacing: 10) {
                SidebarAction(title: "New Deck", systemImage: "sparkles", prominent: true) {
                    app.startCreate()
                }
                SidebarAction(title: "Inspect Deck…", systemImage: "doc.viewfinder") {
                    app.chooseDeckToInspect()
                }
            }
            .padding(.horizontal, 16)

            Divider().padding(.horizontal, 20).padding(.vertical, 18)

            List(selection: selectionProxy) {
                ForEach(LibrarySection.allCases, id: \.self) { item in
                    Label {
                        HStack {
                            Text(item.title)
                            if item == .all, !app.library.isEmpty {
                                Spacer()
                                Text("\(app.library.count)")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: item.symbol)
                    }
                    .tag(item)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider().padding(.horizontal, 20).padding(.bottom, 12)

            // `SettingsLink` is the only supported way to open the Settings
            // scene — the old `showSettingsWindow:` selector is private and has
            // been renamed at least once between releases.
            #if os(macOS)
            SettingsLink {
                SidebarActionLabel(title: "Settings", systemImage: "gearshape")
            }
            .modifier(SidebarActionChrome(prominent: false))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            #else
            SidebarAction(title: "Settings", systemImage: "gearshape", action: onSettings)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            #endif
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// The contents of a sidebar button, without the button.
///
/// Split out so a `Button` and a `SettingsLink` — which cannot be a Button —
/// look identical rather than nearly identical.
private struct SidebarActionLabel: View {
    let title: String
    let systemImage: String
    var prominent = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.body.weight(prominent ? .semibold : .regular))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .contentShape(.rect)
    }
}

/// The surface a sidebar action sits on.
private struct SidebarActionChrome: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(prominent ? AnyShapeStyle(.tint.opacity(0.12))
                                    : AnyShapeStyle(.quaternary.opacity(0.5)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(prominent ? AnyShapeStyle(.tint.opacity(0.35))
                                            : AnyShapeStyle(.quaternary))
            }
            .foregroundStyle(prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
    }
}

/// A full-width sidebar button. Bordered rather than plain so the two verbs
/// read as things you press, next to a list of things you go to.
private struct SidebarAction: View {
    let title: String
    let systemImage: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SidebarActionLabel(title: title, systemImage: systemImage, prominent: prominent)
        }
        .modifier(SidebarActionChrome(prominent: prominent))
    }
}

// MARK: - Grid

/// The decks themselves.
struct DeckGridView: View {
    @Environment(AppState.self) private var app
    let section: LibrarySection
    @Binding var query: String
    let layout: LibraryLayout
    /// Fixed, and decided by the window rather than by this column's width —
    /// see `ContentView.deckColumnCount`. Flexible columns then let the cards
    /// resize with the sidebar instead of being re-dealt into new slots.
    let columnCount: Int
    @State private var renaming: DeckFile?
    @State private var draftName = ""

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 22, alignment: .top),
              count: max(1, columnCount))
    }

    private var decks: [DeckFile] {
        let base = section == .recent ? Array(app.library.prefix(12)) : app.library
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return base }
        let needles = trimmed.lowercased().split(separator: " ").map(String.init)
        return base.filter { deck in
            let name = deck.name.lowercased()
            return needles.allSatisfy { name.contains($0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                if decks.isEmpty {
                    empty
                } else if layout == .list {
                    DeckListView(decks: decks) { deck in
                        renaming = deck
                        draftName = deck.name
                    }
                    .frame(minHeight: 420)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 30) {
                        ForEach(decks) { deck in
                            DeckCardView(deck: deck) {
                                renaming = deck
                                draftName = deck.name
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 36)
        }
        .task(id: app.library.count) { app.refreshLibrary() }
        // The list shows slide count as a sortable column, so it needs every
        // value rather than one per visible row. Cheap now that a count is one
        // zip entry, and cached after the first pass.
        .task(id: "\(layout.rawValue)-\(app.library.count)") {
            if layout == .list { await app.loadSlideCounts() }
        }
        .alert("Rename deck",
               isPresented: Binding(get: { renaming != nil },
                                    set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $draftName)
            Button("Rename") {
                if let deck = renaming { app.renameInLibrary(deck, to: draftName) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: {
            Text("The file is renamed too, so it reads the same in Finder.")
        }
        .alert("Couldn't rename that deck",
               isPresented: Binding(get: { app.renameProblem != nil },
                                    set: { if !$0 { app.renameProblem = nil } })) {
            Button("OK", role: .cancel) { app.renameProblem = nil }
        } message: {
            Text(app.renameProblem ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(section.heading)
                .font(.system(.largeTitle, design: .default, weight: .bold))
            Spacer(minLength: 16)
            Text("Start with a new deck")
                .font(.callout).foregroundStyle(.secondary)
                .lineLimit(1)
            Button("Create") { app.startCreate() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    @ViewBuilder private var empty: some View {
        if !query.isEmpty {
            ContentUnavailableView.search(text: query)
                .frame(maxWidth: .infinity, minHeight: 320)
        } else if !app.hasKey {
            // First run. Create needs a key and will fail on the first press
            // without one, and nothing used to say so — while Inspect works
            // perfectly well with no key at all.
            ContentUnavailableView {
                Label("Welcome to Lectern", systemImage: "sparkles")
            } description: {
                Text("Describe a deck and Lectern writes the .pptx. "
                     + "That needs an API key — or open a deck you already have, "
                     + "which needs nothing.")
            } actions: {
                VStack(spacing: 10) {
                    #if os(macOS)
                    SettingsLink { Text("Add an API key") }
                        .buttonStyle(.borderedProminent)
                    #endif
                    Button("Inspect a deck instead") { app.chooseDeckToInspect() }
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        } else {
            ContentUnavailableView {
                Label("No decks yet", systemImage: "rectangle.stack")
            } description: {
                Text("Decks you make are saved to your Lectern folder and appear here.")
            } actions: {
                Button("New Deck") { app.startCreate() }.buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        }
    }
}

// MARK: - One card

/// A deck as a cover, a name and two facts.
///
/// The cover is drawn from the deck's own theme rather than rasterized from its
/// first slide: a real render costs a WebKit snapshot per card, and the thing
/// that makes a deck recognisable at this size is its colour and its title, not
/// its layout.
struct DeckCardView: View {
    @Environment(AppState.self) private var app
    let deck: DeckFile
    /// Renaming is presented by the grid, not the card: an alert owned by a
    /// cell inside a LazyVGrid goes away with the cell when it scrolls.
    var onRename: () -> Void = {}

    @State private var card: DeckCard?
    @State private var hovering = false

    var body: some View {
        // A real Button, not a tap gesture wearing `.isButton`: the trait made
        // it *look* activatable to VoiceOver and to the keyboard while only a
        // mouse could actually open it. A Button gets press, focus, keyboard
        // activation and the trait for free, and they agree with each other.
        Button {
            app.inspect(deckAt: deck.url)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                DeckThumbnail(url: deck.url,
                              fallbackTitle: deck.name,
                              version: deck.modified,
                              width: 340)
                    .frame(maxWidth: .infinity)
                    // Slides are 16:9, so the card is too — a deck's own
                    // picture arrives uncropped rather than trimmed to a nicer
                    // rectangle.
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.primary.opacity(0.10))
                    }
                    .shadow(color: .black.opacity(hovering ? 0.18 : 0.10),
                            radius: hovering ? 14 : 6, y: hovering ? 7 : 3)
                    .scaleEffect(hovering ? 1.015 : 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(deck.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1).truncationMode(.middle)
                    Text("Modified \(deck.modified.formatted(date: .abbreviated, time: .omitted))")
                        .font(.callout).foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(card.map { "\($0.slideCount) slide\($0.slideCount == 1 ? "" : "s")" }
                         ?? deck.byteCount.formattedByteCount)
                        .font(.callout).foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.smooth(duration: 0.18), value: hovering)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Opens this deck in the inspector")
        .contextMenu { menu }
        .task(id: deck.id) {
            card = await DeckCardIndex.shared.card(for: deck)
        }
    }

    private var accessibilityText: String {
        var parts = [deck.name,
                     "modified \(deck.modified.formatted(date: .abbreviated, time: .omitted))"]
        if let card { parts.append("\(card.slideCount) slides") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder private var menu: some View {
        Button("Inspect") { app.inspect(deckAt: deck.url) }
        Button("Rename…") { onRename() }
        #if os(macOS)
        Button("Open in PowerPoint") { NSWorkspace.shared.open(deck.url) }
        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([deck.url])
        }
        #endif
        ShareLink(item: deck.url)
        Divider()
        Button("Delete…", role: .destructive) { app.deleteFromLibrary(deck) }
    }
}

private extension Int {
    var formattedByteCount: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
    }
}
