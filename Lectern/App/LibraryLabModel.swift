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
    private(set) var failures: [LibraryDemoID: String] = [:]
    private(set) var isRunning = false
    private(set) var activeID: LibraryDemoID?
    private(set) var completed = 0
    private(set) var total = 0
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var runs = RunGate()

    @discardableResult
    func run(_ ids: [LibraryDemoID], in parent: URL = AppState.diagnosticsDirectory().appendingPathComponent("Library Lab")) -> Task<Void, Never> {
        run(ids, in: parent) { id, options, parent in
            try LibraryLab.run(id, options: options, in: parent)
        }
    }

    @discardableResult
    func run(_ ids: [LibraryDemoID], in parent: URL,
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
        for id in ids { failures[id] = nil; results[id] = nil }
        let work = Task.detached(priority: .userInitiated) { [self] in
            for id in ids {
                if Task.isCancelled { break }
                await MainActor.run {
                    if runs.isCurrent(run) { activeID = id }
                }
                do {
                    let result = try await operation(id, options, parent)
                    try Task.checkCancellation()
                    await MainActor.run {
                        guard runs.isCurrent(run), task?.isCancelled == false else { return }
                        results[id] = result
                        completed += 1
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
