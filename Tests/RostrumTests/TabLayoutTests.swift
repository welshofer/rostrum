import Foundation
import Testing
@testable import Rostrum

@Suite struct TabLayoutTests {
    private func body(_ text: String, properties: String = "", attributes: String = "", wrap: Bool = true) throws -> XML.Element {
        try XML.parse(Data("""
        <p:txBody><a:bodyPr lIns="0" tIns="0" rIns="0" bIns="0" wrap="\(wrap ? "square" : "none")"/>
        <a:p><a:pPr \(attributes)>\(properties)<a:defRPr sz="1000"/></a:pPr><a:r><a:t>\(text)</a:t></a:r></a:p></p:txBody>
        """.utf8))
    }
    private func layout(_ xml: XML.Element, width: Double = 300) throws -> RichTextLayout {
        RichTextLayout(textBody: xml, width: width, height: 1000, fallbackMetrics: try FontMetrics(data: TestFont.standard()))
    }

    @Test func standardAlignmentsAndPeriodAnchor() throws {
        for (alignment, expected) in [("l",60.0),("ctr",47.5),("r",35.0),("dec",50.0)] {
            let xml = try body("A\t12.34", properties: "<a:tabLst><a:tab pos=\"762000\" algn=\"\(alignment)\"/></a:tabLst>")
            let result = try layout(xml)
            #expect(result.lines[0].spans[1].x == expected)
            #expect(result.diagnostics.isEmpty)
        }
    }

    @Test func lastTabProtectsEarlierWordSpacingAndExplicitBreakJustifies() throws {
        let xml = try body("A B\tC D\tE F\nG", properties: "<a:tabLst><a:tab pos=\"254000\"/><a:tab pos=\"508000\"/></a:tabLst>", attributes: "algn=\"just\"")
        let result = try layout(xml, width: 80)
        #expect(result.lines[0].spans.map(\.run.text) == ["A B", "C D", "E", " ", "F"])
        #expect(result.lines[0].spans.map(\.x) == [0,20,40,45,75])
        #expect(result.lines[1].spans[0].x == 0)
        #expect(result.diagnostics.isEmpty)
    }

    @Test func fullFieldAlignmentSurvivesWrappingAndNoWrapReportsOverflow() throws {
        let properties = "<a:tabLst><a:tab pos=\"762000\" algn=\"r\"/></a:tabLst>"
        let text = "A\tBBBB CCCC DDDD EEEE FFFF"
        let wrapped = try layout(body(text, properties: properties), width: 80)
        #expect(wrapped.lines.count == 2)
        #expect(wrapped.lines[0].spans[1].x == 5)
        let unwrapped = try layout(body(text, properties: properties, wrap: false), width: 80)
        #expect(unwrapped.lines.count == 1)
        #expect(unwrapped.lines[0].spans[1].x == 5)
        #expect(!unwrapped.fits)
    }

    @Test func tabAPIReadsWithoutMutationAndRoundTripsUnknownXML() throws {
        let deck = try Presentation()
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x: .zero,y: .zero,width: .points(300),height: .points(100)))
        let frame = try #require(shape.textFrame); frame.text = "A\t12.34"
        let paragraph = try #require(frame.paragraphs.first)
        let before = try deck.serializedData()
        #expect(paragraph.tabStops == nil && paragraph.defaultTabInterval == nil)
        #expect(try deck.serializedData() == before)
        paragraph.tabStops = [TextTabStop(position: .points(120),alignment: .decimal),TextTabStop(position: .points(60),alignment: .center)]
        paragraph.defaultTabInterval = .points(48)
        let list = try #require(paragraph.p.firstChild(named: "a:pPr")?.firstChild(named: "a:tabLst"))
        list.appendElement(XML.Element("custom:future", attributes: [("xmlns:custom","urn:rostrum:test"),("data","unchanged")]))
        paragraph.tabStops = [TextTabStop(position: .points(90),alignment: .right)]
        #expect(list.firstChild(named: "custom:future")?[attribute:"data"] == "unchanged")
        let saved = try deck.serializedData()
        _ = RichTextLayout(textBody: frame.txBody, width:300,height:100)
        _ = try deck.renderSVGReportingProblems(slideAt:0)
        #expect(try deck.serializedData() == saved)
        let reopened = try Presentation(data:saved)
        let reread = try #require(reopened.slides[0].shapes.first(where: { _ in true })?.textFrame?.paragraphs.first)
        #expect(reread.tabStops == paragraph.tabStops && reread.defaultTabInterval == .points(48))
        paragraph.tabStops = []; #expect(paragraph.tabStops == [])
        paragraph.tabStops = nil; #expect(paragraph.tabStops == nil)
        paragraph.defaultTabInterval = EMU(-1); #expect(paragraph.defaultTabInterval == EMU(1))
        paragraph.tabStops = [TextTabStop(position:EMU(-1)),TextTabStop(position:EMU(Int.max))]
        #expect(paragraph.tabStops?.map(\.position) == [.zero,EMU(Int(Int32.max))])
    }

    @Test func defaultIntervalBoundariesAgreeAcrossWriteReopenAndLayout() throws {
        let deck = try Presentation()
        let shape = try deck.slides[0].shapes.addTextBox(Rect(x:.zero,y:.zero,width:.points(300),height:.points(100)))
        let frame = try #require(shape.textFrame)
        frame.text = "A\tB"
        frame.wordWrap = false
        frame.setMargins(left:.zero,top:.zero,right:.zero,bottom:.zero)
        frame.paragraphs[0].runs[0].fontSize = 10
        let intervals = [EMU(1),EMU(Int(Int32.max))]
        let expectedStarts = [5 + 1.0 / Double(EMU.perPoint), Double(Int32.max) / Double(EMU.perPoint)]
        for (interval, expected) in zip(intervals,expectedStarts) {
            frame.paragraphs[0].defaultTabInterval = interval
            let reopened = try Presentation(data:deck.serializedData())
            let savedFrame = try #require(reopened.slides[0].shapes.first(where:{ _ in true })?.textFrame)
            #expect(savedFrame.paragraphs[0].defaultTabInterval == interval)
            let result = try layout(savedFrame.txBody)
            #expect(abs(result.lines[0].spans[1].x - expected) < 0.000001)
            #expect(result.lines.count == 1)
            #expect(result.fits == (interval.rawValue == 1))
        }
    }

    @Test func unsupportedTabScriptsAreExplicitAndInputRemainsUntouched() throws {
        for (text, attributes) in [("A\t中文",""),("A\tB","rtl=\"true\"")] {
            let xml = try body(text,properties:"<a:tabLst><a:tab pos=\"762000\" algn=\"r\"/></a:tabLst>",attributes:attributes)
            let result = try layout(xml)
            #expect(result.diagnostics.contains { if case .unsupportedLayoutFeature(let reason) = $0 { return reason.hasPrefix("Tab alignment outside") }; return false })
            #expect(result.lines[0].spans[1].x == 60)
            let collector = RenderDiagnosticCollector()
            collector.text(result)
            #expect(collector.issues.contains { $0.code == .unsupportedTextProperty && $0.message.hasPrefix("Tab alignment outside") })
        }
        let xml = try body("A\tB")
        let inherited = try XML.parse(Data("<a:lstStyle><a:lvl1pPr><a:tabLst><a:tab pos=\"762000\" algn=\"future\"/></a:tabLst></a:lvl1pPr></a:lstStyle>".utf8))
        xml.insertChild(inherited,beforeAnyOf:["a:p"])
        let collector = RenderDiagnosticCollector()
        collector.text(try layout(xml))
        #expect(collector.issues.count == 1)
        #expect(collector.issues.first?.code == .unsupportedTextProperty)
        #expect(collector.issues.first?.message.hasPrefix("Unknown tab alignment") == true)
    }

    @Test func nativePowerPointTabGeometry() throws {
        struct Capture: Decodable {
            struct Face: Decodable { let unitsPerEm:Int; let advances:[Int]; let kern:[[Int]] }
            struct Case: Decodable {
                struct Line:Decodable { struct Word:Decodable { let text:String; let x:Double; let end:Double }; let words:[Word] }
                let name:String; let source:String; let page:Int; let width:Double; let height:Double; let lines:[Line]
            }
            let fonts:[Face]; let cases:[Case]; let tolerancePoints:Double
        }
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/TabLayout")
        let capture = try JSONDecoder().decode(Capture.self,from:Data(contentsOf:root.appendingPathComponent("native-geometry.json")))
        let fonts = FontLibrary()
        for (index, face) in capture.fonts.enumerated() {
            let advances:[Int] = [face.unitsPerEm / 2] + face.advances
            var os2 = TestFont.os2(useTypoMetrics:false)
            os2.replaceSubrange(62..<64,with:TestFont.be16(index == 1 ? 0x20 : 0x40))
            let header:[Int] = [0,1,0,14 + face.kern.count * 6,1,face.kern.count,0,0,0]
            var kern = header.flatMap { TestFont.be16($0) }
            kern += face.kern.flatMap { $0.flatMap { TestFont.be16($0) } }
            let data = Data(TestFont.assemble(tables:[
                ("head",TestFont.head(upem:face.unitsPerEm)),
                ("hhea",TestFont.hhea(ascender:1600,descender:-400,lineGap:0,numberOfHMetrics:advances.count)),
                ("maxp",TestFont.maxp(numGlyphs:advances.count)),("hmtx",TestFont.hmtx(advances:advances)),
                ("cmap",TestFont.cmapFormat4()),("OS/2",os2),("kern",kern)
            ]))
            try fonts.register(data,aliases:["Arial"])
        }
        var decks: [String: Presentation] = [:]
        for source in Set(capture.cases.map(\.source)) {
            let imported = try Presentation(contentsOf:root.appendingPathComponent(source))
            // Force modeled writes before the oracle comparison. This exercises
            // the public setter, package writer and reopened paragraph together.
            for slide in imported.slides {
                for shape in slide.shapes {
                    for paragraph in shape.textFrame?.paragraphs ?? [] {
                        if let stops = paragraph.tabStops { paragraph.tabStops = stops }
                    }
                }
            }
            let saved = try imported.serializedData()
            let reopened = try Presentation(data:saved)
            #expect(try reopened.serializedData() == saved)
            decks[source] = reopened
            // Explicit fixture-maintenance invocation also retains written decks
            // for native PowerPoint acceptance. Ordinary test runs only use memory.
            if let destination = ProcessInfo.processInfo.environment["ROSTRUM_TAB_ORACLE_EXPORT"] {
                try saved.write(to:URL(fileURLWithPath:destination).appendingPathComponent("rostrum-" + source))
            }
        }
        for oracle in capture.cases {
            let deck = try #require(decks[oracle.source])
            let shape = try #require(deck.slides[oracle.page].shapes.first { $0.name == oracle.name })
            let frame = try #require(shape.textFrame)
            let result = RichTextLayout(textBody:frame.txBody,width:oracle.width,height:oracle.height,fonts:fonts)
            #expect(result.lines.count == oracle.lines.count, "\(oracle.name) line count")
            for (line, expected) in zip(result.lines,oracle.lines) {
                var actual:[(text:String,x:Double,end:Double)] = []
                for span in line.spans where span.run.text != "• " {
                    let font = try #require(fonts.metrics(for:"Arial",bold:span.run.bold,italic:span.run.italic))
                    let shaped = TextShaper(font).shape(span.run.text,pointSize:span.run.fontSize)
                    let scalars = Array(span.run.text.unicodeScalars)
                    var x = span.x
                    for glyph in shaped.glyphs {
                        let text = String(String.UnicodeScalarView(scalars[glyph.scalarRange]))
                        if text != " " { actual.append((text,x,x+font.width(of:text,pointSize:span.run.fontSize))) }
                        x += glyph.advance + span.run.tracking * Double(text.count)
                    }
                }
                var offset = 0
                for word in expected.words {
                    let count = word.text.count
                    guard offset+count <= actual.count else { Issue.record("\(oracle.name) missing \(word.text)"); break }
                    let letters = Array(actual[offset..<offset+count])
                    #expect(letters.map(\.text).joined() == word.text,"\(oracle.name) word")
                    #expect(abs(letters[0].x-word.x) <= capture.tolerancePoints,"\(oracle.name) \(word.text) start \(letters[0].x) vs \(word.x)")
                    #expect(abs(letters[count-1].end-word.end) <= capture.tolerancePoints,"\(oracle.name) \(word.text) end")
                    offset += count
                }
                #expect(offset == actual.count, "\(oracle.name) extra glyphs")
            }
            #expect(result.diagnostics.isEmpty,"\(oracle.name) diagnostics")
        }
    }
}
