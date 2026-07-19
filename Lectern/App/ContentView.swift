import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LecternCore

struct ContentView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        // No sidebar — there's no deck History to show, so a single pane is honest.
        Group {
            switch app.phase {
            case .compose: ComposeView()
            case .generating: GeneratingView()
            case .result(let r): ResultView(result: r)
            case .failed(let m): FailedView(message: m)
            }
        }
        .frame(minWidth: 640, minHeight: 560)
        .task { await app.loadStyles() }
    }
}

// MARK: - A reusable glass card

struct Card<Content: View>: View {
    var title: String?
    var systemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Label(title, systemImage: systemImage ?? "circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Compose

struct ComposeView: View {
    @Environment(AppState.self) private var app
    @State private var showStyles = false
    @State private var importing = false
    @State private var dropTargeted = false

    var body: some View {
        @Bindable var app = app
        ScrollView {
            VStack(spacing: 16) {
                Card(title: "PROMPT", systemImage: "text.alignleft") {
                    TextEditor(text: $app.prompt)
                        .font(.body).scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if app.prompt.isEmpty {
                                Text("What is this presentation about, and what should it accomplish?")
                                    .foregroundStyle(.tertiary).allowsHitTesting(false).padding(.top, 2)
                            }
                        }
                }

                HStack(spacing: 16) {
                    Card(title: "AUDIENCE", systemImage: "person.2") {
                        TextField("Executives, engineers…", text: $app.audience).textFieldStyle(.plain)
                    }
                    Card(title: "GOAL", systemImage: "target") {
                        Picker("", selection: $app.goal) {
                            ForEach(["inform", "persuade", "entertain", "inspire"], id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden()
                    }
                }

                Card(title: "LENGTH", systemImage: "rectangle.stack") {
                    HStack {
                        Stepper("\(app.slideCount) slides  ·  ≈ \(Int(Double(app.slideCount) * 1.5)) min",
                                value: $app.slideCount, in: 3...40)
                        Spacer()
                        Toggle("Speaker notes", isOn: $app.includeNotes).toggleStyle(.switch)
                    }
                }

                Card(title: "STYLE", systemImage: "paintpalette") {
                    StyleButton(style: app.selectedStyle) { showStyles = true }
                }

                groundingCard
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) { generateBar }
        .sheet(isPresented: $showStyles) { StylePickerSheet().environment(app) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in
            if let url = try? result.get() { Task { await app.attachPDF(url) } }
        }
    }

    @ViewBuilder private var groundingCard: some View {
        Card(title: "GROUND ON A PDF (OPTIONAL)", systemImage: "doc.text.magnifyingglass") {
            if app.groundingLoading {
                HStack(spacing: 10) { ProgressView().controlSize(.small); Text("Reading PDF…").foregroundStyle(.secondary) }
            } else if let g = app.grounding {
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill").font(.title2).foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.name).font(.headline).lineLimit(1)
                        Text("\(g.pageCount) pages · grounding on\(g.truncated ? " (truncated)" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { app.clearPDF() } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.down.doc").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Drop a PDF here to ground the deck on real facts")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Choose PDF…") { importing = true }.buttonStyle(.glass)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 22)
                .background(dropTargeted ? AnyShapeStyle(Color.accentColor.opacity(0.12)) : AnyShapeStyle(.clear),
                            in: .rect(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .foregroundStyle(dropTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
                )
                if let err = app.groundingError {
                    Label(err, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else { return false }
            Task { await app.attachPDF(url) }
            return true
        } isTargeted: { dropTargeted = $0 }
    }

    private var generateBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                if !app.hasKey {
                    Label("Add an API key in Settings (⌘,) to generate", systemImage: "key")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("\(app.slideCount) slides · \(app.providerID.label)"
                         + (app.costEstimate.map { " · ~\($0) est." } ?? ""))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { app.generate() } label: {
                Label("Generate", systemImage: "sparkles").font(.body.weight(.semibold)).padding(.horizontal, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!app.canGenerate)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.bar)
    }
}

// MARK: - Generating

struct GeneratingView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text(app.stage).font(.title3.weight(.semibold)).contentTransition(.opacity)
            if app.total > 0 {
                ProgressView(value: Double(app.drafted), total: Double(app.total))
                    .frame(maxWidth: 280)
                Text("\(app.drafted) of \(app.total) slides").font(.callout).foregroundStyle(.secondary)
            }
            Button("Cancel", role: .cancel) { app.cancel() }.buttonStyle(.glass)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Result

struct ResultView: View {
    @Environment(AppState.self) private var app
    let result: DeckResult
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 52)).foregroundStyle(.green)
            Text(result.url.lastPathComponent).font(.title3.weight(.semibold))
            Text("\(result.slideCount) slides · written by Rostrum").foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button { NSWorkspace.shared.open(result.url) } label: { Label("Open", systemImage: "arrow.up.forward.app") }
                    .buttonStyle(.glassProminent)
                Button { NSWorkspace.shared.activateFileViewerSelecting([result.url]) } label: { Label("Reveal", systemImage: "folder") }
                    .buttonStyle(.glass)
                Button("New") { app.reset() }.buttonStyle(.glass)
            }
            .controlSize(.large)
            if !result.warnings.isEmpty {
                DisclosureGroup("\(result.warnings.count) validation warning(s)") {
                    ForEach(result.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: 420)
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Failed

struct FailedView: View {
    @Environment(AppState.self) private var app
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundStyle(.orange)
            Text(message).font(.title3).multilineTextAlignment(.center).frame(maxWidth: 420)
            Button("Back to Compose") { app.reset() }.buttonStyle(.glassProminent).controlSize(.large)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
