import SwiftUI
#if os(macOS)
import AppKit
#endif
import UniformTypeIdentifiers
import LecternCore

/// Put a template's brand on a deck you already have.
///
/// The other half of the product, and the half that exercises Rostrum's read
/// side: everything else here starts from an empty presentation, and this
/// starts from someone else's file.
struct RebrandSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var choosingDeck = false
    @State private var choosingTemplate = false

    /// Every PresentationML shape Rostrum can open, on both sides of the sheet.
    /// A `.potx` is a perfectly good deck to rebrand (it has slides) and a
    /// `.pptx` is a perfectly good brand to borrow, so narrowing either slot
    /// only greys out files that would have worked. `DeckRebrander` re-kinds
    /// the result to `.presentation` on save.
    private static let presentationTypes: [UTType] = ["pptx", "potx", "ppsx"]
        .map { UTType(filenameExtension: $0) ?? .data }

    var body: some View {
        @Bindable var app = app
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    filePicker(
                        title: "THE DECK",
                        systemImage: "doc.richtext",
                        prompt: "Choose the deck you want rebranded — .pptx, .potx or .ppsx",
                        url: app.rebrandDeck,
                        isPresented: $choosingDeck,
                        types: Self.presentationTypes) { app.setRebrandDeck($0) }

                    filePicker(
                        title: "THE BRAND",
                        systemImage: "paintpalette",
                        prompt: "Choose a .potx template — or any .pptx to borrow its look",
                        url: app.rebrandTemplate,
                        isPresented: $choosingTemplate,
                        types: Self.presentationTypes) { app.setRebrandTemplate($0) }

                    Card(title: "HOW FAR TO GO", systemImage: "wand.and.stars") {
                        Toggle("Rebind hard-coded colours and fonts", isOn: $app.rebindFormatting)
                            .toggleStyle(.switch)
                        Text(app.rebindFormatting
                             ? "Colours and fonts that came from the deck's own theme become theme "
                               + "references, so the new brand reaches them. Anything the designer "
                               + "chose off-palette is left alone."
                             : "Only the masters, layouts and theme are replaced. A deck with "
                               + "hard-coded formatting will come out looking much as it went in.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) { actions }
        }
        #if os(macOS)
        .frame(minWidth: 620, minHeight: 520)
        #endif
        .background(.background)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rebrand a deck").font(.title2.bold())
                Text("Keep the words, change the brand").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") { dismiss() }.buttonStyle(.glass)
        }
        .padding(20)
    }

    /// One card, one file.
    ///
    /// The first cut hung two `.fileImporter` modifiers on the same view and
    /// **neither Choose button did anything at all**. SwiftUI honours at most
    /// one importer per view, and a `.fileImporter` presented from inside a
    /// `.sheet` is unreliable on macOS besides — two independent reasons for
    /// the same symptom, and no way to tell them apart without running it.
    ///
    /// So macOS does not use `.fileImporter`. `NSOpenPanel` is the native
    /// panel, it does not depend on SwiftUI's presentation plumbing, and it
    /// goes through the same powerbox grant. iOS keeps `.fileImporter`, which
    /// is the only option there and is not presented from a nested sheet.
    @ViewBuilder private func filePicker(title: String, systemImage: String, prompt: String,
                                         url: URL?, isPresented: Binding<Bool>,
                                         types: [UTType],
                                         pick: @escaping (URL) -> Void) -> some View {
        Card(title: title, systemImage: systemImage) {
            if let url {
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill").font(.title2).foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.lastPathComponent).font(.headline).lineLimit(1).truncationMode(.middle)
                        Text(url.deletingLastPathComponent().lastPathComponent)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    chooseButton("Change…", isPresented: isPresented, types: types, pick: pick)
                }
            } else {
                VStack(spacing: 10) {
                    Text(prompt).font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    chooseButton("Choose…", isPresented: isPresented, types: types, pick: pick)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 18)
            }
        }
    }

    /// The button that opens a file panel, by whatever route actually works
    /// on this platform.
    @ViewBuilder private func chooseButton(_ label: String, isPresented: Binding<Bool>,
                                           types: [UTType],
                                           pick: @escaping (URL) -> Void) -> some View {
        #if os(macOS)
        Button(label) {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = types
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.message = "Choose a PowerPoint file"
            if panel.runModal() == .OK, let url = panel.url { pick(url) }
        }
        .buttonStyle(.glass)
        #else
        Button(label) { isPresented.wrappedValue = true }
            .buttonStyle(.glass)
            .fileImporter(isPresented: isPresented, allowedContentTypes: types) { result in
                if let picked = try? result.get() { pick(picked) }
            }
        #endif
    }

    private var actions: some View {
        HStack(spacing: 14) {
            Text(app.canRebrand ? "The original is never modified — a new deck is written."
                                : "Choose a deck and a template.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
            Button { app.rebrand(); dismiss() } label: {
                Label("Rebrand", systemImage: "wand.and.stars")
                    .font(.body.weight(.semibold)).padding(.horizontal, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!app.canRebrand)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.bar)
    }
}

/// What the rebrand did, shown as before and after.
///
/// The comparison is the whole point: a rebrand nobody can see is
/// indistinguishable from one that never ran.
struct RebrandResultView: View {
    @Environment(AppState.self) private var app
    let result: RebrandResult
    @State private var showingAfter = true

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(result.url.lastPathComponent).font(.title3.weight(.semibold))
                    .lineLimit(1).truncationMode(.middle)
                Text(summary).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 24).padding(.horizontal, 24).padding(.bottom, 12)

            Picker("", selection: $showingAfter) {
                Text("Before").tag(false)
                Text("After").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 260)
            .padding(.bottom, 12)

            SlideContactSheet(previews: showingAfter ? result.after : result.before)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()

            VStack(spacing: 14) {
                #if os(macOS)
                HStack(spacing: 12) {
                    Button { NSWorkspace.shared.open(result.url) } label: {
                        Label("Open", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.glassProminent)
                    Button { NSWorkspace.shared.activateFileViewerSelecting([result.url]) } label: {
                        Label("Reveal", systemImage: "folder")
                    }
                    .buttonStyle(.glass)
                    Button("Done") { app.reset() }.buttonStyle(.glass)
                }
                .controlSize(.large)
                #else
                HStack(spacing: 12) {
                    ShareLink(item: result.url) { Label("Share", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.glassProminent)
                    Button("Done") { app.reset() }.buttonStyle(.glass)
                }
                .controlSize(.large)
                #endif

                if !result.kept.isEmpty {
                    // Not a failure, and not ours to hide: the template had no
                    // layout for these, so they kept their own rather than
                    // being dropped onto something that would misplace them.
                    DisclosureGroup("\(result.kept.count) slide(s) kept their original layout") {
                        Text("Slides \(result.kept.map(String.init).joined(separator: ", ")) use a "
                             + "layout this template has no counterpart for. They are unchanged "
                             + "rather than forced onto a layout that would put their text in the "
                             + "wrong place.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 460)
                }
                if !result.schemaIssues.isEmpty {
                    DisclosureGroup("\(result.schemaIssues.count) schema issue(s) in the written deck") {
                        ForEach(result.schemaIssues.prefix(20), id: \.self) {
                            Text($0).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: 460)
                }
            }
            .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summary: String {
        var parts = ["\(result.slideCount) slides", "\(result.relaid) re-laid"]
        if result.reboundColors > 0 || result.reboundFonts > 0 {
            parts.append("\(result.reboundColors) colours and \(result.reboundFonts) fonts rebound")
        }
        return parts.joined(separator: " · ")
    }
}

/// The wait while a deck is opened, re-laid and written.
struct RebrandingView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text("Rebranding").font(.title3.weight(.semibold))
            Text("Opening the deck, adopting the template, rendering both")
                .font(.callout).foregroundStyle(.secondary)
            Button("Cancel", role: .cancel) { app.cancelRebrand() }.buttonStyle(.glass)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityValue("Rebranding in progress")
    }
}
