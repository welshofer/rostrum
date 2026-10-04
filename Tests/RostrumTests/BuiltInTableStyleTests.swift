import Foundation
import Testing
@testable import Rostrum

@Suite struct BuiltInTableStyleTests {
    private func make() throws -> (Presentation, Table) {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 5, columns: 4,
            frame: Rect(x: .zero, y: .zero, width: .inches(8), height: .inches(4)))
        return (deck, table)
    }

    @Test func nativeGUIDsAreUniqueAndDefinitionsAreIndependent() throws {
        #expect(BuiltInTableStyle.allCases.count == 74)
        #expect(Set(BuiltInTableStyle.allCases.map(\.rawValue)).count == 74)
        for style in BuiltInTableStyle.allCases {
            #expect(BuiltInTableStyle(id: " \n" + style.rawValue.lowercased() + "\t") == style)
            let first = try #require(style.definition()), second = try #require(style.definition())
            #expect(first[attribute: "styleId"] == style.rawValue)
            #expect(first[attribute: "styleName"] == style.name)
            #expect(first.firstChild(named: "a:wholeTbl") != nil)
            first.children = []
            #expect(!second.children.isEmpty)
        }
        #expect(BuiltInTableStyle(id: "unknown") == nil)
    }

    @Test func everyNativeStyleResolvesWithoutEmbeddingOrMutatingThePackage() throws {
        let (deck, table) = try make()
        for style in BuiltInTableStyle.allCases {
            table.applyBuiltInStyle(style)
            let before = try deck.serializedData()
            let resolver = TableStyleResolver(table: table, theme: deck.theme)
            #expect(table.builtInStyle == style)
            #expect(resolver.hasStyleDefinition)
            for row in 0..<5 { for column in 0..<4 {
                _ = try resolver.fill(row: row, column: column)
                _ = try resolver.border(.left, row: row, column: column)
            } }
            let report = try deck.renderSVGReportingProblems(slideAt: 0)
            #expect(!report.problems.fidelityIssues.contains { $0.code == .unresolvedTableStyle })
            #expect(try deck.serializedData() == before)
            let reopened = try Presentation(data: before)
            let copied = try #require((reopened.slides[0].shapes.all.first as? TableFrame)?.table)
            #expect(copied.builtInStyle == style)
            #expect(try reopened.serializedData() == before)
        }
    }

    @Test func noGridAndTableGridHaveDistinctBordersAndClearRemovesInlineChoice() throws {
        let (deck, table) = try make()
        table.applyBuiltInStyle(.noStyleTableGrid)
        #expect(try TableStyleResolver(table: table, theme: deck.theme).border(.left, row: 1, column: 1)?.isNone == false)
        let pr = try #require(table.tbl.firstChild(named: "a:tblPr"))
        pr.appendElement(XML.Element("a:tableStyle"))
        let ext = XML.Element("a:extLst", children: [.comment("keep extension")])
        pr.appendElement(ext)
        #expect(table.builtInStyle == nil)
        table.clearBuiltInStyle()
        #expect(table.builtInStyle == .noStyleNoGrid)
        #expect(pr.firstChild(named: "a:tableStyle") == nil)
        #expect(pr.childElements.last === ext)
        #expect(try TableStyleResolver(table: table, theme: deck.theme).border(.left, row: 1, column: 1)?.isNone == true)
        #expect(!table.firstRowHeader && !table.bandedRows)
    }

    @Test func flagsThemeAndDirectFormattingRemainLive() throws {
        let (deck, table) = try make()
        table.firstRowHeader = true; table.bandedRows = true
        table.applyBuiltInStyle(.mediumStyle2Accent1)
        #expect(table.firstRowHeader && table.bandedRows)
        deck.theme.setAccent(1, Color("123456"))
        func fillColor(_ row: Int) throws -> Color? {
            if case .solid(let color, _) = try TableStyleResolver(table: table, theme: deck.theme).fill(row: row, column: 1) { return color }
            return nil
        }
        #expect(try fillColor(0) == Color("123456"))
        deck.theme.setAccent(1, Color("ABCDEF"))
        #expect(try fillColor(0) == Color("ABCDEF"))
        try table.cell(0, 1).setFill(.solid(Color("FEDCBA")))
        #expect(try fillColor(0) == Color("FEDCBA"))
        table.firstRowHeader = false
        #expect(try fillColor(0) == Color("FEDCBA"))
    }

    @Test func embeddedDefinitionsOverrideNativeFallbackAndDefaultReferencesResolve() throws {
        let (deck, table) = try make()
        let definition = try #require(BuiltInTableStyle.noStyleNoGrid.definition())
        let whole = try #require(definition.firstChild(named: "a:wholeTbl")?.firstChild(named: "a:tcStyle"))
        whole.removeChildren(named: "a:fill")
        whole.appendElement(try XML.parse(Data("<a:fill><a:solidFill><a:srgbClr val=\"123456\"/></a:solidFill></a:fill>".utf8)))
        try table.setStyleDefinition(definition)
        #expect(try TableStyleResolver(table: table, theme: deck.theme).fill(row: 2, column: 2) == .solid(Color("123456"), alpha: 1))
        let main = try deck.package.mainDocumentPart()
        let styles = try main.related(by: RelType.tableStyles, in: deck.package)
        let root = try styles.dom()
        root[attribute: "def"] = BuiltInTableStyle.mediumStyle2Accent1.rawValue
        table.styleID = nil
        #expect(TableStyleResolver(table: table, theme: deck.theme).hasStyleDefinition)
        #expect(try !deck.renderSVGReportingProblems(slideAt: 0).problems.fidelityIssues.contains { $0.code == .unresolvedTableStyle })
    }

    @Test func themeReferencedImagesUseTheThemeRelationshipOwner() throws {
        let (deck, table) = try make()
        table.applyBuiltInStyle(.themedStyle1Accent1)
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==")!
        _ = deck.package.addPart(uri: PackURI("/ppt/media/theme-image.png"), contentType: "image/png", blob: png)
        let rid = deck.theme.part.rels.add(type: RelType.image, target: "../media/theme-image.png")
        let fills = try #require(try deck.theme.part.dom().firstChild(named: "a:themeElements")?.firstChild(named: "a:fmtScheme")?.firstChild(named: "a:fillStyleLst"))
        fills.children[1] = .element(try XML.parse(Data("<a:blipFill><a:blip r:embed=\"\(rid)\"/><a:stretch><a:fillRect/></a:stretch></a:blipFill>".utf8)))
        deck.theme.part.markDirty()
        let resolver = TableStyleResolver(table: table, theme: deck.theme)
        #expect(resolver.background().owner === deck.theme.part)
        let before = try deck.serializedData()
        var report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(report.svg.contains("data:image/png;base64,"))
        #expect(!report.problems.fidelityIssues.contains { $0.code == .unsupportedImage || $0.code == .unavailableImage })
        #expect(try deck.serializedData() == before)
        let inline = try #require(BuiltInTableStyle.noStyleNoGrid.definition())
        inline.name = "a:tableStyle"
        let style = try #require(inline.firstChild(named: "a:wholeTbl")?.firstChild(named: "a:tcStyle"))
        style.removeChildren(named: "a:fill")
        style.appendElement(try XML.parse(Data("<a:fillRef idx=\"2\"><a:schemeClr val=\"accent1\"/></a:fillRef>".utf8)))
        let pr = try #require(table.tbl.firstChild(named: "a:tblPr"))
        pr.removeChildren(named: "a:tableStyleId"); pr.appendElement(inline)
        #expect(TableStyleResolver(table: table, theme: deck.theme).effective(row: 1, column: 1).fillOwner === deck.theme.part)
        report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(report.svg.contains("data:image/png;base64,"))
        #expect(!report.problems.fidelityIssues.contains { $0.code == .unsupportedImage || $0.code == .unavailableImage })
        // The same relationship token on a slide remains independent.
        try table.cell(1, 1).setFill(.image(png, fit: .stretch))
        #expect(TableStyleResolver(table: table, theme: deck.theme).effective(row: 1, column: 1).fillOwner === table.part)
        deck.theme.part.rels.remove(rId: rid)
        report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(report.problems.fidelityIssues.contains {
            $0.code == .unavailableImage && $0.location.partURI == deck.theme.part.uri.description
                && $0.location.path == "/a:theme/a:themeElements/a:fmtScheme/a:fillStyleLst/a:blipFill[1]/a:blip[1]"
        })
    }

    @Test func nativeThemeEffectsRemainExplicitPreviewOmissions() throws {
        let (deck, table) = try make()
        table.applyBuiltInStyle(.themedStyle2Accent1)
        let report = try deck.renderSVGReportingProblems(slideAt: 0)
        #expect(report.problems.fidelityIssues.contains { $0.code == .omittedEffect })
        #expect(!report.problems.fidelityIssues.contains { $0.code == .unresolvedTableStyle })
    }
}
