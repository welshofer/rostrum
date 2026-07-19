import SwiftUI
import LecternCore

/// Providers, keys, and model — the Settings scene (§10 / §294). The key goes
/// straight to the Keychain (I1); the SecureField is write-only, so a stored key
/// never round-trips through the UI. Validate confirms the key and populates the
/// live model list.
struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var keyInput = ""
    @State private var imageKeyInput = ""

    private var trimmed: String { keyInput.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var imageTrimmed: String { imageKeyInput.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        @Bindable var app = app
        Form {
            Section("Provider") {
                Picker("Provider", selection: Binding(
                    get: { app.providerID },
                    set: { app.selectProvider($0); keyInput = "" }
                )) {
                    ForEach(ProviderID.allCases, id: \.self) { id in
                        Text(ProviderFactory.isWired(id) ? id.label : "\(id.label) (soon)").tag(id)
                    }
                }
                Picker("Model", selection: Binding(get: { app.model }, set: { app.setModel($0) })) {
                    ForEach(app.modelOptions, id: \.self) { Text(modelLabel($0)).tag($0) }
                }
                .disabled(app.modelOptions.isEmpty)
            }

            Section("API key") {
                // The field is write-only (I1: a stored key never round-trips
                // through the UI), so after a relaunch it is always empty. The
                // prompt must carry the stored-state truth — a bare "Paste your
                // key" placeholder reads as "no key saved" even when one is.
                SecureField(text: $keyInput, prompt: Text(
                    app.hasKey ? "••••••••••••••••••••  saved — paste to replace"
                               : "Paste your \(app.providerID.label) key")) { EmptyView() }
                    .disabled(!ProviderFactory.isWired(app.providerID))
                    .onSubmit(save)
                HStack(spacing: 10) {
                    Button("Save", action: save).disabled(trimmed.isEmpty)
                    Button("Validate") { Task { await app.validateKey() } }.disabled(!app.hasKey)
                    if app.hasKey { Button("Remove", role: .destructive) { app.clearKey() } }
                    Spacer()
                    statusView
                }
            }

            Section("Images (optional)") {
                Picker("Image provider", selection: Binding(
                    get: { app.imageProviderID },
                    set: { app.selectImageProvider($0); imageKeyInput = "" }
                )) {
                    ForEach(ImageProviderID.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                SecureField(text: $imageKeyInput, prompt: Text(
                    app.hasImageKey ? "••••••••••••••••••••  saved — paste to replace"
                                    : "Paste your \(app.imageProviderID.label) key")) { EmptyView() }
                    .onSubmit(saveImageKey)
                HStack(spacing: 10) {
                    Button("Save", action: saveImageKey).disabled(imageTrimmed.isEmpty)
                    if app.hasImageKey { Button("Remove", role: .destructive) { app.clearImageKey() } }
                    Spacer()
                    if app.hasImageKey {
                        Label("On", systemImage: "photo.fill").foregroundStyle(.green)
                    } else {
                        Label("Off", systemImage: "photo").foregroundStyle(.tertiary)
                    }
                }
                Text(app.hasImageKey
                     ? "Slides the model marks for a visual get an on-brand image in the selected style."
                     : "Optional — add a key and Lectern illustrates suitable slides in your chosen design's style.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Diagrams") {
                Toggle("Use SmartArt", isOn: Binding(
                    get: { app.useSmartArt },
                    set: { app.setUseSmartArt($0) }))
                Text(app.useSmartArt
                     ? "Process, cycle, and layer diagrams render as native, editable PowerPoint SmartArt."
                     : "Diagrams render as styled shapes (default). Turn on for native, editable SmartArt.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Label(footerText, systemImage: app.hasKey ? "bolt.fill" : "exclamationmark.circle")
                    .font(.callout)
                    .foregroundStyle(app.hasKey ? .primary : .secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 620)
    }

    private func saveImageKey() {
        guard !imageTrimmed.isEmpty else { return }
        app.saveImageKey(imageTrimmed)
        imageKeyInput = ""
    }

    @ViewBuilder private var statusView: some View {
        switch app.keyStatus {
        case .validating:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…").foregroundStyle(.secondary) }
        case .valid(let count):
            Label("Valid · \(count) models", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        case .invalid(let message):
            Label(message, systemImage: "xmark.seal.fill").foregroundStyle(.red).lineLimit(1).help(message)
        case .unknown:
            if app.hasKey {
                Label("Key saved in Keychain", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Label("No key", systemImage: "key").foregroundStyle(.tertiary)
            }
        }
    }

    private var footerText: String {
        if !ProviderFactory.isWired(app.providerID) {
            return "\(app.providerID.label) isn't wired up yet — choose Anthropic."
        }
        return app.hasKey
            ? "Live \(app.providerID.label) generation is on. Keys are stored only in your Keychain."
            : "Add a key to generate — Lectern never runs on fake data."
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        app.saveKey(trimmed)
        keyInput = ""
        Task { await app.validateKey() }        // immediate feedback that the key works
    }
}
