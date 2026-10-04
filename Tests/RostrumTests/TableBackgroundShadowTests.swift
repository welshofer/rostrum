import Foundation
import Testing
@testable import Rostrum

@Suite struct TableBackgroundShadowTests {
    private func make(effect: String, reference: Bool = false) throws -> (Presentation, Table) {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 2, columns: 2,
            frame: Rect(x: .points(20), y: .points(30), width: .points(200), height: .points(100)))
        table.clearBuiltInStyle()
        let choice: String
        if reference {
            let list = try #require(deck.theme.part.dom().firstChild(named: "a:themeElements")?
                .firstChild(named: "a:fmtScheme")?.firstChild(named: "a:effectStyleLst"))
            list.children = [.element(try XML.parse(Data("<a:effectStyle>\(effect)</a:effectStyle>".utf8)))]
            deck.theme.part.markDirty()
            choice = "<a:effectRef idx=\"1\"><a:schemeClr val=\"accent1\"><a:alpha val=\"50000\"/></a:schemeClr></a:effectRef>"
        } else { choice = "<a:effect>\(effect)</a:effect>" }
        try table.setStyleDefinition(XML.parse(Data("""
        <a:tblStyle xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" styleId="{11111111-2222-3333-4444-555555555555}" styleName="Shadow">
        <a:tblBg><a:fill><a:solidFill><a:srgbClr val="EEEEEE"/></a:solidFill></a:fill>\(choice)</a:tblBg>
        <a:wholeTbl><a:tcStyle><a:tcBdr/><a:fill><a:noFill/></a:fill></a:tcStyle></a:wholeTbl>
        </a:tblStyle>
        """.utf8)))
        return (deck, table)
    }

    @Test func directShadowPreservesGeometryAlphaAndSourceBytes() throws {
        let (deck, table) = try make(effect: """
        <a:effectLst><a:outerShdw blurRad="50800" dist="38100" dir="5400000"><a:srgbClr val="123456"><a:alpha val="25000"/></a:srgbClr></a:outerShdw></a:effectLst>
        """)
        try table.cell(0, 0).setBorder(.diagonalDown, line: Line(color: .black, width: .points(10)))
        try table.cell(0, 0).text = "outside the shadow group"
        let before = try deck.serializedData()
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        let root = try XML.parse(Data(report.svg.utf8))
        let filter = try #require(root.firstChild(named: "defs")?.firstChild(named: "filter"))
        #expect(filter[attribute: "filterUnits"] == "userSpaceOnUse")
        #expect(filter[attribute: "x"] == "76200") // 20pt - (3 sigma + 3pt offset + 5pt border).
        #expect(filter.firstChild(named: "feGaussianBlur")?[attribute: "stdDeviation"] == "25400")
        #expect(filter.firstChild(named: "feOffset")?[attribute: "dx"].flatMap(Double.init) == 0)
        #expect(filter.firstChild(named: "feOffset")?[attribute: "dy"] == "38100")
        #expect(filter.firstChild(named: "feFlood")?[attribute: "flood-color"] == "#123456")
        #expect(filter.firstChild(named: "feFlood")?[attribute: "flood-opacity"].flatMap(Double.init) == 0.25)
        let group = try #require(root.childElements.first { $0.name == "g" && $0[attribute: "filter"] != nil })
        #expect(group.childElements.contains { $0.name == "line" })
        #expect(!group.childElements.contains { $0.name == "text" })
        #expect(root.childElements.contains { $0.name == "text" })
        let effects = report.problems.fidelityIssues.filter { $0.code == .omittedEffect }
        #expect(effects.count == 1 && effects[0].impact == .approximation)
        #expect(effects[0].location.path.hasSuffix("/a:tblBg[1]/a:effect[1]/a:effectLst[1]"))
        #expect(throws: StrictRenderingError.self) { try deck.renderSVG(slideAt: 0, strictRendering: true) }
        #expect(try deck.serializedData() == before)
        let reopened = try Presentation(data: before)
        #expect(try reopened.renderSVG(slideAt: 0) == report.svg)
    }

    @Test func themePlaceholderTransformsStayLiveAndLocated() throws {
        let (deck, table) = try make(effect: """
        <a:effectLst><a:outerShdw blurRad="40000" dist="20000" dir="10800000"><a:schemeClr val="phClr"><a:alphaMod val="50000"/></a:schemeClr></a:outerShdw></a:effectLst>
        """, reference: true)
        deck.theme.setAccent(1, Color("FF0000"))
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        let filter = try #require(XML.parse(Data(report.svg.utf8)).firstChild(named: "defs")?.firstChild(named: "filter"))
        #expect(filter.firstChild(named: "feFlood")?[attribute: "flood-color"] == "#FF0000")
        #expect(filter.firstChild(named: "feFlood")?[attribute: "flood-opacity"].flatMap(Double.init) == 0.25)
        #expect(filter.firstChild(named: "feOffset")?[attribute: "dx"].flatMap(Double.init) == -20000)
        #expect(filter.firstChild(named: "feOffset")?[attribute: "dy"].flatMap(Double.init) == 0)
        let issue = try #require(report.problems.fidelityIssues.first { $0.code == .omittedEffect })
        #expect(issue.impact == .approximation)
        #expect(issue.location.partURI == deck.theme.part.uri.description)
        #expect(issue.location.path.hasSuffix("/a:effectStyle[1]/a:effectLst[1]"))
        deck.theme.setAccent(1, Color("00FF00"))
        #expect(try deck.renderSVG(slideAt: 0).contains("flood-color=\"#00FF00\""))
        #expect(TableStyleResolver(table: table, theme: deck.theme).backgroundShadow()?.fromTheme == true)
    }

    @Test(arguments: ["scale", "skew", "blur-overflow", "negative-distance", "bad-direction", "no-color", "chain", "3d"])
    func unsupportedShadowsRemainOmitted(_ variant: String) throws {
        let attributes: String
        switch variant {
        case "scale": attributes = "sx=\"90000\""
        case "skew": attributes = "ky=\"60000\""
        case "blur-overflow": attributes = "blurRad=\"9223372036854775807\""
        case "negative-distance": attributes = "dist=\"-1\""
        case "bad-direction": attributes = "dir=\"oops\""
        default: attributes = ""
        }
        let color = variant == "no-color" ? "" : "<a:srgbClr val=\"000000\"/>"
        let extra = variant == "chain" ? "<a:glow rad=\"1000\"><a:srgbClr val=\"FF0000\"/></a:glow>" : ""
        let effect = "<a:effectLst><a:outerShdw \(attributes)>\(color)</a:outerShdw>\(extra)</a:effectLst>"
            + (variant == "3d" ? "<a:scene3d><a:camera prst=\"orthographicFront\"/></a:scene3d>" : "")
        let (deck, _) = try make(effect: effect, reference: true)
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(!report.svg.contains("<filter"))
        #expect(report.problems.fidelityIssues.contains { $0.code == .omittedEffect && $0.impact == .omission })
        #expect(!report.problems.fidelityIssues.contains { $0.code == .omittedEffect && $0.impact == .approximation })
    }

    @Test func officeStyleControlsUseOneShadowAcrossTheTableIncludingRTL() throws {
        for name in ["style-precedence", "style-precedence-rtl"] {
            let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("Fixtures/DoubleTableBorders/\(name).pptx")
            let deck = try Presentation(contentsOf: url)
            for index in 24..<36 {
                let report = try deck.renderSVGReportingProblems(slideAt: index)
                #expect(report.svg.components(separatedBy: "<filter").count - 1 == 1)
                #expect(report.svg.contains("stdDeviation=\"20000\""))
                #expect(report.svg.contains("dy=\"20000\""))
                let effects = report.problems.fidelityIssues.filter { $0.code == .omittedEffect }
                #expect(effects.count == 1 && effects[0].impact == .approximation)
            }
        }
    }
}
