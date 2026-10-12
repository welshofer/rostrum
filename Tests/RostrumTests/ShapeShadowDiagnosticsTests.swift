import Foundation
import Testing
@testable import Rostrum

@Suite struct ShapeShadowDiagnosticsTests {
    private let shadow = """
    <a:outerShdw blurRad="40000" dist="20000" dir="5400000"><a:srgbClr val="112233"><a:alpha val="38000"/></a:srgbClr></a:outerShdw>
    """

    private func make(theme: Bool, extra: String = "", properties: String = "",
                      shadowOverride: String? = nil) throws -> Presentation {
        let deck = try Presentation()
        let shape = try deck.slides[0].shapes.addShape(.rectangle,
            frame: Rect(x: .points(20), y: .points(30), width: .points(200), height: .points(100)),
            fill: .solid(Color("CC4400")))
        let effects = try XML.parse(Data("<a:effectLst>\(shadowOverride ?? shadow)\(extra)</a:effectLst>".utf8))
        let spPr = try #require(shape.element.firstChild(named: "p:spPr"))
        if theme {
            let styles = try #require(deck.theme.part.dom().firstChild(named: "a:themeElements")?
                .firstChild(named: "a:fmtScheme")?.firstChild(named: "a:effectStyleLst"))
            styles.children = [.element(XML.Element("a:effectStyle", children: [.element(effects)]))]
            deck.theme.part.markDirty()
            shape.element.appendElement(try XML.parse(Data("<p:style><a:effectRef idx=\"1\"/></p:style>".utf8)))
        } else {
            spPr.appendElement(effects)
        }
        if !properties.isEmpty { spPr.appendElement(try XML.parse(Data(properties.utf8))) }
        shape.part.markDirty()
        return deck
    }

    @Test(arguments: [false, true])
    func renderedShadowsReportApproximationAndStillRefuseStrictMode(_ theme: Bool) throws {
        let deck = try make(theme: theme)
        let before = try deck.serializedData()
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(report.svg.contains("<filter "))
        let issue = try #require(report.problems.fidelityIssues.only)
        #expect(issue.code == .omittedEffect && issue.impact == .approximation)
        #expect(issue.message.contains("outer shadow") && issue.message.contains("approximated"))
        #expect(issue.location.path.hasSuffix(theme ? "/p:style/a:effectRef" : "/p:spPr[1]/a:effectLst[1]"))
        #expect(issue.location.partURI == (try deck.slides[0].part.uri.description))
        do {
            _ = try deck.renderSVG(slideAt: 0, strictRendering: true)
            Issue.record("Strict rendering accepted an approximated shadow")
        } catch let error as StrictRenderingError {
            #expect(error.problems.fidelityIssues == report.problems.fidelityIssues)
        }
        #expect(try deck.serializedData() == before)
        let reopened = try Presentation(data: before)
        let repeatReport = try reopened.renderSVGReportingProblems(slideAt: 0)
        #expect(repeatReport.svg == report.svg)
        #expect(repeatReport.problems.fidelityIssues == report.problems.fidelityIssues)
    }

    @Test(arguments: [false, true], ["scale", "missing-color", "transparent", "glow"])
    func unsupportedOrUnrenderedEffectsRemainOmissions(_ theme: Bool, _ variant: String) throws {
        let custom = variant == "scale" ? shadow.replacingOccurrences(of: "blurRad=", with: "sx=\"50000\" blurRad=")
            : variant == "missing-color" ? "<a:outerShdw blurRad=\"40000\"/>"
            : variant == "transparent" ? shadow.replacingOccurrences(of: "38000", with: "0") : shadow
        let extra = variant == "glow" ? "<a:glow rad=\"10000\"><a:srgbClr val=\"FF0000\"/></a:glow>" : ""
        let deck = try make(theme: theme, extra: extra, shadowOverride: custom)
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(report.problems.fidelityIssues.contains { $0.code == .omittedEffect && $0.impact == .omission })
        #expect(!report.problems.fidelityIssues.contains { $0.code == .omittedEffect && $0.impact == .approximation })
        #expect(report.svg.contains("<filter ") == (variant == "glow"))
    }

    @Test func additionalThemeComponentsKeepTheReferenceAnOmission() throws {
        let deck = try make(theme: true)
        let style = try #require(deck.theme.part.dom().firstChild(named: "a:themeElements")?
            .firstChild(named: "a:fmtScheme")?.firstChild(named: "a:effectStyleLst")?.firstChild(named: "a:effectStyle"))
        style.appendElement(try XML.parse(Data("<a:scene3d><a:camera prst=\"orthographicFront\"/></a:scene3d>".utf8)))
        deck.theme.part.markDirty()
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(report.svg.contains("<filter "))
        #expect(report.problems.fidelityIssues.contains { $0.code == .omittedEffect && $0.impact == .omission })
        #expect(!report.problems.fidelityIssues.contains { $0.impact == .approximation })
    }

    @Test func emptyOverrideSuppressesBothShadowAndDiagnostic() throws {
        let deck = try make(theme: true, properties: "<a:effectLst/>")
        let report = try deck.renderSVGReportingProblems(slideAt: 0, strictRendering: true)
        #expect(!report.svg.contains("<filter "))
        #expect(report.problems.isEmpty)
    }

    @Test func paintedGroupChildCannotHideAnotherChildsOmittedThemeComponent() throws {
        let deck = try make(theme: true)
        let style = try #require(deck.theme.part.dom().firstChild(named: "a:themeElements")?
            .firstChild(named: "a:fmtScheme")?.firstChild(named: "a:effectStyleLst")?.firstChild(named: "a:effectStyle"))
        style.appendElement(try XML.parse(Data("<a:scene3d><a:camera prst=\"orthographicFront\"/></a:scene3d>".utf8)))
        deck.theme.part.markDirty()
        let slide = try deck.slides[0]
        let tree = try #require(Slide.existingSpTree(of: slide.part))
        let first = try #require(tree.firstChild(named: "p:sp"))
        let second = first.deepCopy()
        second.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")?[attribute: "id"] = "3"
        second.firstChild(named: "p:spPr")?.appendElement(XML.Element("a:scene3d"))
        let group = try XML.parse(Data("""
        <p:grpSp><p:nvGrpSpPr><p:cNvPr id="100" name="Group"/></p:nvGrpSpPr>
        <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="5000000" cy="5000000"/>
        <a:chOff x="0" y="0"/><a:chExt cx="5000000" cy="5000000"/></a:xfrm></p:grpSpPr></p:grpSp>
        """.utf8))
        tree.removeChildren(named: "p:sp")
        group.appendElement(first); group.appendElement(second); tree.appendElement(group)
        slide.part.markDirty()
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(report.svg.components(separatedBy: "<filter ").count - 1 == 2)
        #expect(report.problems.fidelityIssues.contains { $0.code == .omittedEffect && $0.impact == .omission })
        let effects = report.problems.fidelityIssues.filter { $0.code == .omittedEffect }
        #expect(effects.map(\.location.shapeID) == ["2", "3"])
        #expect(effects.map(\.impact) == [.omission, .approximation])
    }
}

private extension Array {
    var only: Element? { count == 1 ? first : nil }
}
