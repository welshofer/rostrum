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

    /// Cards size themselves between a readable floor and a ceiling past which
    /// a thumbnail stops earning its width. `.top` so rows stay aligned when a
    /// title wraps differently from its neighbour's.
    private let columns = [GridItem(.adaptive(minimum: 260, maximum: 380),
                                    spacing: 22, alignment: .top)]

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
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 30) {
                        ForEach(decks) { deck in
                            DeckCardView(deck: deck)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 36)
        }
        .task(id: app.library.count) { app.refreshLibrary() }
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
        if query.isEmpty {
            ContentUnavailableView {
                Label("No decks yet", systemImage: "rectangle.stack")
            } description: {
                Text("Decks you make are saved to your Lectern folder and appear here.")
            } actions: {
                Button("New Deck") { app.startCreate() }.buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        } else {
            ContentUnavailableView.search(text: query)
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

    @State private var card: DeckCard?
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DeckThumbnail(url: deck.url, fallbackTitle: deck.name)
                .frame(maxWidth: .infinity)
                // Slides are 16:9, so the card is too — a deck's own picture
                // arrives uncropped rather than trimmed to a nicer rectangle.
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
        .onTapGesture { app.inspect(deckAt: deck.url) }
        .onHover { hovering = $0 }
        .animation(.smooth(duration: 0.18), value: hovering)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
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
