import Foundation
import Observation
import LecternCore

/// A selection is an owned byte snapshot: the file provider's security scope
/// can close after import, and later edits to the original cannot change a run.
@MainActor
@Observable
final class TemplateSelectionModel {
    private(set) var selected: DeckTemplate?
    private(set) var isLoading = false
    private(set) var problem: String?
    private var task: Task<Void, Never>?
    private var runs = RunGate()

    @discardableResult
    func select(_ url: URL,
                loading: @escaping @Sendable (URL) async throws -> DeckTemplate = { url in
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    return try DeckTemplate.load(contentsOf: url)
                }) -> Task<Void, Never> {
        task?.cancel()
        let run = runs.begin()
        isLoading = true
        problem = nil
        let work = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try Task.checkCancellation()
                let template = try await loading(url)
                try Task.checkCancellation()
                await self?.finish(.success(template), run: run)
            } catch {
                await self?.finish(.failure(error), run: run)
            }
        }
        task = work
        return work
    }

    private func finish(_ result: Result<DeckTemplate, Error>, run: Int) {
        guard runs.isCurrent(run) else { return }
        isLoading = false
        task = nil
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let template): selected = template
        case .failure(let error):
            if !(error is CancellationError) {
                problem = error.localizedDescription
            }
        }
    }

    func cancelImport() {
        runs.abandon()
        task?.cancel()
        task = nil
        problem = nil
        isLoading = false
    }

    func clear() {
        cancelImport()
        selected = nil
    }
}
