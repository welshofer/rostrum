import Testing
import Foundation
@testable import Lectern
import LecternCore

@MainActor
@Suite struct ProviderModelPairingTests {
    @Test(arguments: ["claude-sonnet-5", "gpt-5.2", "unknown"])
    func oldPreferencesMigrateToOpenAI(model: String) {
        let name = "LecternMigrationTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        defer { d.removePersistentDomain(forName: name) }
        d.set("anthropic", forKey: "providerID")
        d.set("gemini", forKey: "imageProviderID")
        d.set(model, forKey: "model")
        let app = AppState(skipKeychain: true, defaults: d)
        #expect(app.providerID == .openAI)
        #expect(app.imageProviderID == .openAI)
        #expect(app.textStrength == .sol)
        #expect(app.reasoningEffort == .medium)
        #expect(app.imageModel == .flare)
        #expect(d.string(forKey: "providerID") == "openAI")
        #expect(d.string(forKey: "imageProviderID") == "openAI")
        #expect(d.string(forKey: "model") == TextStrength.sol.modelID)
    }

    @Test func selectionsPersistAndUnsupportedEffortIsCorrected() {
        let name = "LecternChoiceTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        defer { d.removePersistentDomain(forName: name) }
        let app = AppState(skipKeychain: true, defaults: d)
        for strength in TextStrength.allCases {
            app.setModel(strength.modelID)
            for effort in strength.efforts {
                app.setReasoningEffort(effort)
                let relaunched = AppState(skipKeychain: true, defaults: d)
                #expect(relaunched.textStrength == strength)
                #expect(relaunched.reasoningEffort == effort)
            }
        }
        app.setModel(TextStrength.luna.modelID)
        app.setReasoningEffort(.none)
        app.setModel(TextStrength.astra.modelID)
        #expect(app.reasoningEffort == .low)
        for model in ImageModel.allCases {
            for quality in ImageQuality.allCases {
                app.setImageModel(model)
                app.setImageQuality(quality)
                let relaunched = AppState(skipKeychain: true, defaults: d)
                #expect(relaunched.imageModel == model)
                #expect(relaunched.imageQuality == quality)
            }
        }
    }
}
