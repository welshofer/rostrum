import SwiftUI
import LecternCore

extension ProviderID {
    /// Human label for menus and captions (`.capitalized` mangles "openAI").
    var label: String {
        switch self {
        case .anthropic: "Anthropic"
        case .openAI: "OpenAI"
        case .gemini: "Gemini"
        case .custom: "Custom"
        }
    }

    /// Providers with a live implementation today (§7.2). The rest fall back to
    /// the Mock, and the UI says so rather than pretending.
    var isWiredLive: Bool { self == .anthropic }
}

/// Providers, keys, and the model — the M3/M5 Settings scene. Keys go straight to
/// the Keychain (invariant I1); the SecureField is write-only (a stored key is
/// never read back into it), so a secret never round-trips through the UI.
struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var keyInput = ""

    var body: some View {
        @Bindable var app = app
        Form {
            Section("Provider") {
                Picker("Provider", selection: Binding(
                    get: { app.providerID },
                    set: { app.selectProvider($0); keyInput = "" }
                )) {
                    ForEach(ProviderID.allCases, id: \.self) { id in
                        Text(id.isWiredLive ? id.label : "\(id.label) (soon)").tag(id)
                    }
                }
                TextField("Model", text: Binding(get: { app.model }, set: { app.setModel($0) }))
                    .disabled(!app.providerID.isWiredLive)
            }

            Section("API key") {
                SecureField("Paste your \(app.providerID.label) key", text: $keyInput)
                    .disabled(!app.providerID.isWiredLive)
                    .onSubmit(saveKey)
                HStack {
                    Button("Save to Keychain", action: saveKey)
                        .disabled(!app.providerID.isWiredLive
                                  || keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if app.hasKeyForSelectedProvider {
                        Button("Remove", role: .destructive) { app.clearKey() }
                    }
                    Spacer()
                    statusLabel
                }
            }

            Section {
                Label(caption, systemImage: app.hasKeyForSelectedProvider ? "bolt.fill" : "cpu")
                    .font(.callout)
                    .foregroundStyle(app.hasKeyForSelectedProvider ? .primary : .secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 480, height: 340)
    }

    private func saveKey() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        app.saveKey(trimmed)
        keyInput = ""
    }

    @ViewBuilder private var statusLabel: some View {
        if app.hasKeyForSelectedProvider {
            Label("Key stored", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        } else {
            Label("Mock", systemImage: "circle.dashed").foregroundStyle(.secondary)
        }
    }

    private var caption: String {
        if !app.providerID.isWiredLive {
            return "\(app.providerID.label) isn't wired up yet — Lectern uses the built-in Mock provider."
        }
        return app.hasKeyForSelectedProvider
            ? "Live \(app.providerID.label) generation is on."
            : "No key stored — Lectern uses the built-in Mock provider, so it works fully offline."
    }
}
