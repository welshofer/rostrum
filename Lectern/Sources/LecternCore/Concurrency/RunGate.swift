import Foundation

/// Which run of a cancellable job is the current one.
///
/// Cancellation in Swift is cooperative: `Task.cancel()` returns immediately,
/// and the task's own continuation runs some time afterwards — possibly after
/// the user has started a replacement. Any state that continuation writes has
/// to prove it still belongs to the run on screen, or it will land on top of
/// whatever replaced it.
///
/// The failure this exists to stop: cancel a deck generation, immediately
/// generate again, and the first task resolves and writes "back to compose"
/// over the live run. The screen drops out of generating while the new
/// generation keeps going, keeps spending, and finishes into a state nobody is
/// showing.
///
/// A counter rather than a token object so it is trivially `Sendable`, cheap to
/// capture, and impossible to retain a cycle through.
public struct RunGate: Sendable, Equatable {
    private var current = 0

    public init() {}

    /// Start a new run, abandoning any previous one, and return its id.
    public mutating func begin() -> Int {
        current &+= 1
        return current
    }

    /// Abandon the current run without starting another — what cancelling does.
    /// Anything still in flight stops being current immediately, rather than
    /// only once a replacement happens to start.
    public mutating func abandon() {
        current &+= 1
    }

    /// Whether `run` is still the one whose writes should be honoured.
    public func isCurrent(_ run: Int) -> Bool { run == current }
}
