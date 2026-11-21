import Foundation
import Testing
@testable import Rostrum

@Suite struct SVGSecurityHardeningTests {
    private static let minimalPNG = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )!

    @Test func shapeHyperlinksAllowOnlySafeSchemesAndPreserveValidActions() throws {
        let deck = try Presentation()
        let slide1 = try deck.slides[0]
        let slide2 = try deck.slides.add()

        let jsShape = try slide1.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(0.5), y: .inches(0.5), width: .inches(2), height: .inches(1)),
            fill: .solid(Color("DC2626"))
        )
        jsShape.setHyperlink("javascript:alert(1)")

        let tabJsShape = try slide1.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(3.0), y: .inches(0.5), width: .inches(2), height: .inches(1)),
            fill: .solid(Color("EA580C"))
        )
        tabJsShape.setHyperlink("\tJaVaScRiPt:alert(document.domain)")

        let dataShape = try slide1.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(5.5), y: .inches(0.5), width: .inches(2), height: .inches(1)),
            fill: .solid(Color("D97706"))
        )
        dataShape.setHyperlink("data:text/html,<script>alert(1)</script>")

        let badActionShape = try slide1.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(8.0), y: .inches(0.5), width: .inches(2), height: .inches(1)),
            fill: .solid(Color("7C3AED"))
        )
        let cNvPr = try #require(badActionShape.element.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr"))
        cNvPr.appendElement(XML.Element("a:hlinkClick", attributes: [("r:id", ""), ("action", "ppaction://program")]))
        slide1.part.markDirty()

        let safeWeb = try slide1.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(0.5), y: .inches(2.0), width: .inches(2), height: .inches(1)),
            fill: .solid(Color("2563EB"))
        )
        safeWeb.setHyperlink("https://example.com/safe")

        let safeMail = try slide1.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(3.0), y: .inches(2.0), width: .inches(2), height: .inches(1)),
            fill: .solid(Color("059669"))
        )
        safeMail.setHyperlink("mailto:security@example.com")

        let safeJump = try slide1.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(5.5), y: .inches(2.0), width: .inches(2), height: .inches(1)),
            fill: .solid(Color("0D9488"))
        )
        safeJump.setSlideLink(to: slide2)

        let safeAction = try slide1.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(8.0), y: .inches(2.0), width: .inches(2), height: .inches(1)),
            fill: .solid(Color("4F46E5"))
        )
        safeAction.setActionLink(.nextSlide)

        let breakoutURLShape = try slide1.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(0.5), y: .inches(3.5), width: .inches(2), height: .inches(1)),
            fill: .solid(Color("991B1B"))
        )
        breakoutURLShape.setHyperlink("https://evil.example/\"\u{0300}onfocus=alert(1)")

        let nbspURLShape = try slide1.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(3.0), y: .inches(3.5), width: .inches(2), height: .inches(1)),
            fill: .solid(Color("9A3412"))
        )
        nbspURLShape.setHyperlink("\u{00A0}https://evil.example/nbsp")

        let combiningTextShape = try slide1.shapes.addTextBox(
            Rect(x: .inches(5.5), y: .inches(3.5), width: .inches(2), height: .inches(1))
        )
        combiningTextShape.textFrame?.text = "\"\u{0300}<\u{0300}>\u{0300}&\u{0300}"

        let lastViewedShape = try slide1.shapes.addShape(
            .rectangle,
            frame: Rect(x: .inches(8.0), y: .inches(3.5), width: .inches(2), height: .inches(1)),
            fill: .solid(Color("1E40AF"))
        )
        let lastViewedCNvPr = try #require(
            lastViewedShape.element.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:cNvPr")
        )
        lastViewedCNvPr.appendElement(
            XML.Element("a:hlinkClick", attributes: [("r:id", ""), ("action", "ppaction://hlinkshowjump?jump=lastslideviewed")])
        )
        slide1.part.markDirty()

        #expect(SVGMarkup.escape("\"\u{0300}<\u{0300}>\u{0300}&\u{0300}") == "&quot;\u{0300}&lt;\u{0300}&gt;\u{0300}&amp;\u{0300}")

        let svg = try deck.renderSVG(slideAt: 0)
        _ = try XML.parse(Data(svg.utf8))
        #expect(!svg.lowercased().contains("javascript:"))
        #expect(!svg.lowercased().contains("data:text/html"))
        #expect(!svg.contains("ppaction://program"))
        #expect(!svg.contains("evil.example"))
        #expect(svg.contains("<a href=\"https://example.com/safe\">"))
        #expect(svg.contains("<a href=\"mailto:security@example.com\">"))
        #expect(svg.contains("<a href=\"#slide-2\">"))
        #expect(svg.contains("<a href=\"ppaction://hlinkshowjump?jump=nextslide\">"))
        #expect(svg.contains("<a href=\"ppaction://hlinkshowjump?jump=lastslideviewed\">"))
    }

    @Test func adversarialEmbeddedSVGStyleCompletesInLinearTimeAndRejectsInvalidRules() throws {
        let repeatedDecls = String(repeating: "fill:#112233  ", count: 60)
        let redosSVG = Data("""
            <svg xmlns="http://www.w3.org/2000/svg" width="120" height="80">
              <style>.cls-1 { \(repeatedDecls)! }</style>
              <rect class="cls-1" width="120" height="80"/>
            </svg>
            """.utf8)

        let clock = ContinuousClock()
        let start = clock.now
        let rejected = SVGEmbeddedImage.size(redosSVG)
        let elapsed = start.duration(to: clock.now)
        #expect(rejected == nil)
        #expect(elapsed < .milliseconds(100))

        let validSVG = Data("""
            <svg xmlns="http://www.w3.org/2000/svg" width="120" height="80">
              <defs>
                <linearGradient id="grad_1"><stop offset="0%" stop-color="#112233"/></linearGradient>
              </defs>
              <style>.cls-1 { fill: url(#grad_1); stroke: #abcdef; stroke-width: 2px }</style>
              <rect class="cls-1" width="120" height="80"/>
            </svg>
            """.utf8)
        #expect(SVGEmbeddedImage.size(validSVG) != nil)
    }

    @Test func nestedUseAmplificationAndCyclesRejectAndFallbackToPNG() throws {
        var bomb = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\"><defs>"
        bomb += "<rect id=\"g0\" width=\"1\" height=\"1\"/>"
        for level in 1...8 {
            bomb += "<g id=\"g\(level)\">" + String(repeating: "<use href=\"#g\(level - 1)\"/>", count: 10) + "</g>"
        }
        bomb += "</defs><use href=\"#g8\"/></svg>"
        #expect(SVGEmbeddedImage.size(Data(bomb.utf8)) == nil)

        var dualHrefBomb = "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"100\" height=\"100\"><defs>"
        dualHrefBomb += "<circle id=\"dot\" cx=\"5\" cy=\"5\" r=\"4\"/>"
        dualHrefBomb += "<rect id=\"g0\" width=\"1\" height=\"1\"/>"
        for level in 1...8 {
            dualHrefBomb += "<g id=\"g\(level)\">" + String(repeating: "<use xlink:href=\"#g\(level - 1)\"/>", count: 10) + "</g>"
        }
        dualHrefBomb += "</defs><use href=\"#dot\" xlink:href=\"#g8\"/></svg>"
        #expect(SVGEmbeddedImage.size(Data(dualHrefBomb.utf8)) == nil)

        let nbspHrefSVG = Data("""
            <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
              <defs><circle id="dot" cx="5" cy="5" r="4"/></defs>
              <use href="\u{00A0}#dot"/>
            </svg>
            """.utf8)
        #expect(SVGEmbeddedImage.size(nbspHrefSVG) == nil)

        let matchingDualHrefSVG = Data("""
            <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">
              <defs><circle id="dot" cx="5" cy="5" r="4" fill="#059669"/></defs>
              <use href="#dot" xlink:href="#dot" x="0" y="0"/>
            </svg>
            """.utf8)
        #expect(SVGEmbeddedImage.size(matchingDualHrefSVG) != nil)

        let cycle = Data("""
            <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
              <defs>
                <g id="a"><use href="#b"/></g>
                <g id="b"><use href="#a"/></g>
              </defs>
              <use href="#a"/>
            </svg>
            """.utf8)
        #expect(SVGEmbeddedImage.size(cycle) == nil)

        let boundedUse = Data("""
            <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
              <defs><circle id="dot" cx="5" cy="5" r="4" fill="#059669"/></defs>
              <use href="#dot" x="0" y="0"/>
              <use href="#dot" x="20" y="20"/>
            </svg>
            """.utf8)
        #expect(SVGEmbeddedImage.size(boundedUse) != nil)

        let combiningBypassSVG = Data("""
            <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
              <style>@\u{0300}import "https://evil.example/a.css"; .cls-1 { fill: #112233 }</style>
              <rect class="cls-1" width="100" height="100"/>
            </svg>
            """.utf8)
        #expect(SVGEmbeddedImage.size(combiningBypassSVG) == nil)

        // Authoring refuses <use> bombs up front; foreign SVG parts carrying a bomb fall back cleanly to PNG.
        let deck = try Presentation()
        let slide = try deck.slides[0]
        #expect(throws: RostrumError.self) {
            _ = try slide.shapes.addSVGPicture(
                Data(bomb.utf8),
                fallbackPNG: Self.minimalPNG,
                frame: Rect(x: .inches(1), y: .inches(1), width: .inches(2), height: .inches(2))
            )
        }
        _ = try slide.shapes.addSVGPicture(
            boundedUse,
            fallbackPNG: Self.minimalPNG,
            frame: Rect(x: .inches(1), y: .inches(1), width: .inches(2), height: .inches(2))
        )
        let svgPart = try #require(deck.package.parts[PackURI("/ppt/media/image1.svg")])
        svgPart.replaceBlob(Data(bomb.utf8))
        let reopened = try Presentation(data: try deck.serializedData())
        let rendered = try reopened.renderSVG(slideAt: 0)
        #expect(rendered.contains("data:image/png;base64,"))
        #expect(!rendered.contains("data:image/svg+xml;base64,"))
    }
}
