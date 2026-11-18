import Foundation
import Testing
import LecternCore
@testable import Lectern

@Suite @MainActor struct KeyxAppTests {
    @Test func outputChoicePersistsWithoutChangingModelOrCredentialSettings() throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let beforeModel = context.app.model
        let beforeProvider = context.app.providerID
        context.app.setOutputFormat(.keynoteInterchange)
        #expect(context.app.outputFormat == .keynoteInterchange)
        #expect(AppState(skipKeychain: true, defaults: context.defaults).outputFormat == .keynoteInterchange)
        #expect(context.app.model == beforeModel && context.app.providerID == beforeProvider)
        #expect(ContentView.deckExtensions.contains("keyx"))
        #expect(ContentView.deckTypes.contains { $0.preferredFilenameExtension == "keyx" })
        context.app.setOutputFormat(.powerPoint)
        #expect(context.app.outputFormat == .powerPoint)
    }

    @Test func nativeInterchangeInspectionAndExportReachAppState() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let deck = DeckIR(meta: Meta(title: "App interchange"), slides: [
            IRSlide(id: "one", layout: "bullets", title: "App interchange",
                    body: Body(bullets: [Bullet(text: "Native local content")]), notes: "Presenter text")
        ])
        let result = try await DeckRenderer().render(deck, designURL: nil, notesEnabled: true,
            into: context.libraryDirectory, outputFormat: .keynoteInterchange)
        await context.app.inspect(deckAt: result.url).value
        #expect(context.app.phase == .inspected)
        #expect(context.app.inspection?.format == .keynoteInterchange)
        #expect(context.app.inspection?.slides.first?.notes == ["Presenter text"])
        #expect(context.app.inspection?.previewRecords.count == 1)
        if let work = context.app.exportInspected(into: context.libraryDirectory.appendingPathComponent("export")) {
            await work.value
        } else { Issue.record("Export did not start") }
        #expect(context.app.exportedDirectory != nil)
        #expect(context.app.exportProblem == nil)
        await context.app.refreshLibraryAndWait()
        #expect(context.app.library.contains { $0.format == .keynoteInterchange })
    }
}
