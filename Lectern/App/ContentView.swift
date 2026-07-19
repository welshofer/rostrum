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
            Section {
                Button("Generate") { app.generate() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)          // .glass on macOS 26
                    .disabled(!app.canGenerate)
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

struct SettingsView: View {
    var body: some View {
        Form {
            Text("Providers (keys → Keychain), generation defaults, pricing, and about "
                 + "live here — the M3/M5 finish.")
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 440, height: 220)
    }
}
