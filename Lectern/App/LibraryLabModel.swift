import Foundation
import Observation
import LecternCore

/// Keeps completed demonstrations while navigating to the deck inspector.
/// Every run owns a background task; retired tasks cannot replace its results.
@Observable @MainActor
final class LibraryLabModel {
    var selection: LibraryDemoID = .tableStructure
    var options = LibraryLabOptions()
    private(set) var results: [LibraryDemoID: LibraryLabResult] = [:]
    private(set) var savedDecks: [LibraryDemoID: URL] = [:]
    private(set) var saveFailures: [LibraryDemoID: String] = [:]
    private(set) var failures: [LibraryDemoID: String] = [:]
    private(set) var isRunning = false
    private(set) var activeID: LibraryDemoID?
    private(set) var completed = 0
    private(set) var total = 0
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var runs = RunGate()

    @discardableResult
    func run(_ ids: [LibraryDemoID], in parent: URL = AppState.diagnosticsDirectory().appendingPathComponent("Library Lab"),
             savingTo library: URL? = nil,
             onSaved: @escaping @MainActor @Sendable (URL) -> Void = { _ in }) -> Task<Void, Never> {
        run(ids, in: parent, savingTo: library, onSaved: onSaved) { id, options, parent in
            try LibraryLab.run(id, options: options, in: parent)
        }
    }

    @discardableResult
    func run(_ ids: [LibraryDemoID], in parent: URL, savingTo library: URL? = nil,
             onSaved: @escaping @MainActor @Sendable (URL) -> Void = { _ in },
             preparingSave: @escaping @Sendable (LibraryLabResult, URL) async throws -> DeckStorage.PreparedDeckCopy = { result, library in
                 let title = LibraryLab.catalog.first { $0.id == result.id }?.title ?? result.id.rawValue
                 return try DeckStorage.prepareDeckCopy(from: result.afterURL, title: title, into: library)
             },
             using operation: @escaping @Sendable (LibraryDemoID, LibraryLabOptions, URL) async throws -> LibraryLabResult) -> Task<Void, Never> {
        let run = runs.begin()
        task?.cancel()
        let options = options
        var seen = Set<LibraryDemoID>()
        let ids = ids.filter { seen.insert($0).inserted }
        completed = 0
        total = ids.count
        isRunning = !ids.isEmpty
        activeID = ids.first
        for id in ids { failures[id] = nil; results[id] = nil; savedDecks[id] = nil; saveFailures[id] = nil }
        let work = Task.detached(priority: .userInitiated) { [self] in
            for id in ids {
                if Task.isCancelled { break }
                await MainActor.run {
                    if runs.isCurrent(run) { activeID = id }
                }
                do {
                    let result = try await operation(id, options, parent)
                    try Task.checkCancellation()
                    var prepared: DeckStorage.PreparedDeckCopy?
                    var saveFailure: String?
                    if let library {
                        do { prepared = try await preparingSave(result, library) }
                        catch { saveFailure = error.localizedDescription }
                    }
                    // A cancelled or superseded run may finish copying, but it
                    // cannot promote the hidden file into the user's library.
                    let pending = prepared, problem = saveFailure
                    defer { pending?.discard() }
                    await MainActor.run {
                        guard runs.isCurrent(run), task?.isCancelled == false else { return }
                        results[id] = result
                        var savedURL: URL?
                        if let pending {
                            do {
                                let url = try pending.commit()
                                savedDecks[id] = url
                                savedURL = url
                            } catch { saveFailures[id] = error.localizedDescription }
                        } else if let problem { saveFailures[id] = problem }
                        completed += 1
                        if let savedURL { onSaved(savedURL) }
                    }
                } catch {
                    if Task.isCancelled || error is CancellationError { break }
                    let message = error.localizedDescription
                    await MainActor.run {
                        guard runs.isCurrent(run), task?.isCancelled == false else { return }
                        failures[id] = message
                        completed += 1
                    }
                }
            }
            await MainActor.run {
                guard runs.isCurrent(run) else { return }
                runs.abandon()
                task = nil
                activeID = nil
                isRunning = false
            }
        }
        task = work
        return work
    }

    func cancel() {
        runs.abandon()
        task?.cancel()
        task = nil
        activeID = nil
        isRunning = false
    }
}
