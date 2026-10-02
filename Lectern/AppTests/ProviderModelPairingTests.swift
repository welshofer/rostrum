import Testing
import Foundation
@testable import Lectern
@testable import LecternCore

/// The provider and the model have to agree on disk, not just in memory.
///
/// Cross-model review found that `selectProvider` fixed the model for the new
/// provider but never persisted it, and that init fell back to the property's
/// default when the stored model did not match. Together those sent one
/// vendor's model name to another vendor's API after a relaunch, and left the
/// Model picker with no matching tag.
@MainActor
@Suite struct ProviderModelPairingTests {

    @Test func selectingAProviderPersistsItsModelToo() throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = context.app

        app.selectProvider(.openAI)
        let persisted = context.defaults.string(forKey: "model")

        #expect(persisted == app.model)
        #expect(AppState.defaultModels(for: .openAI).contains(app.model))
        #expect(context.makeApp().model == app.model)
    }

    @Test func aModelNeverBelongsToTheWrongProvider() throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = context.app
        for id in ProviderID.allCases where ProviderFactory.isWired(id) {
            app.selectProvider(id)
            #expect(AppState.defaultModels(for: id).contains(app.model),
                    "\(app.model) is not a \(id.rawValue) model")
        }
    }
}
