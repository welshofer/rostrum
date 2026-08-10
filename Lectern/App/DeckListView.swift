import SwiftUI
#if os(macOS)
import AppKit
#endif
import LecternCore

/// Grid or list. Persisted, because it is a preference about how you like to
/// read your own files rather than a state of the current session.
enum LibraryLayout: String, CaseIterable {
    case grid, list

    var symbol: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }

    var label: String {
        switch self {
        case .grid: "Grid"
        case .list: "List"
        }
    }

}

/// One deck plus the facts the list shows in columns.
///
/// `Table` sorts over values it already has, so the slide count is resolved
/// into the row rather than faulted in per cell.
struct DeckListRow: Identifiable, Equatable {
    let deck: DeckFile
    let slideCount: Int

    var id: URL { deck.url }
    var name: String { deck.name }
    var modified: Date { deck.modified }
    var byteCount: Int { deck.byteCount }
}

/// The library as rows: name, when it changed, how big it is, how long it is.
///
/// A `Table` on macOS rather than a styled `List` — it brings sortable,
/// resizable column headers that a hand-rolled row would only imitate. iOS has
/// no room for columns, so it gets the same facts stacked.
struct DeckListView: View {
    @Environment(AppState.self) private var app
    let decks: [DeckFile]
    var onRename: (DeckFile) -> Void

    @State private var sortOrder = [KeyPathComparator(\DeckListRow.modified, order: .reverse)]
    @State private var selection: URL?

    private var rows: [DeckListRow] {
        decks
            .map { DeckListRow(deck: $0, slideCount: app.slideCounts[$0.url] ?? 0) }
            .sorted(using: sortOrder)
    }

    var body: some View {
        #if os(macOS)
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { row in
                HStack(spacing: 8) {
                    DeckThumbnail(url: row.deck.url,
                                  fallbackTitle: row.name,
                                  version: row.modified,
                                  width: 44)
                        .frame(width: 44, height: 25)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(.primary.opacity(0.12))
                        }
                    Text(row.name).lineLimit(1).truncationMode(.middle)
                }
                .padding(.vertical, 3)
            }
            TableColumn("Modified", value: \.modified) { row in
                Text(row.modified.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            .width(min: 140, ideal: 170)
            TableColumn("Size", value: \.byteCount) { row in
                Text(row.byteCount.formattedBytes)
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            .width(min: 70, ideal: 90)
            TableColumn("Slides", value: \.slideCount) { row in
                // Zero means "not read yet" rather than a deck with no slides,
                // which cannot be saved in the first place.
                Text(row.slideCount == 0 ? "—" : "\(row.slideCount)")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            .width(min: 60, ideal: 70)
        }
        .contextMenu(forSelectionType: URL.self) { urls in
            if let url = urls.first, let deck = decks.first(where: { $0.url == url }) {
                menu(for: deck)
            }
        } primaryAction: { urls in
            if let url = urls.first { app.inspect(deckAt: url) }
        }
        #else
        List(rows, selection: $selection) { row in
            Button { app.inspect(deckAt: row.deck.url) } label: {
                HStack(spacing: 12) {
                    DeckThumbnail(url: row.deck.url,
                                  fallbackTitle: row.name,
                                  version: row.modified,
                                  width: 64)
                        .frame(width: 64, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.name).font(.body.weight(.medium))
                            .lineLimit(1).truncationMode(.middle)
                        Text(detail(for: row)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .contextMenu { menu(for: row.deck) }
        }
        .listStyle(.inset)
        #endif
    }

    private func detail(for row: DeckListRow) -> String {
        var parts = [row.modified.formatted(date: .abbreviated, time: .omitted),
                     row.byteCount.formattedBytes]
        if row.slideCount > 0 { parts.append("\(row.slideCount) slides") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private func menu(for deck: DeckFile) -> some View {
        Button("Inspect") { app.inspect(deckAt: deck.url) }
        Button("Rename…") { onRename(deck) }
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

extension Int {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
    }
}
