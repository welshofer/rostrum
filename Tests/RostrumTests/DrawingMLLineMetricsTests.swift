import Foundation
import Testing
@testable import Rostrum

@Suite struct DrawingMLLineMetricsTests {
    private func fontData(ascent: Int, descent: Int, length: Int = 78, useTypo: Bool = false) -> Data {
        var os2 = TestFont.os2(useTypoMetrics: useTypo)
        os2.replaceSubrange(74..<76, with: TestFont.be16(ascent))
        os2.replaceSubrange(76..<78, with: TestFont.be16(descent))
        return TestFont.standard(os2: Array(os2.prefix(length)))
    }
    private func metrics(ascent: Int = 1854, descent: Int = 434, length: Int = 78,
                         useTypo: Bool = false) throws -> FontMetrics {
        try FontMetrics(data: fontData(ascent: ascent, descent: descent, length: length, useTypo: useTypo))
    }
    private func body(sizes: [Int], paragraph: String = "", autofit: String = "") throws -> XML.Element {
        let runs = sizes.enumerated().map { index, size in
            (index > 0 ? "<a:br/>" : "") + "<a:r><a:rPr sz=\"\(size * 100)\"/><a:t>Hpxgy</a:t></a:r>"
        }.joined()
        return try XML.parse(Data("<p:txBody><a:bodyPr lIns=\"0\" rIns=\"0\" tIns=\"0\" bIns=\"0\">\(autofit)</a:bodyPr><a:p><a:pPr>\(paragraph)</a:pPr>\(runs)</a:p></p:txBody>".utf8))
    }
    @Test func windowsPairDoesNotChangeGenericMetricAPIs() throws {
        let font = try metrics(useTypo: true)
        #expect(font.ascent(pointSize: 20) == 15)
        #expect(font.descent(pointSize: 20) == 5)
        #expect(font.lineHeight(pointSize: 20) == 22)
        #expect(abs(try #require(font.drawingMLAscentShare) - 1854.0 / 2288) < 1e-12)
    }
    @Test func absentTruncatedAndZeroWindowsMetricsRetainFallback() throws {
        for length in [0, 62, 64, 74, 75, 76, 77] {
            #expect(try metrics(length: length).drawingMLAscentShare == nil)
        }
        #expect(try metrics(ascent: 0, descent: 0).drawingMLAscentShare == nil)
        #expect(try metrics(ascent: 0, descent: 65535).drawingMLAscentShare == nil)
        #expect(try metrics(ascent: 65535, descent: 65535).drawingMLAscentShare == 0.5)
        #expect(try metrics(ascent: 65535, descent: 0).drawingMLAscentShare == 1)
        let layout = RichTextLayout(textBody: try body(sizes: [18, 18]), width: 300, height: 300,
                                    fallbackMetrics: try FontMetrics(data: TestFont.standard()))
        #expect(layout.lines.map(\.baseline) == [14.4, 32.4])
    }
    @Test func independentOfficeBaselinesRequireUnroundedAccumulation() throws {
        // Native PowerPoint 16.113.3 PDF, verified glyph outlines. Values are
        // content-relative points. The 0.121pt bound covers its 0.24pt PDF grid.
        for (asc, desc, sizes, baselines) in [
            (1854, 434, [14], [13.92]), (1854, 434, [18], [18.0]), (1854, 434, [24], [23.04]),
            (1950, 550, [14], [12.96]), (1950, 550, [18], [17.04]), (1950, 550, [24], [22.08]),
            (1854, 434, [24, 14], [23.04, 42.0]), (1854, 434, [14, 24], [13.92, 40.08]),
            (1854, 434, [18, 18], [18.0, 38.88]), (1950, 550, [24, 14], [22.08, 42.0]),
            (1950, 550, [14, 24], [12.96, 38.88]), (1950, 550, [18, 18], [17.04, 37.92])
        ] {
            for spacing in ["", "<a:lnSpc><a:spcPct val=\"100000\"/></a:lnSpc>"] {
                let layout = RichTextLayout(textBody: try body(sizes: sizes, paragraph: spacing), width: 300, height: 300,
                                            fallbackMetrics: try metrics(ascent: asc, descent: desc))
                #expect(layout.lines.count == baselines.count)
                for (line, baseline) in zip(layout.lines, baselines) { #expect(abs(line.baseline - baseline) < 0.121) }
            }
        }
    }
    @Test func explicitSpacingAndAutofitKeepUnroundedAdvance() throws {
        let font = try metrics()
        let exact = RichTextLayout(textBody: try body(sizes: [24, 14], paragraph: "<a:lnSpc><a:spcPts val=\"1000\"/></a:lnSpc>"),
                                   width: 300, height: 300, fallbackMetrics: font)
        #expect(exact.lines.map(\.baseline) == [23, 24])
        #expect(exact.lines.map(\.height) == [10, 10])
        let proportional = RichTextLayout(textBody: try body(sizes: [24, 14], paragraph: "<a:lnSpc><a:spcPct val=\"200000\"/></a:lnSpc>"),
                                          width: 300, height: 300, fallbackMetrics: font)
        #expect(proportional.lines.map(\.baseline) == [23, 71])
        let xml = try body(sizes: [24, 14], autofit: "<a:normAutofit fontScale=\"50000\" lnSpcReduction=\"20000\"/>")
        let reduced = RichTextLayout(textBody: xml, width: 300, height: 20, fallbackMetrics: font)
        #expect(reduced.lines.map(\.baseline) == [12, 18])
        #expect(abs(reduced.lines[0].height - 11.52) < 1e-9)
        #expect(reduced.lines.flatMap(\.spans).map(\.run.fontSize) == [12, 7])
        #expect(reduced.fits)
        // Last-line descent exceeds the reduced advance; do not report a fit
        // merely because the unrounded flow cursor (18.24pt) fits.
        #expect(!RichTextLayout(textBody: xml, width: 300, height: 18.5, fallbackMetrics: font).fits)
        #expect(reduced.contentHeight > 19)
    }
    @Test func roundingDoesNotAccumulateAndInsetsStayOutsideTheMetricRule() throws {
        let xml = try body(sizes: Array(repeating: 18, count: 100))
        let layout = RichTextLayout(textBody: xml, width: 300, height: 3000, fallbackMetrics: try metrics(),
                                    insets: (left: 0, top: 5.04, right: 0, bottom: 0))
        #expect(layout.lines.count == 100)
        #expect(abs(layout.lines[99].baseline - 2161.04) < 1e-8)
        #expect(layout.lines[0].baseline == 23.04)
    }
    @Test func fittingUsesTheSameWindowsMetricsAndRoundedDescentAsSVG() throws {
        let deck = try Presentation()
        try deck.fonts.register(fontData(ascent: 1854, descent: 434), aliases: ["Metric Fixture"])
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero, y: .zero, width: .points(100), height: .points(16.9)))
        let frame = try #require(shape.textFrame)
        frame.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        frame.text = "Hpxgy"
        frame.paragraphs[0].runs[0].fontName = "Metric Fixture"
        frame.paragraphs[0].runs[0].fontSize = 14
        let fit = frame.fitText(in: shape.frame, fonts: deck.fonts, theme: deck.theme)
        #expect(fit.fits && fit.fontScale == 92.5)
        let layout = RichTextLayout(textBody: frame.txBody, width: 100, height: 16.9, fonts: deck.fonts, theme: deck.theme)
        #expect(layout.fits && layout.lines[0].baseline == 13)
        let before = frame.txBody.serialized()
        let svg = try deck.renderSVG(slideAt: 0)
        #expect(svg.contains("translate(0,165100) scale(12700)"))
        #expect(frame.txBody.serialized() == before)
    }
}
