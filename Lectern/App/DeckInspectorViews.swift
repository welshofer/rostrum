import SwiftUI
#if os(macOS)
import AppKit
#else
import QuickLook
#endif
import LecternCore

struct InspectingDeckView: View {
    let fileName: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text("Opening \(fileName)")
                .font(.title3.weight(.semibold))
                .lineLimit(1).truncationMode(.middle)
            Text("Reading the package, layouts, media, charts, notes, and comments.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InspectionFailedView: View {
    @Environment(AppState.self) private var app
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.xmark")
                .font(.system(size: 44)).foregroundStyle(.orange)
            Text("This deck did not open")
                .font(.title2.weight(.semibold))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 480)
            HStack(spacing: 12) {
                Button("Choose Another…") { app.isImportingDeck = true }
                    .buttonStyle(.glassProminent)
                Button("Done") { app.closeInspection() }
                    .buttonStyle(.glass)
            }
            .controlSize(.large)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DeckInspectorView: View {
    @Environment(AppState.self) private var app
    let inspection: DeckInspection
    @State private var selectedSlide = 0
    @State private var showDeckDetails = false
    #if os(iOS)
    @State private var previewURL: URL?
    #endif

    init(inspection: DeckInspection) {
        self.inspection = inspection
        _selectedSlide = State(initialValue: inspection.slides.first?.index ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            GeometryReader { proxy in
                if proxy.size.width >= 900 {
                    HStack(spacing: 0) {
                        contactSheet
                        Divider()
                        details
                            .frame(width: 340)
                    }
                } else {
                    contactSheet
                        .sheet(isPresented: $showDeckDetails) {
                            NavigationStack {
                                details
                                    .toolbar {
                                        ToolbarItem(placement: .confirmationAction) {
                                            Button("Done") { showDeckDetails = false }
                                        }
                                    }
                            }
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .quickLookPreview($previewURL)
        #endif
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(inspection.fileName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1).truncationMode(.middle)
                    .accessibilityIdentifier("deck-inspector-title")
                Text("\(inspection.slideCount) slides · \(inspection.documentKind) · \(size)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if !inspection.validationIssues.isEmpty {
                Label("\(inspection.validationIssues.count) issues",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            #if os(macOS)
            Button {
                NSWorkspace.shared.open(inspection.sourceURL)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.glassProminent)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([inspection.sourceURL])
            } label: {
                Label("Reveal", systemImage: "folder")
            }
            .buttonStyle(.glass)
            #else
            Button { previewURL = inspection.sourceURL } label: {
                Label("Preview", systemImage: "eye")
            }
            .buttonStyle(.glassProminent)
            ShareLink(item: inspection.sourceURL) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.glass)
            #endif
            Button("Done") { app.closeInspection() }
                .buttonStyle(.glass)
        }
        .controlSize(.large)
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var contactSheet: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 230), spacing: 14)],
                spacing: 14
            ) {
                ForEach(inspection.slides) { slide in
                    Button {
                        selectedSlide = slide.index
                        showDeckDetails = true
                    } label: {
                        InspectionSlideTile(
                            slide: slide,
                            preview: app.inspectedPreviews[slide.index],
                            selected: selectedSlide == slide.index
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("deck-inspector-slide-\(slide.index)")
                    .accessibilityLabel("Inspect slide \(slide.index + 1), \(slide.headline)")
                    .task { await app.loadInspectionPreview(at: slide.index) }
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var details: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let slide = inspection.slides.first(where: { $0.index == selectedSlide }) {
                    slideDetails(slide)
                }
                Divider()
                deckDetails
            }
            .padding(20)
        }
        .navigationTitle("Deck details")
    }

    @ViewBuilder
    private func slideDetails(_ slide: SlideInspection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Slide \(slide.index + 1)").font(.caption).foregroundStyle(.secondary)
            Text(slide.headline).font(.title3.weight(.semibold))
            Text(slide.layoutName).font(.caption).foregroundStyle(.secondary)
        }

        if !slide.shapeCounts.isEmpty {
            InspectorGroup(title: "Objects") {
                ForEach(slide.shapeCounts.keys.sorted(), id: \.self) { kind in
                    InspectorRow(kind, value: "\(slide.shapeCounts[kind] ?? 0)")
                }
            }
        }
        if !slide.notes.isEmpty {
            InspectorGroup(title: "Speaker notes") {
                Text(slide.notes).font(.callout).textSelection(.enabled)
            }
        }
        if !slide.comments.isEmpty {
            InspectorGroup(title: "Comments") {
                ForEach(slide.comments) { comment in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(comment.author).font(.caption.weight(.semibold))
                        Text(comment.text).font(.callout)
                        if comment.replyCount > 0 || comment.resolved {
                            Text([
                                comment.replyCount > 0 ? "\(comment.replyCount) replies" : nil,
                                comment.resolved ? "resolved" : nil,
                            ].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        if !slide.chartIndices.isEmpty {
            InspectorGroup(title: "Charts") {
                ForEach(slide.chartIndices, id: \.self) { index in
                    if inspection.charts.indices.contains(index) {
                        let chart = inspection.charts[index]
                        VStack(alignment: .leading, spacing: 3) {
                            Text(chart.title).font(.callout.weight(.semibold))
                            Text(chart.plotTypes.joined(separator: " + "))
                                .font(.caption).foregroundStyle(.secondary)
                            Text("\(chart.categories.count) categories · \(chart.series.count) series")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var deckDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            InspectorGroup(title: "Document") {
                if let title = inspection.properties.title { InspectorRow("Title", value: title) }
                if let author = inspection.properties.author { InspectorRow("Author", value: author) }
                if let company = inspection.properties.company { InspectorRow("Company", value: company) }
                if let application = inspection.properties.application {
                    InspectorRow("Created by", value: application)
                }
                InspectorRow("Masters", value: "\(inspection.masters.count)")
                InspectorRow("Layouts", value: "\(inspection.masters.reduce(0) { $0 + $1.layoutNames.count })")
                InspectorRow("Sections", value: "\(inspection.sections.count)")
                InspectorRow("Charts", value: "\(inspection.charts.count)")
            }

            let fonts = Array(Set(inspection.themeFonts + inspection.explicitFonts)).sorted()
            if !fonts.isEmpty {
                InspectorGroup(title: "Fonts") {
                    ForEach(fonts, id: \.self) { Text($0).font(.callout) }
                    if !inspection.embeddedFonts.isEmpty {
                        Text("\(inspection.embeddedFonts.count) embedded and registered")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if !inspection.validationIssues.isEmpty {
                InspectorGroup(title: "Validation") {
                    ForEach(inspection.validationIssues, id: \.self) {
                        Label($0, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var size: String {
        ByteCountFormatter.string(fromByteCount: Int64(inspection.byteCount), countStyle: .file)
    }
}

private struct InspectionSlideTile: View {
    let slide: SlideInspection
    let preview: String?
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let preview {
                    SlidePreview(svg: preview)
                } else {
                    ZStack {
                        Rectangle().fill(.quaternary)
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(alignment: .firstTextBaseline) {
                Text("\(slide.index + 1)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Text(slide.headline)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? Color.accentColor : .primary.opacity(0.1),
                              lineWidth: selected ? 2 : 1))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Slide \(slide.index + 1), \(slide.headline)")
    }
}

private struct InspectorGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InspectorRow: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .font(.callout)
    }
}
