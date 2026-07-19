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

    private var allTags: [String] { Array(Set(app.styles.flatMap(\.tags))).sorted() }

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
                    if !favorites.isEmpty { section("Favorites", favorites) }
                    if !recents.isEmpty { section("Recents", recents) }
                    section(activeTag == nil && query.isEmpty ? "All \(app.styles.count)" : "\(filtered.count) results", filtered)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 860, minHeight: 640)
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
                    ForEach(allTags, id: \.self) { tag in
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
            Text(title)
                .font(.callout.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 13).padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial), in: .capsule)
        .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
    }
}
