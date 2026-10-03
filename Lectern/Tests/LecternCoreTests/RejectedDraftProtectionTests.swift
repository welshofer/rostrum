import Foundation
import Testing
@testable import LecternCore

/// L-SEC-1: a rejected draft is the model's rendering of the user's prompt plus
/// whatever grounding text they pasted, so it must not be left readable by other
/// processes running as the same user. iOS guards it with
/// `.completeFileProtection`; on macOS/Linux the equivalent is owner-only POSIX
/// permissions. This asserts the guard actually holds on disk, not just that a
/// code path was taken.
@Suite struct RejectedDraftProtectionTests {

    @Test func exportFailureKeepsTheAcceptedRevisionForOfflineRecovery() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent("blocked-output")
        try Data("a file cannot be used as an output directory".utf8).write(to: output)
        let diagnostics = root.appendingPathComponent("diagnostics")
        let original = DeckIR(meta: Meta(title: "Original draft"), slides: [
            IRSlide(id: "title", layout: "title", title: "Original"),
            IRSlide(id: "body", layout: "bullets", title: "Evidence", body: Body(bullets: [Bullet(text: "Retain this fact")])),
            IRSlide(id: "end", layout: "closing", title: "Next step", body: Body(callToAction: "Act"))
        ])
        var revised = original
        revised.meta.title = "Accepted revision"
        let encoder = JSONEncoder()
        let provider = FixtureProvider(validJSON: String(decoding: try encoder.encode(original), as: UTF8.self),
            revisedJSON: String(decoding: try encoder.encode(revised), as: UTF8.self))
        do {
            _ = try await DeckGenerator(provider: provider).generate(
                DeckRequest(prompt: "Explain the evidence", slideCount: 3, notes: false),
                designURL: nil, into: output, diagnostics: diagnostics) { _ in }
            Issue.record("The blocked output should fail")
        } catch let LecternError.renderFailed(message) {
            #expect(message.contains("saved for recovery"))
        }
        let files = try FileManager.default.contentsOfDirectory(at: diagnostics, includingPropertiesForKeys: nil)
        let saved = try #require(files.first { $0.lastPathComponent.hasPrefix("rejected-draft") })
        let recovered = try JSONDecoder().decode(DeckIR.self, from: Data(contentsOf: saved))
        #expect(recovered.meta.title == "Accepted revision")
        #expect(recovered.slides[1].body?.bullets?.first?.text == "Retain this fact")
        #if !os(iOS)
        #expect((try FileManager.default.attributesOfItem(atPath: saved.path)[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #endif
    }

    @Test func rejectedDraftOnDiskIsOwnerReadableOnly() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lectern-sec1-\(ProcessInfo.processInfo.globallyUniqueString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        // A provider whose drafts never validate drives the pipeline through the
        // one repair attempt and into keepRejectedDraft — the branch that writes
        // the file. With `diagnostics` omitted, the draft lands in `dir` itself.
        let provider = FixtureProvider(validJSON: "{}", failure: .invalidJSONAlways)
        let request = DeckRequest(prompt: "confidential board strategy", slideCount: 3,
                                  groundingText: "PASTED CONFIDENTIAL SOURCE MATERIAL")

        await #expect(throws: LecternError.self) {
            _ = try await DeckGenerator(provider: provider)
                .generate(request, designURL: nil, into: dir) { _ in }
        }

        // Read the real file back rather than trusting that a write was attempted.
        let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let kept = try #require(
            contents.first { $0.lastPathComponent.hasPrefix("rejected-draft-") },
            "the pipeline should have written a rejected-draft file")
        #expect(FileManager.default.fileExists(atPath: kept.path))

        #if !os(iOS)
        // The desktop analogue of iOS data protection: owner read/write only.
        let perms = try #require(
            FileManager.default.attributesOfItem(atPath: kept.path)[.posixPermissions] as? NSNumber,
            "the written draft should carry POSIX permissions")
        #expect(perms.intValue == 0o600,
                "rejected draft must be owner-only (0o600), was 0o\(String(perms.intValue, radix: 8))")
        #endif
    }
}
