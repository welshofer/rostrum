import SwiftUI
import LecternCore

/// The full style gallery (§6.2): search, tag chips, and Favorites / Recents /
/// All-150 sections of thumbnail cards. Selection dismisses and updates Compose.
struct StylePickerSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var activeTag: String?

    private let columns = [GridItem(.adaptive(minimum: 236, maximum: 320), spacing: 16)]

    /// Curated chip row: theme (light/dark) then the vibes by descending count —
    /// every chip selects a meaningful slice of the catalog. The raw tag union
    /// surfaced the category long-tail first (20 categories, half covering 1–3
    /// styles), which read as broken metadata. Categories stay reachable
    /// through text search, which matches all tags.
    private var pillTags: [String] {
        let themes = ["light", "dark"].filter { t in app.styles.contains { $0.tags.contains(t) } }
        let vibeCounts = Dictionary(app.styles.compactMap { $0.vibe.map { ($0.lowercased(), 1) } },
                                    uniquingKeysWith: +)
        let vibes = vibeCounts.sorted { ($1.value, $0.key) < ($0.value, $1.key) }.map(\.key)
        return themes + vibes
    }

    private func matches(_ s: Style) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let tagOK = activeTag == nil || s.tags.contains(activeTag!)
        let qOK = q.isEmpty || s.name.lowercased().contains(q)
            || s.tags.contains { $0.contains(q) } || (s.vibe?.lowercased().contains(q) ?? false)
        return tagOK && qOK
    }

    private var filtered: [Style] { app.styles.filter(matches) }
    private var favorites: [Style] { filtered.filter { app.isFavorite($0.slug) } }
    private var recents: [Style] { app.recents.compactMap { slug in filtered.first { $0.slug == slug } } }

    var body: some View {
        VStack(spacing: 0) {
            header
            controls
            Divider().padding(.top, 12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    if filtered.isEmpty {
                        ContentUnavailableView(
                            "No styles match",
                            systemImage: "paintpalette",
                            description: Text("Try a different search or clear the filter."))
                            .frame(maxWidth: .infinity)
                    } else {
                        if !favorites.isEmpty { section("Favorites", favorites) }
                        if !recents.isEmpty { section("Recents", recents) }
                        section(activeTag == nil && query.isEmpty ? "All \(app.styles.count)" : "\(filtered.count) results", filtered)
                    }
                }
                .padding(20)
            }
        }
        #if os(macOS)
        .frame(minWidth: 860, minHeight: 640)
        #endif
        .background(.background)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Choose a style").font(.title2.bold())
                Text("Every deck renders in the selected design").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search 150 styles by name or vibe", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(.regularMaterial, in: .capsule)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    TagChip("All", selected: activeTag == nil) { activeTag = nil }
                    ForEach(pillTags, id: \.self) { tag in
                        TagChip(tag.capitalized, selected: activeTag == tag) {
                            activeTag = activeTag == tag ? nil : tag
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder private func section(_ title: String, _ items: [Style]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3.bold())
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { style in
                    StyleCard(style: style,
                              isSelected: style.slug == app.selectedStyleSlug,
                              isFavorite: app.isFavorite(style.slug),
                              onSelect: { app.selectStyle(style.slug); dismiss() },
                              onFavorite: { app.toggleFavorite(style.slug) })
                }
            }
        }
    }
}

struct TagChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    init(_ title: String, selected: Bool, action: @escaping () -> Void) {
        self.title = title; self.selected = selected; self.action = action
    }
    var body: some View {
        Button(action: action) {
            // Capsule, padding and content shape all live *inside* the label:
            // `.plain` hit-tests the label's drawn content, so with the
            // background hung on the Button the pill's padding was dead space
            // and only the glyphs themselves selected a filter.
            Text(title)
                .font(.callout.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .padding(.horizontal, 13).padding(.vertical, 6)
                #if !os(macOS)
                .frame(minWidth: 44, minHeight: 44)     // HIG touch minimum
                #endif
                .background(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial),
                            in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
