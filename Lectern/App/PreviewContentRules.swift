import Foundation
import WebKit
import LecternCore

/// Where a preview or thumbnail page may and may not go.
///
/// The SVG a preview shows is model-derived — a deck drafted from the user's
/// own PDF — so a planted `<image href="https://…">`, a CSS `url()` or a
/// `<foreignObject>` iframe would carry slide text (and the user's IP) off the
/// machine during a render nobody is watching. `loadHTMLString(_, baseURL: nil)`
/// gives the page no origin, but a nil base URL does not stop absolute URLs
/// inside the markup from being fetched. Three layers do, and each stands on
/// its own:
///
/// 1. `PreviewPolicy.allows` — the navigation delegate gate. Both coordinators
///    cancel every frame navigation except the `about:blank` the initial load
///    is, and the app's own font scheme.
/// 2. `PreviewPolicy.contentSecurityPolicyMeta` — a `<meta>` CSP written into
///    every preview document, so the page itself refuses to fetch anything
///    that is not inline, `data:` or served by the font scheme.
/// 3. `PreviewContentRules` — a compiled `WKContentRuleList` built from
///    `PreviewPolicy.encodedRules` that blocks every load the web view would
///    otherwise make, with the same exceptions.
///
/// Ordering: the first two are synchronous and apply to the very first load.
/// The rule list has to be compiled by `WKContentRuleListStore`, which is
/// asynchronous, so the app kicks compilation off at launch (`LecternApp.init`)
/// and `PreviewContentRules.attach(to:)` adds the finished list to a
/// configuration's user content controller — immediately when compilation is
/// done, otherwise as soon as it is. A `WKWebView` shares the
/// `WKUserContentController` it was configured with, so a list added later
/// still governs that view's subsequent loads.
enum PreviewPolicy {
    /// The only navigation a preview is allowed: the `about:blank` that
    /// `loadHTMLString(_, baseURL: nil)` loads as (reported as a nil URL on
    /// some WebKit versions). Fonts on the app's own scheme are subresource
    /// loads, which never reach the navigation delegate, so the scheme needs
    /// no exception here — and granting one would let a page navigate a frame
    /// to font bytes.
    static func allows(_ url: URL?) -> Bool {
        guard let url else { return true }
        return url.absoluteString == "about:blank"
    }

    /// What the rendered SVG needs and nothing more: inline `<style>` and
    /// style attributes, images embedded as `data:` URLs, and fonts either
    /// inline as `data:` or served through the app's own scheme. Scripts stay
    /// off (`allowsContentJavaScript = false` already; `default-src 'none'`
    /// agrees). API-injected scripts are user-agent scripts and are not
    /// subject to the page's CSP.
    static let contentSecurityPolicy =
        "default-src 'none'; img-src data:; style-src 'unsafe-inline'; font-src data: \(PreviewFontResources.scheme):"

    /// The `<meta>` element both preview document builders write into `<head>`.
    static let contentSecurityPolicyMeta =
        "<meta http-equiv=\"Content-Security-Policy\" content=\"\(contentSecurityPolicy)\">"

    /// Identifier under which the compiled list is stored by the default
    /// `WKContentRuleListStore`. The list is recompiled on every launch (it is
    /// tiny), so the version suffix only keeps an older build's copy from
    /// sharing a name with this one.
    static let ruleListIdentifier = "lectern-preview-block-all-v1"

    /// Block everything, then exempt what a preview legitimately loads. The
    /// `url-filter` is a regular expression over the whole URL, so `^scheme:`
    /// pins the match to the scheme. `about:` covers the page's own document
    /// and `data:` the inline images and fonts; neither can leave the machine,
    /// and WebKit versions differ on whether they consult rule lists for them.
    static let encodedRules: String = {
        let rules: [[String: Any]] = [
            ["trigger": ["url-filter": ".*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": "^about:"], "action": ["type": "ignore-previous-rules"]],
            ["trigger": ["url-filter": "^data:"], "action": ["type": "ignore-previous-rules"]],
            ["trigger": ["url-filter": "^\(PreviewFontResources.scheme):"], "action": ["type": "ignore-previous-rules"]],
        ]
        let data = try! JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }()
}

/// The compiled block-all rule list, built once per launch and shared by every
/// preview and thumbnail web view.
@MainActor
enum PreviewContentRules {
    private(set) static var compiled: WKContentRuleList?
    private static var compilation: Task<Void, Never>?
    private(set) static var compilationFailure: String?

    /// Starts compiling the list if nothing has yet. Call once at launch.
    static func warm() { _ = compile() }

    @discardableResult
    private static func compile() -> Task<Void, Never> {
        if let compilation { return compilation }
        let task = Task {
            do {
                compiled = try await WKContentRuleListStore.default().compileContentRuleList(
                    forIdentifier: PreviewPolicy.ruleListIdentifier,
                    encodedContentRuleList: PreviewPolicy.encodedRules)
                if compiled == nil { compilationFailure = "The content rule list store returned no list." }
            } catch {
                compilationFailure = error.localizedDescription
            }
        }
        compilation = task
        return task
    }

    /// Waits for compilation and adds the list to the configuration's user
    /// content controller. Returns whether a list was added.
    @discardableResult
    static func install(into configuration: WKWebViewConfiguration) async -> Bool {
        await compile().value
        return installCompiled(into: configuration)
    }

    /// Adds the list only if it is already compiled. Returns whether it was.
    @discardableResult
    static func installCompiled(into configuration: WKWebViewConfiguration) -> Bool {
        guard let compiled else { return false }
        configuration.userContentController.add(compiled)
        return true
    }

    /// For the synchronous `make…` paths: adds the list now when it is ready,
    /// otherwise as soon as compilation finishes. Until then the navigation
    /// gate and the document's CSP are what stand between the markup and the
    /// network.
    static func attach(to configuration: WKWebViewConfiguration) {
        if installCompiled(into: configuration) { return }
        Task { await install(into: configuration) }
    }
}
