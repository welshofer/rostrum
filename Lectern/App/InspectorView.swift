import SwiftUI
#if os(macOS)
import AppKit
#endif
import UniformTypeIdentifiers
import LecternCore

/// What the deck turned out to be.
///
/// The counterpart to `ResultView`: same shape — a title band, the slides
/// themselves, then the actions — so the two halves of the app read as one
/// app. What differs is that everything here is a fact about a file somebody
/// else may have written, which is why the findings are not hidden behind a
/// success mark.
struct InspectorView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        Group {
            if let inspection = app.inspection {
                content(for: inspection)
            } else {
                // Only reachable if the phase and the payload ever disagree.
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(isPresented: $app.isChoosingExportDestination,
                      allowedContentTypes: [.folder]) { result in
            if let url = try? result.get() { app.exportInspected(into: url) }
        }
        .overlay {
            // Copying a deck's media out is measured in megabytes. The window
            // says so rather than going quiet.
            if app.isExporting { exportingOverlay }
        }
    }

    private func content(for inspection: DeckInspection) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(inspection.fileName).font(.title3.weight(.semibold))
                    .lineLimit(1).truncationMode(.middle)
                Text("\(inspection.slideCount) slide\(inspection.slideCount == 1 ? "" : "s") · "
                     + "\(inspection.formattedSize) · \(inspection.slideSize)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 24).padding(.horizontal, 24).padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 16) {
                    factsCard(inspection)
                    if !inspection.sections.isEmpty { sectionsCard(inspection) }
                    if inspection.hasFindings { findingsCard(inspection) }
                    if !inspection.previews.isEmpty {
                        Card(title: "SLIDES", systemImage: "rectangle.on.rectangle") {
                            SlideContactSheet(previews: inspection.previews,
                                              titles: inspection.previewTitles)
                                .frame(minHeight: 260)
                        }
                    }
                    textCard(inspection)
                    if let summary = app.exportSummary { exportReport(summary) }
                }
                .padding(20)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }

            Divider()
            actionBar(inspection)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cards

    private func factsCard(_ inspection: DeckInspection) -> some View {
        Card(title: "WHAT'S INSIDE", systemImage: "shippingbox") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 12)],
                      alignment: .leading, spacing: 12) {
                Stat("Slides", inspection.slideCount)
                Stat("Layouts", inspection.layoutCount)
                Stat("Masters", inspection.masterCount)
                Stat("Media", inspection.mediaCount)
                Stat("Charts", inspection.chartCount)
                Stat("Workbooks", inspection.embedCount)
                Stat("Notes", inspection.notesCount)
                Stat("Parts", inspection.partCount)
            }
        }
    }

    private func sectionsCard(_ inspection: DeckInspection) -> some View {
        Card(title: "SECTIONS", systemImage: "list.bullet.indent") {
            Text(inspection.sections.joined(separator: " · "))
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func findingsCard(_ inspection: DeckInspection) -> some View {
        Card(title: "FINDINGS", systemImage: "exclamationmark.triangle") {
            VStack(alignment: .leading, spacing: 10) {
                if !inspection.schemaIssues.isEmpty {
                    DisclosureGroup("\(inspection.schemaIssues.count) schema issue(s)") {
                        ForEach(inspection.schemaIssues, id: \.self) {
                            Text($0).font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                if !inspection.readWarnings.isEmpty {
                    DisclosureGroup("\(inspection.readWarnings.count) part(s) the reader couldn't place") {
                        ForEach(inspection.readWarnings, id: \.self) {
                            Text($0).font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                if !inspection.outlineWarnings.isEmpty {
                    DisclosureGroup("\(inspection.outlineWarnings.count) slide(s) couldn't be read") {
                        ForEach(inspection.outlineWarnings, id: \.self) {
                            Text($0).font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private func textCard(_ inspection: DeckInspection) -> some View {
        Card(title: "EVERY WORD IN IT", systemImage: "text.alignleft") {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(inspection.slides) { slide in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(slide.number)")
                                .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                            Text(slide.title ?? "(untitled)")
                                .font(.headline)
                                .foregroundStyle(slide.title == nil ? .secondary : .primary)
                        }
                        if let subtitle = slide.subtitle {
                            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach(Array(slide.bullets.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.callout).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if slide.tableCount > 0 || slide.hasAttachments {
                            Text(cargo(of: slide)).font(.caption).foregroundStyle(.tertiary)
                        }
                        ForEach(Array(slide.notes.enumerated()), id: \.offset) { _, note in
                            Label(note, systemImage: "text.bubble")
                                .font(.caption).foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// The one-line "and it also carries…" under a slide's text.
    private func cargo(of slide: SlideDigest) -> String {
        var parts: [String] = []
        if slide.tableCount > 0 {
            parts.append("\(slide.tableCount) table\(slide.tableCount == 1 ? "" : "s")")
        }
        if !slide.chartTitles.isEmpty {
            parts.append("charts: " + slide.chartTitles.joined(separator: ", "))
        }
        if !slide.assetNames.isEmpty {
            parts.append(slide.assetNames.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    private func exportReport(_ summary: String) -> some View {
        Card(title: "EXPORTED", systemImage: "checkmark.seal") {
            VStack(alignment: .leading, spacing: 8) {
                Text(summary).font(.callout).foregroundStyle(.secondary)
                if let problem = app.exportProblem {
                    Label(problem, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
                #if os(macOS)
                if let directory = app.exportedDirectory {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([directory])
                    }
                    .buttonStyle(.glass)
                }
                #endif
            }
        }
    }

    // MARK: - Actions

    private func actionBar(_ inspection: DeckInspection) -> some View {
        HStack(spacing: 12) {
            Button { app.goHome() } label: { Label("Done", systemImage: "chevron.left") }
                .buttonStyle(.glass)
            Spacer()
            if let problem = app.exportProblem, app.exportSummary == nil {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange).lineLimit(2)
            }
            Button { app.chooseDeckToInspect() } label: {
                Label("Open Another", systemImage: "folder")
            }
            .buttonStyle(.glass)
            Button { app.isChoosingExportDestination = true } label: {
                Label("Export Everything…", systemImage: "square.and.arrow.down.on.square")
                    .font(.body.weight(.semibold)).padding(.horizontal, 6)
            }
            .buttonStyle(.glassProminent)
            .disabled(app.isExporting)
            .help("Write this deck's text, media and chart data into a folder")
        }
        .controlSize(.large)
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.bar)
    }

    private var exportingOverlay: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text("Writing the export…").font(.headline)
                Text("Copying media and chart data out of the deck.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(maxWidth: 300)
            .background(.regularMaterial, in: .rect(cornerRadius: 18, style: .continuous))
        }
        .transition(.opacity)
    }
}

/// One labelled number in the facts grid.
private struct Stat: View {
    let label: String
    let value: Int

    init(_ label: String, _ value: Int) {
        self.label = label
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(.title3.weight(.semibold).monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
