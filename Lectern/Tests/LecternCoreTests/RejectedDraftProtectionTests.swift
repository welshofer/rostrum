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
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lectern-sec1-\(ProcessInfo.processInfo.globallyUniqueString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let decks = root.appendingPathComponent("Decks", isDirectory: true)
        let diagnostics = root.appendingPathComponent("Diagnostics", isDirectory: true)
        try FileManager.default.createDirectory(at: decks, withIntermediateDirectories: true)

        // A provider whose drafts never validate drives the pipeline through the
        // one repair attempt and into keepRejectedDraft — the branch that writes
        // the file.
        let provider = FixtureProvider(validJSON: "{}", failure: .invalidJSONAlways)
        let request = DeckRequest(prompt: "confidential board strategy", slideCount: 3,
                                  groundingText: "PASTED CONFIDENTIAL SOURCE MATERIAL")

        var reported: [String] = []
        do {
            _ = try await DeckGenerator(provider: provider)
                .generate(request, designURL: nil, into: decks, diagnostics: diagnostics) { _ in }
            Issue.record("an always-invalid draft must fail")
        } catch let LecternError.schemaInvalid(errors) {
            reported = errors
        }

        // SEC-5: the draft lands in the diagnostics directory, never among the
        // user's decks (published to Files / USB file sharing on iOS).
        let deckFiles = try FileManager.default.contentsOfDirectory(atPath: decks.path)
        #expect(!deckFiles.contains { $0.hasPrefix("rejected-draft") },
                "a rejected draft leaked into the decks folder: \(deckFiles)")

        // Read the real file back rather than trusting that a write was attempted.
        let contents = try FileManager.default.contentsOfDirectory(at: diagnostics, includingPropertiesForKeys: nil)
        let kept = try #require(
            contents.first { $0.lastPathComponent.hasPrefix("rejected-draft-") },
            "the pipeline should have written a rejected-draft file")
        #expect(FileManager.default.fileExists(atPath: kept.path))
        #expect(reported.contains { $0.contains(kept.path) }, "the error should point at the kept draft")

        #if !os(iOS)
        // The desktop analogue of iOS data protection: owner read/write only.
        let perms = try #require(
            FileManager.default.attributesOfItem(atPath: kept.path)[.posixPermissions] as? NSNumber,
            "the written draft should carry POSIX permissions")
        #expect(perms.intValue == 0o600,
                "rejected draft must be owner-only (0o600), was 0o\(String(perms.intValue, radix: 8))")
        #endif
    }

    /// SEC-5: even a careless caller that hands the decks folder as the
    /// diagnostics directory cannot leak a draft into it — there is no fallback.
    @Test func keepRejectedDraftRefusesTheDecksDirectory() throws {
        let decks = FileManager.default.temporaryDirectory
            .appendingPathComponent("lectern-sec5-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: decks, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: decks) }

        #expect(DeckGenerator.keepRejectedDraft("{\"secret\":1}", in: decks, decks: decks) == nil)
        // A spelling that standardizes to the same folder is refused too.
        let dotted = decks.appendingPathComponent(".", isDirectory: true)
        #expect(DeckGenerator.keepRejectedDraft("{\"secret\":1}", in: dotted, decks: decks) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: decks.path).isEmpty)

        // A distinct diagnostics folder is still written.
        let diagnostics = decks.deletingLastPathComponent()
            .appendingPathComponent(decks.lastPathComponent + "-diagnostics", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: diagnostics) }
        let kept = try #require(DeckGenerator.keepRejectedDraft("{\"secret\":1}", in: diagnostics, decks: decks))
        #expect(kept.deletingLastPathComponent().standardizedFileURL.path == diagnostics.standardizedFileURL.path)
    }

    /// SEC-5 (c): with a required diagnostics directory, a successful run still
    /// saves its recovery snapshot there — and only there — and it reloads.
    @Test func recoverySnapshotGoesToDiagnosticsNotDecks() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let decks = root.appendingPathComponent("Decks", isDirectory: true)
        let diagnostics = root.appendingPathComponent("Diagnostics", isDirectory: true)
        try FileManager.default.createDirectory(at: decks, withIntermediateDirectories: true)
        let deck = DeckIR(meta: Meta(title: "Recoverable"), slides: [
            IRSlide(id: "title", layout: "title", title: "Recoverable"),
            IRSlide(id: "body", layout: "bullets", title: "Evidence", body: Body(bullets: [Bullet(text: "Keep me")])),
            IRSlide(id: "end", layout: "closing", title: "Next step", body: Body(callToAction: "Act"))
        ])
        let provider = FixtureProvider(validJSON: String(decoding: try JSONEncoder().encode(deck), as: UTF8.self))
        let result = try await DeckGenerator(provider: provider, quality: false).generate(
            DeckRequest(prompt: "Explain the evidence", slideCount: 3, notes: false),
            designURL: nil, into: decks, diagnostics: diagnostics) { _ in }

        let recovery = try #require(result.recoveryURL)
        #expect(recovery.deletingLastPathComponent().standardizedFileURL.path == diagnostics.standardizedFileURL.path)
        #expect(try RenderSnapshot.load(recovery).deck.slides[1].body?.bullets?.first?.text == "Keep me")
        let deckFiles = try FileManager.default.contentsOfDirectory(atPath: decks.path)
        #expect(!deckFiles.contains { $0.hasPrefix("render-session") || $0.hasPrefix("rejected-draft") })

        // Diagnostics pointed at the decks folder: no snapshot is written there.
        let unsafe = try await DeckGenerator(provider: provider, quality: false).generate(
            DeckRequest(prompt: "Explain the evidence", slideCount: 3, notes: false),
            designURL: nil, into: decks, diagnostics: decks) { _ in }
        #expect(unsafe.recoveryURL == nil)
        #expect(!(try FileManager.default.contentsOfDirectory(atPath: decks.path)).contains { $0.hasPrefix("render-session") })
    }
}
