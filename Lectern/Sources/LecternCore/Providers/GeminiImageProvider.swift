import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Gemini 2.5 Flash Image ("Nano Banana") via the generativelanguage API. Returns
/// the first inline image part. No vendor SDK (house rule); key never logged (I1).
public struct GeminiImageProvider: ImageProvider {
    public let id: ImageProviderID = .gemini
    private let apiKey: String
    private let model: String
    private let session: URLSession

    public init(apiKey: String, model: String = "gemini-2.5-flash-image", session: URLSession = .shared) {
        self.apiKey = apiKey; self.model = model; self.session = session
    }

    public func image(prompt: String, style: String?, aspect: ImageAspect) async throws -> Data {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        let full = [style, prompt, "Aspect ratio \(aspect.rawValue)."].compactMap { $0 }.joined(separator: "\n\n")
        let body: [String: Any] = [
            "contents": [["parts": [["text": full]]]],
            "generationConfig": ["responseModalities": ["IMAGE"]],
        ]
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var req = URLRequest(url: url, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")           // never logged (I1)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: req) }
        catch let e as URLError where e.code == .notConnectedToInternet { throw LecternError.networkOffline }

        guard let http = response as? HTTPURLResponse else { throw LecternError.providerError(status: 0, message: "no response") }
        switch http.statusCode {
        case 200:
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = obj["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else {
                throw LecternError.providerError(status: 200, message: "unexpected Gemini response")
            }
            for part in parts {
                let inline = (part["inlineData"] ?? part["inline_data"]) as? [String: Any]
                if let b64 = inline?["data"] as? String, let bytes = Data(base64Encoded: b64) { return bytes }
            }
            throw LecternError.providerError(status: 200, message: "no image in Gemini response")
        case 400, 401, 403:
            throw LecternError.authFailed(provider: "Gemini")
        case 429:
            throw LecternError.rateLimited(afterSeconds: Int(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 2)
        default:
            throw LecternError.providerError(status: http.statusCode, message: message(data))
        }
    }

    private func message(_ data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? [String: Any], let m = err["message"] as? String else { return "image request failed" }
        return m
    }
}
