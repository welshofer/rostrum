import Foundation
import Testing
@testable import Rostrum

@Suite struct SVGNumberTests {
    @Test(arguments: [0.0, 1, -1, 1.23456, -1.23456, 0.00004, -0.00004,
                      0.00016, 1234567.89012, -1099511627775.125])
    func coordinatesKeepPrecisionAndLocaleIndependentSyntax(_ value: Double) throws {
        let text = SVGNumber.decimal(value)
        let parsed = try #require(Double(text))
        #expect(abs(parsed - value) <= 0.000051)
        #expect(!text.contains(","))
        if value.rounded() == value { #expect(!text.contains(".")) }
    }
    @Test func nonfiniteAndExtremeValuesNeverTrap() {
        #expect(SVGNumber.decimal(.infinity) == "0")
        #expect(SVGNumber.decimal(.nan) == "0")
        #expect(Double(SVGNumber.decimal(Double.greatestFiniteMagnitude)) == Double.greatestFiniteMagnitude)
    }
}
