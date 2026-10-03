import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import LecternCore

@Suite struct OpenAIModelChoiceTests {
    @Test(arguments: TextStrength.allCases, ReasoningEffort.allCases)
    func everyTextChoiceHasASupportedWireContract(strength: TextStrength, effort: ReasoningEffort) async throws {
        let seen = SentRequest()
        let provider = OpenAIProvider(apiKey: "test", model: strength.modelID, effort: effort) { wire in
            seen.record(wire)
            let body = #"{"status":"completed","output":[{"type":"function_call","status":"completed","name":"emit_deck","arguments":"{}"}]}"#
            return (Data(body.utf8), Self.http(wire, status: 200))
        }
        let deck = DeckRequest(prompt: "Synthetic test", slideCount: 40, notes: true)
        _ = try await provider.draft(deck, repairing: nil) { _ in }
        let wire = try #require(seen.value)
        let payload = try Self.body(wire)
        #expect(payload["model"] as? String == strength.modelID)
        let effective = strength.supported(effort)
        #expect((payload["reasoning"] as? [String: String])?["effort"] == effective.rawValue)
        let budget = try #require(payload["max_output_tokens"] as? Int)
        #expect(budget == DeckOutputBudget.tokens(for: deck) + effective.tokenAllowance)
        #expect(budget <= 128_000)
        #expect(wire.timeoutInterval > 290)
        if effective == .max { #expect(wire.timeoutInterval > 890) }
        #expect(strength.efforts.contains(.none) == (strength == .luna))
    }

    @Test(arguments: ImageModel.allCases, ImageQuality.allCases)
    func imageChoicesUseImagesAPI(model: ImageModel, quality: ImageQuality) async throws {
        let seen = SentRequest()
        let provider = OpenAIImageProvider(apiKey: "test", model: model.rawValue, quality: quality) { wire in
            seen.record(wire)
            return (Data(#"{"data":[{"b64_json":"aW1hZ2U="}]}"#.utf8), Self.http(wire, status: 200))
        }
        let result = try await provider.image(prompt: "A tree", style: "Ink drawing", aspect: .wide, role: .background)
        #expect(result == Data("image".utf8))
        let wire = try #require(seen.value)
        let payload = try Self.body(wire)
        #expect(wire.url?.absoluteString == "https://api.openai.com/v1/images/generations")
        #expect(wire.httpMethod == "POST")
        #expect(wire.value(forHTTPHeaderField: "Authorization") == "Bearer test")
        #expect(payload["model"] as? String == model.rawValue)
        #expect(payload["quality"] as? String == quality.rawValue)
        #expect(payload["size"] as? String == "1536x864")
        #expect(payload["output_format"] as? String == "png")
        #expect(payload["n"] as? Int == 1)
        let prompt = try #require(payload["prompt"] as? String)
        #expect(prompt.contains("Ink drawing"))
        #expect(prompt.contains("BACKGROUND"))
        #expect(prompt.contains("A tree"))
        try await provider.validate()
        #expect(seen.value?.url?.path == "/v1/models/\(model.rawValue)")
    }

    @Test func imageDimensionsKeepEveryRequestedAspectRatio() {
        for (aspect, width, height) in [(ImageAspect.wide,16,9),(.standard,4,3),(.square,1,1),(.tall,3,4),(.portrait,9,16)] {
            let dimensions = aspect.openAISize.split(separator: "x").compactMap { Int($0) }
            #expect(dimensions.count == 2)
            #expect(dimensions[0] * height == dimensions[1] * width)
            #expect(dimensions.allSatisfy { $0 % 16 == 0 && $0 <= 3840 })
            #expect((655_360...8_294_400).contains(dimensions[0] * dimensions[1]))
        }
    }

    @Test(arguments: ["refusal", "wrongFunction", "multipleCalls", "failed", "incompleteCall"])
    func incompleteOrUnexpectedResponsesNeverBecomeDecks(kind: String) async throws {
        let provider = OpenAIProvider(apiKey: "test") { wire in
            var call: [String: Any] = ["type":"function_call", "status":"completed", "name":"emit_deck", "arguments":"{}"]
            if kind == "wrongFunction" { call["name"] = "other" }
            if kind == "incompleteCall" { call["status"] = "incomplete" }
            var output: [[String: Any]] = [call]
            if kind == "multipleCalls" { output.append(call) }
            if kind == "refusal" { output = [["type":"message", "content":[["type":"refusal", "refusal":"No"]]]] }
            let body: [String: Any] = ["status": kind == "failed" ? "failed" : "completed", "output": output]
            return (try JSONSerialization.data(withJSONObject: body), Self.http(wire, status: 200))
        }
        await #expect(throws: LecternError.self) {
            _ = try await provider.draft(DeckRequest(prompt: "Synthetic"), repairing: nil) { _ in }
        }
    }

    @Test func cancellationDoesNotRetry() async {
        let attempts = AttemptCounter()
        let provider = OpenAIProvider(apiKey: "test") { _ in
            _ = attempts.next()
            throw CancellationError()
        }
        await #expect(throws: CancellationError.self) {
            _ = try await provider.draft(DeckRequest(prompt: "Synthetic"), repairing: nil) { _ in }
        }
        #expect(attempts.count == 1)
    }

    @Test func modelValidationUsesOpenAIAuthentication() async throws {
        let models = try await OpenAIModels.list(apiKey: "test") { wire in
            #expect(wire.url?.absoluteString == "https://api.openai.com/v1/models")
            #expect(wire.value(forHTTPHeaderField: "Authorization") == "Bearer test")
            #expect(wire.value(forHTTPHeaderField: "x-api-key") == nil)
            return (Data(#"{"data":[{"id":"gpt-6.1-sol"}]}"#.utf8), Self.http(wire, status: 200))
        }
        #expect(models == [TextStrength.sol.modelID])
    }

    private static func http(_ request: URLRequest, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
    private static func body(_ request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
