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

    public static func inches(_ v: Double) -> EMU { EMU(Int((v * Double(perInch)).rounded())) }
    public static func centimeters(_ v: Double) -> EMU { EMU(Int((v * Double(perCentimeter)).rounded())) }
    public static func millimeters(_ v: Double) -> EMU { EMU(Int((v * Double(perMillimeter)).rounded())) }
    public static func points(_ v: Double) -> EMU { EMU(Int((v * Double(perPoint)).rounded())) }

    public var inches: Double { Double(rawValue) / Double(EMU.perInch) }
    public var centimeters: Double { Double(rawValue) / Double(EMU.perCentimeter) }
    public var millimeters: Double { Double(rawValue) / Double(EMU.perMillimeter) }
    public var points: Double { Double(rawValue) / Double(EMU.perPoint) }

    public static func < (lhs: EMU, rhs: EMU) -> Bool { lhs.rawValue < rhs.rawValue }
    public static func + (lhs: EMU, rhs: EMU) -> EMU { EMU(lhs.rawValue + rhs.rawValue) }
    public static func - (lhs: EMU, rhs: EMU) -> EMU { EMU(lhs.rawValue - rhs.rawValue) }
    public static var zero: EMU { EMU(0) }

    public var description: String { "\(rawValue) EMU" }
}

// TODO(user contribution): the ergonomic layer.
//
// python-pptx makes callers write `Inches(1)`, `Pt(18)`, `Emu(914400)`. Swift
// can do better, and the choice here shapes how every line of user code reads
// for the life of the library. Candidate designs:
//
//   1. Numeric-literal extensions:      shape.width = 1.5.inches
//      (Sweet to read; pollutes Double/Int globally for any importer.)
//   2. Static-member inference:         shape.width = .inches(1.5)
//      (Already works today via the factories above; zero pollution; a bit
//       more punctuation.)
//   3. Measurement bridging:            shape.width = EMU(Measurement(value: 1.5, unit: UnitLength.inches))
//      (Interops with Foundation/HealthKit-style code; verbose; UnitLength
//       has no "points".)
//
// Implement your pick below (5–10 lines). If you choose (1), consider gating it
// behind an explicit `import RostrumSugar`-style opt-in later.
