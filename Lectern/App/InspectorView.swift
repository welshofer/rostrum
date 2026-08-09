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
        Group {
            if let inspection = app.inspection {
                content(for: inspection)
            } else {
                // Only reachable if the phase and the payload ever disagree.
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        #if !os(macOS)
        // macOS uses a real open panel instead, because `fileImporter` gives no
        // way to create a folder — see `chooseExportDestination`.
        .fileImporter(isPresented: exportDestinationBinding,
                      allowedContentTypes: [.folder]) { result in
            if let url = try? result.get() { app.exportInspected(into: url) }
        }
        #endif
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
                Text(inspection.documentKind)
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.top, 24).padding(.horizontal, 24).padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 16) {
                    factsCard(inspection)
                    if !inspection.sections.isEmpty { sectionsCard(inspection) }
                    if inspection.hasFindings { findingsCard(inspection) }
                    if !inspection.masters.isEmpty { mastersCard(inspection) }
                    if !inspection.charts.isEmpty { chartsCard(inspection) }
                    if hasFonts(inspection) { fontsCard(inspection) }
                    if !inspection.properties.isEmpty { propertiesCard(inspection) }
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
            VStack(alignment: .leading, spacing: 6) {
                ForEach(inspection.sections) { section in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(section.name).font(.callout)
                        Spacer(minLength: 12)
                        Text("\(section.slideCount) slide\(section.slideCount == 1 ? "" : "s")")
                            .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// The masters a deck is actually built on, and the layouts each owns.
    /// A deck with three masters is usually three decks somebody pasted
    /// together, so this is worth showing rather than counting.
    private func mastersCard(_ inspection: DeckInspection) -> some View {
        Card(title: "MASTERS & LAYOUTS", systemImage: "square.stack") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(inspection.masters) { master in
                    DisclosureGroup {
                        Text(master.layoutNames.isEmpty
                             ? "No layouts"
                             : master.layoutNames.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(master.name).font(.callout)
                            Spacer(minLength: 12)
                            Text(fontPair(of: master))
                                .font(.caption).foregroundStyle(.tertiary)
                            Text("\(master.layoutNames.count)")
                                .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private func fontPair(of master: MasterInspection) -> String {
        [master.majorFont, master.minorFont].compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    /// What the charts plot — and whether Lectern could write new numbers back
    /// into them, which is the question the rest of the app cares about.
    private func chartsCard(_ inspection: DeckInspection) -> some View {
        Card(title: "CHARTS", systemImage: "chart.bar") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(inspection.charts) { chart in
                    ChartRow(chart: chart)
                }
            }
        }
    }

    private func hasFonts(_ inspection: DeckInspection) -> Bool {
        !inspection.themeFonts.isEmpty || !inspection.explicitFonts.isEmpty
            || !inspection.embeddedFonts.isEmpty
    }

    /// Three font lists that answer three different questions: what the theme
    /// asks for, what the slides override it with, and what the file carries
    /// so it looks the same somewhere else.
    private func fontsCard(_ inspection: DeckInspection) -> some View {
        Card(title: "FONTS", systemImage: "textformat") {
            VStack(alignment: .leading, spacing: 8) {
                fontRow("Theme", inspection.themeFonts)
                fontRow("Named on slides", inspection.explicitFonts)
                fontRow("Embedded", inspection.embeddedFonts)
            }
        }
    }

    @ViewBuilder private func fontRow(_ label: String, _ fonts: [String]) -> some View {
        if !fonts.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased()).font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Text(fonts.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func propertiesCard(_ inspection: DeckInspection) -> some View {
        Card(title: "WHO MADE IT", systemImage: "person.text.rectangle") {
            VStack(alignment: .leading, spacing: 4) {
                let properties = inspection.properties
                propertyRow("Title", properties.title)
                propertyRow("Author", properties.author)
                propertyRow("Company", properties.company)
                propertyRow("Subject", properties.subject)
                propertyRow("Keywords", properties.keywords)
                propertyRow("Category", properties.category)
                propertyRow("Application", properties.application)
                propertyRow("Created", properties.created.map(Self.dateFormatter.string(from:)))
                propertyRow("Modified", properties.modified.map(Self.dateFormatter.string(from:)))
            }
        }
    }

    @ViewBuilder private func propertyRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label).font(.caption).foregroundStyle(.tertiary)
                    .frame(width: 92, alignment: .leading)
                Text(value).font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

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
                        Text(slide.layoutName).font(.caption2).foregroundStyle(.tertiary)
                        ForEach(slide.comments) { comment in
                            Label("\(comment.author): \(comment.text)"
                                  + (comment.replyCount > 0 ? " (+\(comment.replyCount))" : ""),
                                  systemImage: comment.resolved
                                    ? "checkmark.bubble" : "bubble.left.and.bubble.right")
                                .font(.caption).foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Choosing where the export goes

    /// Ask for the folder to export into.
    ///
    /// On macOS this is a real `NSOpenPanel` rather than SwiftUI's
    /// `fileImporter`, for one reason: `fileImporter` cannot offer to *create*
    /// a folder, and the folder a person wants to export a deck into usually
    /// does not exist yet. `canCreateDirectories` is what puts the New Folder
    /// button on the panel.
    private func chooseExportDestination(for inspection: DeckInspection) {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Here"
        panel.title = "Export “\(inspection.fileName)”"
        // The exporter makes its own folder inside whatever is chosen, so say
        // which one rather than leaving a person to guess where it landed.
        panel.message = "Choose or create a folder. Lectern will write "
            + "“\(DeckExporter.folderName(for: inspection.fileURL))” inside it."
        // Start beside the deck itself: exporting next to the original is the
        // common case, and it makes New Folder land somewhere sensible.
        panel.directoryURL = inspection.fileURL.deletingLastPathComponent()

        let handle: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            app.exportInspected(into: url)
        }
        // A sheet on the window it belongs to when there is one; the panel's
        // own modal session when there is not.
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
        #else
        app.isChoosingExportDestination = true
        #endif
    }

    #if !os(macOS)
    private var exportDestinationBinding: Binding<Bool> {
        Binding(get: { app.isChoosingExportDestination },
                set: { app.isChoosingExportDestination = $0 })
    }
    #endif

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
            Button { chooseExportDestination(for: inspection) } label: {
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

/// One chart, with what it plots folded away until asked for.
///
/// Its own view rather than a closure inside `InspectorView`: a chart carries
/// four nested collections, and inlining that is what turns a card into an
/// expression the type checker gives up on.
private struct ChartRow: View {
    let chart: ChartInspection

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 4) {
                if !chart.categories.isEmpty {
                    row("Categories: " + chart.categories.joined(separator: ", "))
                }
                ForEach(chart.series) { series in
                    row("\(series.name): " + Self.describe(series.values))
                }
                if let problem = chart.replacementProblem {
                    Label(problem, systemImage: "pencil.slash")
                        .font(.caption).foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(chart.title).font(.callout).lineLimit(1)
                Spacer(minLength: 12)
                Text("slide \(chart.slideIndex + 1)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                Image(systemName: chart.canReplaceData ? "square.and.pencil" : "pencil.slash")
                    .font(.caption)
                    .foregroundStyle(chart.canReplaceData ? AnyShapeStyle(.secondary)
                                                          : AnyShapeStyle(.orange))
            }
        }
    }

    private func row(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func describe(_ values: [Double?]) -> String {
        let parts: [String] = values.map { value in
            guard let value else { return "—" }
            return String(format: "%g", value)
        }
        return parts.joined(separator: ", ")
    }
}
