// Generated alongside PresetGeometry.swift. Do not edit by hand.

import Testing
@testable import Rostrum

@Suite("PresetGeometryTests")
struct PresetGeometryTests {

    @Test func allRawValuesAreUnique() {
        let raws = ShapeGeometry.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
    }

    @Test func caseCountMatchesExtraction() {
        #expect(ShapeGeometry.allCases.count == 178)
    }

    @Test func requiredCasesHaveRequiredRawValues() {
        #expect(ShapeGeometry.rectangle.rawValue == "rect")
        #expect(ShapeGeometry.roundedRectangle.rawValue == "roundRect")
        #expect(ShapeGeometry.ellipse.rawValue == "ellipse")
        #expect(ShapeGeometry.line.rawValue == "line")
        #expect(ShapeGeometry.chevron.rawValue == "chevron")
        #expect(ShapeGeometry.rightArrow.rawValue == "rightArrow")
        #expect(ShapeGeometry.downArrow.rawValue == "downArrow")
        #expect(ShapeGeometry.triangle.rawValue == "triangle")
    }
}
