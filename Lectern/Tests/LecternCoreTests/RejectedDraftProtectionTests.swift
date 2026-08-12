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
