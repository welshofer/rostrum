#if os(macOS)
import Foundation
import WebKit
import LecternCore

/// Only the resources pinned by the current capture are accessible. No file or
/// network lookup, and no outstanding asynchronous tasks survive cancellation.
@MainActor
final class PreviewFontSchemeHandler: NSObject, WKURLSchemeHandler {
    var resources: [String: PreviewFontResources.Resource] = [:]
    private(set) var servedBytes = 0
    private(set) var servedRequests = 0

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard urlSchemeTask.request.httpMethod == "GET",
              let url = urlSchemeTask.request.url,
              let resource = resources[url.absoluteString],
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": resource.mimeType,
                               "Content-Length": String(resource.data.count),
                               "Access-Control-Allow-Origin": "*",
                               "Cache-Control": "no-store"]) else {
            urlSchemeTask.didFailWithError(URLError(.resourceUnavailable))
            return
        }
        servedRequests += 1
        servedBytes += resource.data.count
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(resource.data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // Delivery is synchronous on the main actor: start either has not run
        // or has already finished. There is no later callback to cancel.
    }
}
#endif
