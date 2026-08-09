import Foundation

/// English Metric Units — the native length unit of OOXML.
///
/// 914,400 EMU per inch; 360,000 per centimeter; 12,700 per point. The number
/// exists so that inches, centimeters and points all divide it exactly —
/// coordinates in Office files are integers with no rounding drift.
public struct EMU: RawRepresentable, Hashable, Sendable, Comparable, AdditiveArithmetic, CustomStringConvertible {
    public var rawValue: Int

    public init(rawValue: Int) { self.rawValue = rawValue }
    public init(_ rawValue: Int) { self.rawValue = rawValue }

    public static let perInch = 914_400
    public static let perCentimeter = 360_000
    public static let perMillimeter = 36_000
    public static let perPoint = 12_700
    /// CSS reference pixel at 96 DPI: 914,400 / 96. Divides the inch exactly, so
    /// px→EMU stays an integer with no rounding drift (the same 96-DPI basis
    /// Office uses when it materializes CSS/HTML pixel lengths).
    public static let perPixel = 9_525

    public static func inches(_ v: Double) -> EMU { EMU(clamped(v * Double(perInch))) }
    public static func centimeters(_ v: Double) -> EMU { EMU(clamped(v * Double(perCentimeter))) }
    public static func millimeters(_ v: Double) -> EMU { EMU(clamped(v * Double(perMillimeter))) }
    public static func points(_ v: Double) -> EMU { EMU(clamped(v * Double(perPoint))) }
    public static func pixels(_ v: Double) -> EMU { EMU(clamped(v * Double(perPixel))) }

    /// `Int(_: Double)` traps on NaN, infinity, and magnitude past `Int.max` —
    /// an uncatchable abort reachable from every factory and scalar operator
    /// (`width / 0.0` is all it takes). Layout math must degrade, not kill the
    /// host process: NaN maps to 0, and out-of-range magnitudes saturate to
    /// `OOXMLBounds.coordinate`, the same ceiling the read side imposes so
    /// that downstream `+`/`*` over the result cannot overflow either.
    private static func clamped(_ value: Double) -> Int {
        guard value.isFinite else { return value.isNaN ? 0 : (value > 0 ? saturation : -saturation) }
        let rounded = value.rounded()
        guard abs(rounded) <= Double(saturation) else { return rounded > 0 ? saturation : -saturation }
        return Int(rounded)
    }
    private static let saturation = OOXMLBounds.coordinate.upperBound

    public var inches: Double { Double(rawValue) / Double(EMU.perInch) }
    public var centimeters: Double { Double(rawValue) / Double(EMU.perCentimeter) }
    public var millimeters: Double { Double(rawValue) / Double(EMU.perMillimeter) }
    public var points: Double { Double(rawValue) / Double(EMU.perPoint) }
    public var pixels: Double { Double(rawValue) / Double(EMU.perPixel) }

    /// Alias for `EMU(_:)` so raw values read like the other factories in
    /// static-member-inference position: `.emu(914_400)`.
    public static func emu(_ rawValue: Int) -> EMU { EMU(rawValue) }

    public static func < (lhs: EMU, rhs: EMU) -> Bool { lhs.rawValue < rhs.rawValue }
    public static func + (lhs: EMU, rhs: EMU) -> EMU { EMU(lhs.rawValue + rhs.rawValue) }
    public static func - (lhs: EMU, rhs: EMU) -> EMU { EMU(lhs.rawValue - rhs.rawValue) }
    public static var zero: EMU { EMU(0) }

    public static prefix func - (value: EMU) -> EMU { EMU(-value.rawValue) }

    // Scalar arithmetic for layout math ("a third of the slide width").
    public static func * (lhs: EMU, rhs: Double) -> EMU { EMU(clamped(Double(lhs.rawValue) * rhs)) }
    public static func * (lhs: Double, rhs: EMU) -> EMU { rhs * lhs }
    public static func / (lhs: EMU, rhs: Double) -> EMU { EMU(clamped(Double(lhs.rawValue) / rhs)) }
    /// The dimensionless ratio of two lengths (aspect ratios, proportions).
    public static func / (lhs: EMU, rhs: EMU) -> Double { Double(lhs.rawValue) / Double(rhs.rawValue) }

    public var description: String { "\(rawValue) EMU" }
}

// Ergonomics decision (2026-07-18): static-member inference — `.points(24)`,
// `.inches(1.5)` — is the API, matching the stdlib's `Duration` pattern
// (`.seconds(5)`). No unit is privileged: points and inches are equally
// first-class on both write (`.points(540)`) and read (`width.points`).
// Numeric-literal extensions (`1.5.inches`) were rejected because they
// pollute Double for every importer; `Measurement` bridging because
// `UnitLength` has no points unit.
