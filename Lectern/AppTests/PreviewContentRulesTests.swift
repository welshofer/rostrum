import Foundation
import Testing
import WebKit
import LecternCore
@testable import Lectern

/// The preview pages show model-derived SVG. These pin the three layers that
/// keep such a page from fetching anything off the machine: the navigation
/// gate, the document CSP, and the block-all content rule list.
@Suite struct PreviewPolicyTests {
    @Test func navigationGateAllowsOnlyTheBlankPage() throws {
        #expect(PreviewPolicy.allows(nil))
        #expect(PreviewPolicy.allows(URL(string: "about:blank")))
        // Fonts are subresources, never navigations: the scheme gets no pass.
        for denied in ["https://example.com", "http://example.com/slide.png", "file:///etc/hosts",
                       "ftp://example.com/", "about:srcdoc", "data:text/html,hi", "javascript:void(0)",
                       "blob:null/abc", "\(PreviewFontResources.scheme)://namespace/1",
                       "\(PreviewFontResources.scheme)x://namespace/1"] {
            let url = try #require(URL(string: denied))
            #expect(!PreviewPolicy.allows(url), "\(denied)")
        }
    }

    @Test func ruleListBlocksEverythingButLocalDataAndTheFontScheme() throws {
        let rules = try #require(try JSONSerialization.jsonObject(with: Data(PreviewPolicy.encodedRules.utf8)) as? [[String: Any]])
        #expect(rules.count == 4)
        let block = try #require(rules.first)
        #expect((block["trigger"] as? [String: String])?["url-filter"] == ".*")
        #expect((block["action"] as? [String: String])?["type"] == "block")
        let exceptions = rules.dropFirst()
        #expect(exceptions.map { ($0["trigger"] as? [String: String])?["url-filter"] }
            == ["^about:", "^data:", "^\(PreviewFontResources.scheme):"])
        for rule in exceptions {
            #expect((rule["action"] as? [String: String])?["type"] == "ignore-previous-rules")
        }
        // The scheme filter is anchored: it matches the URLs the handler serves
        // and not a network URL that merely mentions the scheme.
        let filter = try NSRegularExpression(pattern: "^\(PreviewFontResources.scheme):")
        func matches(_ url: String) -> Bool {
            filter.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil
        }
        #expect(matches("\(PreviewFontResources.scheme)://namespace/1"))
        #expect(!matches("https://example.com/\(PreviewFontResources.scheme):"))
    }

    @Test func contentSecurityPolicyNamesOnlyInlineDataAndTheFontScheme() {
        let csp = PreviewPolicy.contentSecurityPolicy
        #expect(csp.hasPrefix("default-src 'none';"))
        #expect(csp.contains("img-src data:"))
        #expect(csp.contains("style-src 'unsafe-inline'"))
        #expect(csp.contains("font-src data: \(PreviewFontResources.scheme):"))
        #expect(!csp.contains("http"))
        #expect(PreviewPolicy.contentSecurityPolicyMeta.contains("http-equiv=\"Content-Security-Policy\""))
    }

    @MainActor @Test func bothPreviewDocumentsCarryTheContentSecurityPolicy() throws {
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 4 3\"/>"
        for document in [SlidePreview(svg: svg).document, SnapshotHost.document(svg: svg)] {
            let meta = try #require(document.range(of: PreviewPolicy.contentSecurityPolicyMeta))
            let body = try #require(document.range(of: "<body>"))
            #expect(meta.lowerBound < body.lowerBound)
            #expect(document.contains(svg))
        }
    }

    /// WebKit compiles the rules; a typo in the JSON or an unsupported
    /// `url-filter` form surfaces here rather than as silently unblocked loads.
    @MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["LECTERN_TEST_WEBKIT"] == "1"))
    func ruleListCompilesAndInstalls() async throws {
        let installed = await PreviewContentRules.install(into: WKWebViewConfiguration())
        #expect(installed, "\(PreviewContentRules.compilationFailure ?? "no failure recorded")")
        let compiled = try #require(PreviewContentRules.compiled)
        #expect(compiled.identifier == PreviewPolicy.ruleListIdentifier)
        // Once compiled, the synchronous path the `make…` functions use succeeds too.
        #expect(PreviewContentRules.installCompiled(into: WKWebViewConfiguration()))
    }
}
