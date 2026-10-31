import Foundation
import Testing
@testable import Rostrum
@testable import RostrumLayout

@Suite struct StructuredLayoutTests {
    private func region(width: Double, height: Double) -> Rect {
        Rect(x: .points(40), y: .points(100), width: .points(width), height: .points(height))
    }

    private func expectCannotFit(_ kind: StructuredKind, count: Int, in region: Rect) {
        #expect(throws: LayoutError.self) {
            _ = try StructuredLayout.frames(kind: kind, count: count, in: region)
        }
    }

    @Test func bandsTooShortForCountThrowsInsteadOfNegativeFrames() {
        expectCannotFit(.bands, count: 12, in: region(width: 640, height: 100))
    }

    @Test func pyramidTooNarrowThrows() {
        // Tall enough that every band clears the 48-pt height floor
        // ((800 - 11 * 16) / 12 ≈ 52), so only the narrowest band's width
        // (100 * (0.55 + 0.45 / 12) ≈ 59 < 72) can be what throws.
        expectCannotFit(.pyramid, count: 12, in: region(width: 100, height: 800))
    }

    @Test func pyramidTooShortThrows() {
        expectCannotFit(.pyramid, count: 12, in: region(width: 640, height: 100))
    }

    @Test func cycleTooShortThrows() {
        expectCannotFit(.cycle, count: 6, in: region(width: 640, height: 60))
    }

    @Test func generousRegionYieldsPositiveReadableFramesForEveryKind() throws {
        let area = region(width: 800, height: 600)
        let kinds: [StructuredKind] = [.metrics, .process, .cycle, .pyramid, .timeline, .quadrant, .bands]
        for scale in [1.0, 1.5] {
            for kind in kinds {
                for count in [1, 4, 6] {
                    let frames = try StructuredLayout.frames(kind: kind, count: count, in: area, scale: scale)
                    #expect(frames.count == count)
                    for frame in frames {
                        #expect(frame.width.points >= 72 * scale)
                        #expect(frame.height.points >= 48 * scale)
                        #expect(frame.width.points > 0 && frame.height.points > 0)
                    }
                }
            }
        }
    }
}
