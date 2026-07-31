import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// OpenAI image generation (gpt-image-1). Returns the base64 image. No vendor
/// SDK; key never logged (I1).
public struct OpenAIImageProvider: ImageProvider {
    public let id: ImageProviderID = .openAI
    private let apiKey: String
    private let model: String
    private let send: HTTPRequestSender

    public init(apiKey: String, model: String = "gpt-image-1", session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.send = { request in try await session.data(for: request) }
    }

    init(apiKey: String, model: String = "gpt-image-1",
         send: @escaping HTTPRequestSender) {
        self.apiKey = apiKey
        self.model = model
        self.send = send
    }

    public func validate() async throws {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/models/\(model)")!, timeoutInterval: 30)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, http) = try await perform(req)
        switch http.statusCode {
        case 200:
            return
        case 401, 403:
            throw LecternError.authFailed(provider: "OpenAI")
        case 404:
            throw LecternError.providerError(status: 404, message: "\(model) isn't available to this OpenAI project.")
        case 429:
            throw LecternError.rateLimited(afterSeconds: Int(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 5)
        default:
            throw LecternError.providerError(status: http.statusCode, message: message(data))
        }
    }

    public func image(prompt: String, style: String?, aspect: ImageAspect, role: ImageRole) async throws -> Data {
        guard !apiKey.isEmpty else { throw LecternError.noKey }
        let full = ImageStyleDirective.compose(style: style, role: role, subject: prompt, aspect: aspect)
        let body: [String: Any] = ["model": model, "prompt": full, "size": aspect.openAISize, "n": 1]

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")   // never logged (I1)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, http) = try await perform(req)
        switch http.statusCode {
        case 200:
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = obj["data"] as? [[String: Any]],
                  let b64 = arr.first?["b64_json"] as? String,
                  let bytes = Data(base64Encoded: b64) else {
                throw LecternError.providerError(status: 200, message: "no image in OpenAI response")
            }
            return bytes
        case 401, 403:
            throw LecternError.authFailed(provider: "OpenAI")
        case 429:
            throw LecternError.rateLimited(afterSeconds: Int(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 5)
        default:
            throw LecternError.providerError(status: http.statusCode, message: message(data))
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data, response: URLResponse
        do {
            (data, response) = try await send(request)
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw LecternError.networkOffline
        }
        guard let http = response as? HTTPURLResponse else {
            throw LecternError.providerError(status: 0, message: "no response")
        }
        return (data, http)
    }

    private func message(_ data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? [String: Any], let m = err["message"] as? String else { return "image request failed" }
        return m
    }
}
