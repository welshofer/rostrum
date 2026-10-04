import Foundation
import LecternCore
@testable import Lectern

/// Every AppState test owns its preferences and filesystem paths. Startup and
/// migration tests exercise actual storage work there, with no login-keychain
/// lookup or user Documents access.
@MainActor
struct AppStateTestContext {
    let domain: String
    let defaults: UserDefaults
    let libraryDirectory: URL
    let app: AppState

    init() throws {
        domain = "Lectern.AppStateTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(domain, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        libraryDirectory = directory
        app = Self.makeApp(defaults: defaults, directory: directory)
    }

    func makeApp() -> AppState {
        Self.makeApp(defaults: defaults, directory: libraryDirectory)
    }

    private static func makeApp(defaults: UserDefaults, directory: URL) -> AppState {
        AppState(skipKeychain: true, defaults: defaults, libraryDirectory: directory, deletingDeck: { deck in
            // Delete only an owned fixture, without placing it in the real Trash.
            guard deck.url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else {
                throw CocoaError(.fileWriteNoPermission)
            }
            try FileManager.default.removeItem(at: deck.url)
        }, legacyDirectory: directory.appendingPathComponent("Legacy", isDirectory: true),
            diagnosticsDirectory: directory.appendingPathComponent("Diagnostics", isDirectory: true))
    }

    func remove() {
        defaults.removePersistentDomain(forName: domain)
        try? FileManager.default.removeItem(at: libraryDirectory)
    }
}
