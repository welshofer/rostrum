import Foundation
import Testing
@testable import Rostrum

@Suite struct ChartPreviewFidelityTests {
    @Test func numericFormatsPreserveUnitsAndDistinguishLiteralPercent() {
        let cases: [(String, Double, String)] = [
            (#"0"%""#, 20, "20%"), (#"0.0"%""#, 1.2, "1.2%"),
            (#"0\%"#, 20, "20%"), ("0%", 0.2, "20%"), ("0.0%", -0.125, "-12.5%"),
            ("\"$\"#,##0.0\"B\"", 64.7, "$64.7B"), ("#,##0\"K\"", 1200, "1,200K"),
            (#"0.0,,"M""#, 1250000, "1.3M"), ("0.##", 1.2, "1.2"),
            (#"0.0;(0.0);"—""#, -3.2, "(3.2)"), (#"0.0;(0.0);"—""#, 0, "—"),
            (#"0"; units""#, 5, "5; units"), (#"0"\"quoted\"""#, 5, "5\"quoted\""),
            ("0;;", -3, ""), ("000", 3, "003"), ("General", 123.25, "123.25")
        ]
        for (code, value, expected) in cases {
            let format = ChartNumberFormat(code)
            #expect(format.isSupported, "\(code)")
            #expect(format.string(value) == expected, "\(code) for \(value)")
        }
        for code in ["0.0E+00", "yyyy-mm-dd", "mm:ss", "# ?/?", "[Red]0", "0_)", "0* ", "[>=0]0", "0\"unterminated", "0\\", "0;0;0;0;0"] {
            #expect(!ChartNumberFormat(code).isSupported, "\(code)")
        }
        #expect(ChartNumberFormat("0").string(.infinity).isEmpty)
    }

    private func make(_ kind: ChartKind = .barClustered, values: [Double] = [17, 31], options: ChartOptions = .init()) throws -> (Presentation, XML.Element) {
        let deck = try Presentation()
        try deck.slides[0].shapes.addChart(kind,
            data: ChartData(categories: values.indices.map { "Group \($0 + 1)" }, name: "Sample", values: values),
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(8), height: .inches(4)), options: options)
        return (deck, try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")).dom())
    }

    private func descendants(_ root: XML.Element, _ name: String) -> [XML.Element] {
        (root.name == name ? [root] : []) + root.childElements.flatMap { descendants($0, name) }
    }
    private func text(_ svg: String) throws -> [XML.Element] { descendants(try XML.parse(Data(svg.utf8)), "text") }
    private func style(_ hex: String, size: Int, extra: String = "") throws -> XML.Element {
        try XML.parse(Data("""
        <c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="\(size)" \(extra)>
        <a:solidFill><a:srgbClr val="\(hex)"/></a:solidFill><a:latin typeface="Chosen Font"/>
        </a:defRPr></a:pPr></a:p></c:txPr>
        """.utf8))
    }

    @Test func savedChartsKeepLiteralPercentLabelsAndTheirSourceStyle() throws {
        let (deck, root) = try make(options: ChartOptions(
            dataLabels: DataLabelOptions(showValue: true, numberFormat: #"0"%""#, position: "outEnd"),
            valueAxis: AxisOptions(min: 0, max: 40, majorUnit: 10, numberFormat: #"0"%""#)))
        root.removeChildren(named: "c:txPr")
        root.appendElement(try style("FFFFFF", size: 1300))
        let plot = try #require(descendants(root, "c:barChart").first)
        let labels = try #require(plot.firstChild(named: "c:dLbls"))
        labels.appendElement(try style("FFAA00", size: 1500, extra: "b=\"1\" i=\"1\""))
        let part = try deck.package.part(at: PackURI("/ppt/charts/chart1.xml")); part.markDirty()
        let saved = try deck.serializedData()
        let reopened = try Presentation(data: saved)
        let svg = try reopened.renderSVG(slideAt: 0)
        let texts = try text(svg)
        #expect(texts.contains { $0.textContent == "20%" && $0[attribute: "fill"] == "#FFFFFF" && $0[attribute: "font-size"] == "13" })
        #expect(!texts.contains { $0.textContent == "2000%" })
        for value in ["17%", "31%"] {
            let label = try #require(texts.first { $0.textContent == value })
            #expect(label[attribute: "fill"] == "#FFAA00")
            #expect(label[attribute: "font-size"] == "15")
            #expect(label[attribute: "font-weight"] == "bold")
            #expect(label[attribute: "font-style"] == "italic")
            #expect(label[attribute: "font-family"]?.contains("Chosen Font") == true)
        }
        #expect(try reopened.serializedData() == saved)
        #expect(try reopened.renderSVG(slideAt: 0) == svg)
        #expect(try reopened.validate().isEmpty)
    }

    @Test func seriesAndPointLabelOverridesCanSuppressAndRestyleValues() throws {
        let (deck, root) = try make(values: [17, 31, 42], options: ChartOptions(dataLabels: DataLabelOptions(showValue: true)))
        let series = try #require(descendants(root, "c:ser").first)
        series.appendElement(try XML.parse(Data("""
        <c:dLbls><c:dLbl><c:idx val="1"/><c:delete val="1"/></c:dLbl>
        <c:dLbl><c:idx val="2"/><c:numFmt formatCode='0"K"' sourceLinked="0"/></c:dLbl>
        <c:numFmt formatCode='0"%"' sourceLinked="0"/></c:dLbls>
        """.utf8)))
        let texts = try text(deck.renderSVG(slideAt: 0)).map(\.textContent)
        #expect(texts.contains("17%"))
        #expect(!texts.contains("31%"))
        #expect(texts.contains("42K"))
    }

    @Test func lineMarkersSurviveAndPointNoneOverrideIsRespected() throws {
        let (deck, root) = try make(.line, values: [329, 502, 488, 429])
        let series = try #require(descendants(root, "c:ser").first)
        series.removeChildren(named: "c:marker")
        series.appendElement(try XML.parse(Data("<c:marker><c:symbol val=\"circle\"/><c:size val=\"8\"/></c:marker>".utf8)))
        series.appendElement(try XML.parse(Data("<c:dPt><c:idx val=\"1\"/><c:marker><c:symbol val=\"none\"/></c:marker></c:dPt>".utf8)))
        series.appendElement(try XML.parse(Data("<c:dPt><c:idx val=\"2\"/><c:marker><c:spPr><a:solidFill><a:srgbClr val=\"FFAA00\"/></a:solidFill></c:spPr></c:marker></c:dPt>".utf8)))
        let svg = try XML.parse(Data(deck.renderSVG(slideAt: 0).utf8))
        #expect(descendants(svg, "circle").count == 3)
        #expect(descendants(svg, "circle").allSatisfy { $0[attribute: "r"] == "50800" })
        #expect(descendants(svg, "circle").filter { $0[attribute: "fill"] == "#FFAA00" }.count == 1)
        #expect(descendants(svg, "polyline").first?[attribute: "points"]?.split(separator: " ").count == 4)
    }

    @Test func limitsOnlyReportOmissionWhenTheyActuallyDiscardPoints() throws {
        let (small, _) = try make()
        #expect(try !small.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.contains { $0.impact == .omission })
        let (large, _) = try make(values: Array(repeating: 3, count: 513))
        #expect(try large.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.contains {
            $0.impact == .omission && $0.message.contains("512")
        })
    }

    @Test func outsideLabelsFollowPositiveAndNegativeBarEndsInBothOrientations() throws {
        for horizontal in [false, true] {
            let (deck, root) = try make(values: [17, -31], options: ChartOptions(
                dataLabels: DataLabelOptions(showValue: true, numberFormat: "0\" units\"", position: "outEnd")))
            let plot = try #require(descendants(root, "c:barChart").first)
            plot.firstChild(named: "c:barDir")?[attribute: "val"] = horizontal ? "bar" : "col"
            let svg = try XML.parse(Data(deck.renderSVG(slideAt: 0).utf8))
            let bars = descendants(svg, "rect").filter { $0[attribute: "fill"] != "#FFFFFF" }
            #expect(bars.count == 2)
            let labels = descendants(svg, "text").filter { $0.textContent.hasSuffix(" units") }
            #expect(labels.count == 2)
            for (index, value) in ["17 units", "-31 units"].enumerated() {
                let label = try #require(labels.first { $0.textContent == value })
                let origin = try #require(label[attribute: "transform"]?.split(separator: "(").dropFirst().first?.split(separator: ")").first)
                let xy = origin.split(separator: ",").compactMap { Double($0) }
                let bar = bars[index]
                let edge = try #require(Double(bar[attribute: horizontal ? "x" : "y"] ?? ""))
                let length = try #require(Double(bar[attribute: horizontal ? "width" : "height"] ?? ""))
                if horizontal {
                    #expect(index == 0 ? xy[0] > edge + length : xy[0] < edge)
                    #expect(label[attribute: "text-anchor"] == (index == 0 ? "start" : "end"))
                } else {
                    #expect(index == 0 ? xy[1] < edge : xy[1] > edge + length)
                }
            }
        }
    }
}
