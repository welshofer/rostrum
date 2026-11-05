import Foundation
import Testing
@testable import Rostrum

/// Public numeric setters convert `Double` to fixed-point wire integers.
/// `Int(_: Double)` traps on NaN/±infinity and on out-of-range magnitudes, so
/// each setter routes through `fixedPoint(_:scale:)`: non-finite input is a
/// no-op (attribute unchanged / element not created) and huge finite input
/// clamps to the 32-bit range instead of aborting the host process.
@Suite struct NonFiniteSetterTests {
    static let nonFinite: [Double] = [.nan, .infinity, -.infinity]

    private func newBox() throws -> (Presentation, Shape, TextFrame) {
        let deck = try Presentation()
        let box = try deck.slides[0].shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(4)))
        return (deck, box, box.textFrame!)
    }

    private func reopenedShape(_ deck: Presentation) throws -> Shape {
        let reopened = try Presentation(data: try deck.serializedData())
        return try reopened.slides[0].shapes[reopened.slides[0].shapes.count - 1]
    }

    // MARK: - Helper

    @Test func fixedPointMatchesLegacyFormattingForFiniteInput() {
        let values: [Double] = [0, 1, -1, 0.5, -0.5, 1.5, 2.5, 12.345, -17.25, 0.35, 0.01, 359.99, 1e-9]
        for value in values {
            for scale in [100.0, 1000, 60_000, 100_000] {
                #expect(fixedPoint(value, scale: scale) == String(Int((value * scale).rounded())))
            }
        }
    }

    @Test func fixedPointRejectsNonFiniteAndClampsHugeValues() {
        for value in Self.nonFinite { #expect(fixedPoint(value, scale: 100) == nil) }
        #expect(fixedPoint(1e30, scale: 100) == String(Int32.max))
        #expect(fixedPoint(-1e30, scale: 100) == String(Int32.min))
        // Finite × scale overflowing to infinity still clamps.
        #expect(fixedPoint(.greatestFiniteMagnitude, scale: 100_000) == String(Int32.max))
        #expect(fixedPoint(-.greatestFiniteMagnitude, scale: 100_000) == String(Int32.min))
    }

    // MARK: - Shape.rotation (Shapes.swift)

    @Test func rotationIgnoresNonFiniteAndClampsHuge() throws {
        let (deck, shape, _) = try newBox()
        shape.rotation = 15
        let before = shape.element.serialized()
        for value in Self.nonFinite {
            shape.rotation = value
            #expect(shape.element.serialized() == before)
        }
        #expect(shape.rotation == 15)

        // A shape with no transform at all must not gain one on non-finite input.
        let bare = try deck.slides[0].shapes.addShape(
            .rectangle, frame: Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1)), fill: .none)
        bare.element.firstChild(named: "p:spPr")?.removeChildren(named: "a:xfrm")
        let bareBefore = bare.element.serialized()
        for value in Self.nonFinite {
            bare.rotation = value
            #expect(bare.element.serialized() == bareBefore)
        }

        shape.rotation = 1e30
        #expect(xfrm(shape)?[attribute: "rot"] == String(Int32.max))
        shape.rotation = -1e30
        #expect(xfrm(shape)?[attribute: "rot"] == String(Int32.min))

        shape.rotation = 30
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(try reopened.slides[0].shapes[0].rotation == 30)
    }

    private func xfrm(_ shape: Shape) -> XML.Element? {
        shape.element.firstChild(named: "p:spPr")?.firstChild(named: "a:xfrm")
    }

    // MARK: - TextFrame.setAutoFit (Text.swift)

    @Test func autoFitIgnoresNonFinite() throws {
        let (deck, shape, tf) = try newBox()
        tf.setAutoFit(fontScale: 0.8)
        let before = shape.element.serialized()
        for value in Self.nonFinite {
            tf.setAutoFit(fontScale: value)
            #expect(shape.element.serialized() == before)
        }
        tf.setAutoFit(fontScale: 0.75)
        let reopened = try reopenedShape(deck)
        let fit = reopened.textFrame?.txBody.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit")
        #expect(fit?[attribute: "fontScale"] == "75000")
    }

    // MARK: - Paragraph.setSpacing / setLineSpacing (Text.swift)

    @Test func spacingIgnoresNonFiniteWithoutCreatingElements() throws {
        let (deck, shape, tf) = try newBox()
        tf.clear()
        let fresh = tf.addParagraph()
        fresh.addRun("fresh")
        let freshBefore = shape.element.serialized()
        for value in Self.nonFinite {
            fresh.setSpacing(beforePoints: value, afterPoints: value)
            fresh.setLineSpacing(value)
            #expect(shape.element.serialized() == freshBefore)
        }
        #expect(fresh.p.firstChild(named: "a:pPr") == nil)

        let p = tf.addParagraph()
        p.addRun("spaced")
        p.setSpacing(beforePoints: 6, afterPoints: 3)
        p.setLineSpacing(1.2)
        let before = shape.element.serialized()
        for value in Self.nonFinite {
            p.setSpacing(beforePoints: value)
            p.setSpacing(afterPoints: value)
            p.setLineSpacing(value)
            #expect(shape.element.serialized() == before)
        }

        // Mixed: a finite side still applies when the other is non-finite.
        p.setSpacing(beforePoints: 12, afterPoints: .nan)
        p.setLineSpacing(1.5)
        let reopened = try reopenedShape(deck)
        let pPr = try #require(reopened.textFrame?.paragraphs[1].p.firstChild(named: "a:pPr"))
        #expect(pPr.firstChild(named: "a:spcBef")?.firstChild(named: "a:spcPts")?[attribute: "val"] == "1200")
        #expect(pPr.firstChild(named: "a:spcAft")?.firstChild(named: "a:spcPts")?[attribute: "val"] == "300")
        #expect(pPr.firstChild(named: "a:lnSpc")?.firstChild(named: "a:spcPct")?[attribute: "val"] == "150000")

        p.setLineSpacing(1e30)
        #expect(p.p.firstChild(named: "a:pPr")?.firstChild(named: "a:lnSpc")?
            .firstChild(named: "a:spcPct")?[attribute: "val"] == String(Int32.max))
        p.setSpacing(beforePoints: -1e30)
        #expect(p.p.firstChild(named: "a:pPr")?.firstChild(named: "a:spcBef")?
            .firstChild(named: "a:spcPts")?[attribute: "val"] == String(Int32.min))
    }

    // MARK: - Run.fontSize / letterSpacing / baselinePercent (Text.swift)

    @Test func runNumericSettersIgnoreNonFinite() throws {
        let (deck, shape, tf) = try newBox()
        tf.clear()
        let run = tf.addParagraph().addRun("styled")
        run.fontSize = 18
        run.letterSpacing = 1.5
        run.baselinePercent = 30
        let before = shape.element.serialized()
        for value in Self.nonFinite {
            run.fontSize = value
            run.letterSpacing = value
            run.baselinePercent = value
            #expect(shape.element.serialized() == before)
        }
        #expect(run.fontSize == 18)
        #expect(run.letterSpacing == 1.5)
        #expect(run.baselinePercent == 30)

        // nil still removes; non-finite on an absent attribute does not add one.
        run.letterSpacing = nil
        run.letterSpacing = .nan
        #expect(run.r.firstChild(named: "a:rPr")?[attribute: "spc"] == nil)

        // A run without a:rPr must not gain one on non-finite input.
        let bare = tf.addParagraph().addRun("bare")
        bare.r.removeChildren(named: "a:rPr")
        let bareBefore = bare.r.serialized()
        for value in Self.nonFinite {
            bare.fontSize = value
            bare.letterSpacing = value
            bare.baselinePercent = value
            #expect(bare.r.serialized() == bareBefore)
        }

        run.fontSize = 1e30
        #expect(run.r.firstChild(named: "a:rPr")?[attribute: "sz"] == String(Int32.max))
        run.letterSpacing = -1e30
        #expect(run.r.firstChild(named: "a:rPr")?[attribute: "spc"] == String(Int32.min))
        run.baselinePercent = 1e30
        #expect(run.r.firstChild(named: "a:rPr")?[attribute: "baseline"] == String(Int32.max))

        run.fontSize = 24
        run.letterSpacing = -0.5
        run.baselinePercent = -25
        let reopened = try reopenedShape(deck)
        let rr = try #require(reopened.textFrame?.paragraphs[0].runs[0])
        #expect(rr.fontSize == 24)
        #expect(rr.letterSpacing == -0.5)
        #expect(rr.baselinePercent == -25)
    }

    // MARK: - Color alpha / gradient stops (Drawing.swift)

    @Test func alphaFillSkipsAlphaElementOnNonFinite() throws {
        let (deck, shape, _) = try newBox()
        for value in Self.nonFinite {
            try shape.setFill(.solidAlpha(.black, value))
            let clr = shape.element.firstChild(named: "p:spPr")?
                .firstChild(named: "a:solidFill")?.firstChild(named: "a:srgbClr")
            #expect(clr != nil)
            #expect(clr?.firstChild(named: "a:alpha") == nil)
        }
        try shape.setFill(.solidAlpha(.black, -1e30))
        #expect(shape.element.firstChild(named: "p:spPr")?.firstChild(named: "a:solidFill")?
            .firstChild(named: "a:srgbClr")?.firstChild(named: "a:alpha")?[attribute: "val"] == String(Int32.min))

        try shape.setFill(.solidAlpha(.black, 0.35))
        let reopened = try reopenedShape(deck)
        #expect(reopened.element.firstChild(named: "p:spPr")?.firstChild(named: "a:solidFill")?
            .firstChild(named: "a:srgbClr")?.firstChild(named: "a:alpha")?[attribute: "val"] == "35000")
    }

    @Test func gradientSkipsNonFiniteStopsAndAngle() throws {
        let (deck, shape, _) = try newBox()
        for value in Self.nonFinite {
            try shape.setFill(.gradient(GradientFill(stops: [
                GradientStop(position: 0, color: .white),
                GradientStop(position: value, color: .black, alpha: value),
                GradientStop(position: 1, color: .black),
            ], angleDegrees: value)))
            let grad = try #require(shape.element.firstChild(named: "p:spPr")?.firstChild(named: "a:gradFill"))
            let stops = try #require(grad.firstChild(named: "a:gsLst")).children(named: "a:gs")
            #expect(stops.map { $0[attribute: "pos"] } == ["0", "100000"])
            #expect(stops.allSatisfy { $0.firstChild(named: "a:srgbClr")?.firstChild(named: "a:alpha") == nil })
            #expect(grad.firstChild(named: "a:lin") == nil)
        }

        try shape.setFill(.gradient(GradientFill(stops: [
            GradientStop(position: -1e30, color: .white),
            GradientStop(position: 1e30, color: .black),
        ], angleDegrees: 1e30)))
        let huge = try #require(shape.element.firstChild(named: "p:spPr")?.firstChild(named: "a:gradFill"))
        #expect(huge.firstChild(named: "a:gsLst")?.children(named: "a:gs").map { $0[attribute: "pos"] }
            == [String(Int32.min), String(Int32.max)])
        #expect(huge.firstChild(named: "a:lin")?[attribute: "ang"] == String(Int32.max))

        try shape.setFill(.gradient(GradientFill(from: .white, to: .black, angleDegrees: 45)))
        let reopened = try reopenedShape(deck)
        let grad = try #require(reopened.element.firstChild(named: "p:spPr")?.firstChild(named: "a:gradFill"))
        #expect(grad.firstChild(named: "a:gsLst")?.children(named: "a:gs").map { $0[attribute: "pos"] }
            == ["0", "100000"])
        #expect(grad.firstChild(named: "a:lin")?[attribute: "ang"] == "2700000")
    }
}
