import SwiftUI
#if os(macOS)
import AppKit
#else
import QuickLook
#endif
import LecternCore

/// The decks already generated.
///
/// They were always on disk; the app just could not see them. Pressing New put
/// the previous deck permanently out of reach from inside Lectern, and each one
/// had cost a real API call — so the product forgot everything the user had
/// paid for. This is the way back to them.
struct DeckLibrarySheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: DeckFile?
    #if os(iOS)
    @State private var previewURL: URL?
    #endif

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if app.library.isEmpty {
                ContentUnavailableView(
                    "No decks yet",
                    systemImage: "rectangle.stack",
                    description: Text("Decks you generate are saved to \(Self.folderName) and appear here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(app.library) { deck in
                        DeckRow(deck: deck,
                                open: { open(deck) },
                                inspect: {
                                    app.inspect(deckAt: deck.url)
                                    dismiss()
                                },
                                reveal: { reveal(deck) },
                                delete: { pendingDelete = deck })
                    }
                }
                #if os(macOS)
                .listStyle(.inset)
                #endif
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 420)
        #endif
        .background(.background)
        .task { app.refreshLibrary() }
        #if os(iOS)
        .quickLookPreview($previewURL)
        #endif
        // A deck is a document the user made, so removing one asks first.
        .confirmationDialog(
            pendingDelete.map { "Delete “\($0.name)”?" } ?? "",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let deck = pendingDelete { app.deleteFromLibrary(deck) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(Self.deleteExplanation)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your decks").font(.title2.bold())
                Text(app.library.isEmpty
                     ? "Saved to \(Self.folderName)"
                     : "\(app.library.count) in \(Self.folderName)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }

    /// Named rather than shown as a full path: the point is that the user can
    /// find them in Finder or Files, not that they read a URL.
    private static var folderName: String {
        #if os(macOS)
        "Documents › Lectern"
        #else
        "Files › Lectern › Decks"
        #endif
    }

    private static var deleteExplanation: String {
        #if os(macOS)
        "It moves to the Trash, so you can put it back."
        #else
        "This can't be undone."
        #endif
    }

    private func open(_ deck: DeckFile) {
        #if os(macOS)
        NSWorkspace.shared.open(deck.url)
        #else
        previewURL = deck.url
        #endif
    }

    private func reveal(_ deck: DeckFile) {
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([deck.url])
        #endif
    }
}

private struct DeckRow: View {
    let deck: DeckFile
    let open: () -> Void
    let inspect: () -> Void
    let reveal: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.title2).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(deck.name).font(.headline).lineLimit(1).truncationMode(.middle)
                Text("\(deck.modified.formatted(date: .abbreviated, time: .shortened)) · \(size)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            #if os(macOS)
            Button("Inspect", action: inspect).buttonStyle(.glassProminent)
            Button("Open", action: open).buttonStyle(.glass)
            Button { reveal() } label: { Image(systemName: "folder") }
                .buttonStyle(.glass)
                .help("Reveal in Finder")
                .accessibilityLabel("Reveal \(deck.name) in Finder")
            #else
            Button("Inspect", action: inspect).buttonStyle(.glassProminent)
            Button("Preview", action: open).buttonStyle(.glass)
            ShareLink(item: deck.url) { Image(systemName: "square.and.arrow.up") }
                .accessibilityLabel("Share \(deck.name)")
            #endif
            Button(role: .destructive, action: delete) { Image(systemName: "trash") }
                .buttonStyle(.glass)
                .accessibilityLabel("Delete \(deck.name)")
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }

    private var size: String {
        ByteCountFormatter.string(fromByteCount: Int64(deck.byteCount), countStyle: .file)
    }
}
