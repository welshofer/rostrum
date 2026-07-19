import SwiftUI
import AppKit
import LecternCore

// The Compose → Generating → Result state machine (§5). Standard SwiftUI so the
// scaffold compiles today; the Liquid Glass treatment, History sidebar (SwiftData),
// PDF drop zone, and Style picker are the M4–M5 finish.
struct ContentView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        NavigationSplitView {
            List {
                Section("History") {
                    Text("Past decks appear here.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Lectern")
        } detail: {
            switch app.phase {
            case .compose: ComposeView()
            case .generating: GeneratingView()
            case .result(let result): ResultView(result: result)
            case .failed(let message): FailedView(message: message)
            }
        }
        .task { await app.loadStyles() }
    }
}

struct ComposeView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        Form {
            Section("Prompt") {
                TextEditor(text: $app.prompt)
                    .frame(minHeight: 110)
                    .overlay(alignment: .topLeading) {
                        if app.prompt.isEmpty {
                            Text("What is this presentation about, and what should it accomplish?")
                                .foregroundStyle(.tertiary).padding(6).allowsHitTesting(false)
                        }
                    }
            }
            Section("Audience") {
                TextField("Executives, engineers, customers…", text: $app.audience)
            }
            Section("Goal") {
                Picker("Goal", selection: $app.goal) {
                    ForEach(["inform", "persuade", "entertain", "inspire"], id: \.self) {
                        Text($0.capitalized).tag($0)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Length") {
                Stepper("\(app.slideCount) slides  ·  ≈ \(Int(Double(app.slideCount) * 1.5)) min",
                        value: $app.slideCount, in: 3...40)
            }
            Section {
                Toggle("Speaker notes", isOn: $app.includeNotes)
            }
            if !app.styles.isEmpty {
                Section("Style") {
                    Picker("Style", selection: $app.selectedStyleSlug) {
                        ForEach(app.styles) { style in
                            Text(style.name).tag(style.slug as String?)
                        }
                    }
                }
            }
            Section {
                Button("Generate") { app.generate() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)          // .glass on macOS 26
                    .disabled(!app.canGenerate)
                Label(app.hasKeyForSelectedProvider
                      ? "Using \(app.providerID.label)" + (app.costEstimate.map { " · ~\($0) est." } ?? "")
                      : "Using the Mock provider — add a key in Settings for live generation.",
                      systemImage: app.hasKeyForSelectedProvider ? "bolt.fill" : "cpu")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Compose")
    }
}

struct GeneratingView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(app.stage).font(.headline)
            if app.total > 0 {
                Text("\(app.drafted) of \(app.total) slides").foregroundStyle(.secondary)
            }
            Button("Cancel", role: .cancel) { app.cancel() }
        }
        .padding(40)
    }
}

struct ResultView: View {
    @Environment(AppState.self) private var app
    let result: DeckResult

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.richtext").font(.system(size: 44)).foregroundStyle(.tint)
            Text(result.url.lastPathComponent).font(.headline)
            Text("\(result.slideCount) slides").foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([result.url]) }
                Button("Open") { NSWorkspace.shared.open(result.url) }
                Button("New") { app.reset() }
            }
            if !result.warnings.isEmpty {
                DisclosureGroup("\(result.warnings.count) validation warning(s)") {
                    ForEach(result.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: 420)
            }
        }
        .padding(40)
    }
}

struct FailedView: View {
    @Environment(AppState.self) private var app
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundStyle(.orange)
            Text(message).multilineTextAlignment(.center)
            Button("Back to Compose") { app.reset() }
        }
        .padding(40)
    }
}

