import Foundation
import Observation
import LecternCore

struct NotesPagePreviewRequest: Identifiable, Hashable, Sendable {
    let fileURL: URL
    let slideNumber: Int
    var id: Self { self }
}

/// Owns the actual background task, including security-scoped access. A page
/// closed or replaced during synchronous rendering cannot publish afterward.
@Observable @MainActor
final class NotesPagePreviewModel {
    private(set) var preview: NotesPageInspection?
    private(set) var problem: String?
    private(set) var isLoading = false
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var runs = RunGate()

    @discardableResult
    func load(_ request: NotesPagePreviewRequest) -> Task<Void, Never> {
        load(request) { request in
            try DeckInspector.inspectNotesPage(deckAt: request.fileURL, slideNumber: request.slideNumber)
        }
    }

    @discardableResult
    func load(
        _ request: NotesPagePreviewRequest,
        using operation: @escaping @Sendable (NotesPagePreviewRequest) async throws -> NotesPageInspection
    ) -> Task<Void, Never> {
        let run = runs.begin()
        task?.cancel()
        preview = nil
        problem = nil
        isLoading = true
        let work = Task.detached(priority: .userInitiated) { [self] in
            do {
                try Task.checkCancellation()
                let scoped = request.fileURL.startAccessingSecurityScopedResource()
                defer { if scoped { request.fileURL.stopAccessingSecurityScopedResource() } }
                let result = try await operation(request)
                try Task.checkCancellation()
                await MainActor.run {
                    guard runs.isCurrent(run) else { return }
                    let cancelled = task?.isCancelled ?? true
                    runs.abandon()
                    task = nil
                    isLoading = false
                    if !cancelled { preview = result }
                }
            } catch {
                let message = String(describing: error)
                let cancelled = Task.isCancelled || error is CancellationError
                await MainActor.run {
                    guard runs.isCurrent(run) else { return }
                    let retired = cancelled || (task?.isCancelled ?? true)
                    runs.abandon()
                    task = nil
                    isLoading = false
                    if !retired { problem = message }
                }
            }
        }
        task = work
        return work
    }

    func cancel() {
        runs.abandon()
        task?.cancel()
        task = nil
        isLoading = false
        preview = nil
        problem = nil
    }
}
