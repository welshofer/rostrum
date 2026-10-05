import SwiftUI
import LecternCore

/// OpenAI generation choices. Stored keys never round-trip through the UI.
struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var keyInput = ""
    @State private var imageKeyInput = ""

    private var trimmed: String { keyInput.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var imageTrimmed: String { imageKeyInput.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        #if os(iOS)
        // Presented as a sheet (no Settings scene on iOS) — needs its own
        // navigation bar for the title and an explicit way out.
        NavigationStack {
            form
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        #else
        form
            .frame(width: 520, height: 740)
        #endif
    }

    private var form: some View {
        Form {
            if app.isTestSession {
                Section {
                    Label(AppState.testSessionAdvice, systemImage: "testtube.2")
                }
            }
            Section("Text generation · OpenAI") {
                Picker("Model strength", selection: Binding(
                    get: { app.textStrength }, set: { app.setModel($0.modelID) })) {
                    ForEach(TextStrength.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                Picker("Reasoning effort", selection: Binding(
                    get: { app.reasoningEffort }, set: { app.setReasoningEffort($0) })) {
                    ForEach(app.textStrength.efforts, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                Text("Higher effort gives the model more time to reason and can increase cost. Applies to drafting, repair, and polish.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("OpenAI API key") {
                // The field is write-only (I1: a stored key never round-trips
                // through the UI), so after a relaunch it is always empty. The
                // prompt must carry the stored-state truth — a bare "Paste your
                // key" placeholder reads as "no key saved" even when one is.
                SecureField(text: $keyInput, prompt: Text(
                    app.keyStorageUnavailable ? "Keychain unavailable — retry access"
                    : app.hasKey ? "••••••••••••••••••••  saved — paste to replace"
                    : "Paste your \(app.providerID.label) key")) { EmptyView() }
                    .disabled(!ProviderFactory.isWired(app.providerID))
                    .onSubmit(save)
                HStack(spacing: 10) {
                    Button("Save", action: save).disabled(trimmed.isEmpty)
                    Button("Validate") { Task { await app.validateKey() } }.disabled(!app.hasKey)
                    if app.hasKey { Button("Remove", role: .destructive) { app.clearKey() } }
                    if app.keyStorageUnavailable {
                        Button("Retry Keychain") { app.refreshKeyAvailability() }
                    }
                    Spacer()
                    statusView
                }
            }
            .disabled(app.isTestSession)

            Section("Images (optional)") {
                Picker("Image model", selection: Binding(
                    get: { app.imageModel }, set: { app.setImageModel($0) })) {
                    ForEach(ImageModel.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                Picker("Image quality", selection: Binding(
                    get: { app.imageQuality }, set: { app.setImageQuality($0) })) {
                    ForEach(ImageQuality.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                SecureField(text: $imageKeyInput, prompt: Text(
                    app.imageKeyStorageUnavailable ? "Keychain unavailable — retry access"
                    : app.hasImageKey ? "••••••••••••••••••••  saved — paste to replace"
                    : "Paste your \(app.imageProviderID.label) key")) { EmptyView() }
                    .onSubmit(saveImageKey)
                HStack(spacing: 10) {
                    Button("Save", action: saveImageKey).disabled(imageTrimmed.isEmpty)
                    Button("Validate") { Task { await app.validateImageKey() } }
                        .disabled(!app.hasImageKey || app.imageKeyStatus == .validating)
                    if app.hasImageKey { Button("Remove", role: .destructive) { app.clearImageKey() } }
                    if app.imageKeyStorageUnavailable {
                        Button("Retry Keychain") { app.refreshKeyAvailability() }
                    }
                    Spacer()
                    imageStatusView
                }
                Text(imageFooterText)
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(app.isTestSession)

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
        .task(id: app.imageModel) {
            if !app.isTestSession && app.hasImageKey && !app.imageKeyStorageUnavailable {
                await app.validateImageKey()
            }
        }
    }

    private func saveImageKey() {
        guard !imageTrimmed.isEmpty else { return }
        guard app.saveImageKey(imageTrimmed) else { return }
        imageKeyInput = ""
        Task { await app.validateImageKey() }
    }

    @ViewBuilder private var imageStatusView: some View {
        switch app.imageKeyStatus {
        case .validating:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            }
        case .valid:
            Label("Valid", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        case .invalid(let message):
            Label(message, systemImage: "xmark.seal.fill")
                .foregroundStyle(.red).lineLimit(1).help(message)
        case .unknown:
            if app.hasImageKey {
                Label("Saved — not checked", systemImage: "key.fill").foregroundStyle(.secondary)
            } else {
                Label("Off", systemImage: "photo").foregroundStyle(.tertiary)
            }
        }
    }

    private var imageFooterText: String {
        if app.isTestSession { return AppState.testSessionAdvice }
        if app.imageKeyStorageUnavailable { return AppState.unreadableKeyAdvice }
        switch app.imageKeyStatus {
        case .valid:
            return "Slides the model marks for a visual get an on-brand image in the selected style."
        case .validating:
            return "Checking that the key can access \(app.imageModel.label)…"
        case .invalid:
            return "Fix or remove this key before generating; Lectern won't silently omit failed images."
        case .unknown:
            return app.hasImageKey
                ? "The key is saved but has not been accepted by the provider yet."
                : "Optional — save an OpenAI key here to illustrate suitable slides. You can use the same key as text generation. Higher quality may take longer."
        }
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
        if app.isTestSession { return AppState.testSessionAdvice }
        if app.keyStorageUnavailable { return AppState.unreadableKeyAdvice }
        return app.hasKey
            ? "Live \(app.providerID.label) generation is on. Keys are stored only in your Keychain."
            : "Add a key to generate — Lectern never runs on fake data."
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        guard app.saveKey(trimmed) else { return }
        keyInput = ""
        Task { await app.validateKey() }        // immediate feedback that the key works
    }
}
