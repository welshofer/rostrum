import Foundation
import Testing
import LecternCore
@testable import Lectern

@MainActor
@Suite struct AppStateIsolationTests {
    @Test func preferencesRemainInTheirInjectedDomainAcrossRelaunch() throws {
        let left = try AppStateTestContext(), right = try AppStateTestContext()
        defer { left.remove(); right.remove() }
        let keys = ["providerID", "model", "imageProviderID", "favoriteStyles", "recentStyles", "useSmartArt"]
        let standardBefore = snapshot(UserDefaults.standard, keys: keys)
        let rightBefore = snapshot(right.defaults, keys: keys)
        let app = left.app
        app.selectProvider(.openAI)
        app.setModel("gpt-5.2-mini")
        app.selectImageProvider(.openAI)
        app.selectStyle("first")
        app.selectStyle("second")
        app.toggleFavorite("second")
        app.setUseSmartArt(true)

        #expect(left.defaults.string(forKey: "providerID") == "openAI")
        #expect(left.defaults.string(forKey: "model") == "gpt-5.2-mini")
        #expect(left.defaults.stringArray(forKey: "recentStyles") == ["second", "first"])
        #expect(left.defaults.stringArray(forKey: "favoriteStyles") == ["second"])
        #expect(left.defaults.bool(forKey: "useSmartArt"))
        let relaunched = left.makeApp()
        #expect(relaunched.providerID == .openAI && relaunched.model == "gpt-5.2-mini")
        #expect(relaunched.imageProviderID == .openAI)
        #expect(relaunched.recents == ["second", "first"] && relaunched.favorites == ["second"])
        #expect(relaunched.useSmartArt)
        #expect(!app.hasKey && !app.hasImageKey && !relaunched.hasKey && !relaunched.hasImageKey)
        #expect(snapshot(right.defaults, keys: keys) == rightBefore)
        #expect(snapshot(UserDefaults.standard, keys: keys) == standardBefore)
    }

    @Test func libraryRefreshRenameAndDeleteUseOnlyTheInjectedLibrary() throws {
        let left = try AppStateTestContext(), right = try AppStateTestContext()
        defer { left.remove(); right.remove() }
        let leftURL = left.libraryDirectory.appendingPathComponent("left.pptx")
        let rightURL = right.libraryDirectory.appendingPathComponent("right.pptx")
        try Data("left fixture".utf8).write(to: leftURL)
        try Data("right fixture".utf8).write(to: rightURL)
        left.app.refreshLibrary()
        right.app.refreshLibrary()
        #expect(left.app.library.map(\.url.standardizedFileURL) == [leftURL.standardizedFileURL])
        #expect(right.app.library.map(\.url.standardizedFileURL) == [rightURL.standardizedFileURL])
        let deck = try #require(left.app.library.first)
        left.app.renameInLibrary(deck, to: "renamed")
        #expect(left.app.renameProblem == nil)
        let renamed = try #require(left.app.library.first)
        #expect(renamed.url.standardizedFileURL == left.libraryDirectory.appendingPathComponent("renamed.pptx").standardizedFileURL)
        #expect(!FileManager.default.fileExists(atPath: leftURL.path))
        left.app.deleteFromLibrary(renamed)
        #expect(left.app.library.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: renamed.url.path))
        #expect(try Data(contentsOf: rightURL) == Data("right fixture".utf8))
        #expect(right.app.library.map(\.url.standardizedFileURL) == [rightURL.standardizedFileURL])
    }

    private func snapshot(_ defaults: UserDefaults, keys: [String]) -> NSDictionary {
        var values: [String: Any] = [:]
        for key in keys { values[key] = defaults.object(forKey: key) ?? NSNull() }
        return values as NSDictionary
    }
}
