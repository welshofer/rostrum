import Foundation
import Testing
@testable import LecternCore

@Suite struct RunGateTests {
    @Test func theRunItStartedIsTheCurrentOne() {
        var gate = RunGate()
        let first = gate.begin()
        #expect(gate.isCurrent(first))
    }

    /// The bug this type exists for: cancel a generation, start another, and
    /// the first task's continuation runs afterwards. It must not be able to
    /// write over the run that replaced it.
    @Test func aReplacedRunIsNoLongerCurrent() {
        var gate = RunGate()
        let cancelled = gate.begin()
        let live = gate.begin()
        #expect(!gate.isCurrent(cancelled), "the abandoned run could still write")
        #expect(gate.isCurrent(live))
    }

    /// Cancelling with no replacement has to orphan the in-flight run
    /// immediately, rather than leaving it current until something else
    /// happens to start.
    @Test func abandoningOrphansTheRunWithoutStartingAnother() {
        var gate = RunGate()
        let run = gate.begin()
        gate.abandon()
        #expect(!gate.isCurrent(run))
        // `abandon` parks the counter on a value `begin` will never hand out —
        // it pre-increments — so no run that was ever issued is current, and
        // the next one gets a fresh id rather than inheriting the gap.
        let next = gate.begin()
        #expect(next != run)
        #expect(gate.isCurrent(next))
    }

    /// A fresh gate has issued nothing, so no id a caller could be holding is
    /// current.
    @Test func noIssuedRunIsCurrentBeforeTheFirstBegin() {
        let gate = RunGate()
        #expect(!gate.isCurrent(1))
        #expect(!gate.isCurrent(2))
        // begin() never returns the initial value, so 0 can never be a run id
        // a caller captured.
        var started = RunGate()
        #expect(started.begin() != 0)
    }

    @Test func idsDoNotRepeatAcrossManyRuns() {
        var gate = RunGate()
        var seen: Set<Int> = []
        for _ in 0..<500 { seen.insert(gate.begin()) }
        #expect(seen.count == 500, "run ids collided, so a stale write could be honoured")
    }
}
