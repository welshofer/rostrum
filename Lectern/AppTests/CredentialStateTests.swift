import Foundation
import Testing
import LecternCore
@testable import Lectern

/// No test uses the real Keychain or a live provider. Failures and presence are
/// supplied through the same dependency used by all AppState credential paths.
@MainActor
@Suite struct CredentialStateTests {
    @Test func failedReplacementAndRemovalKeepKnownStoredKeys() throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let fake = FakeCredentials()
        fake.values = ["openAI": "old-text-fixture", "image:openAI": "old-image-fixture"]
        let app = AppState(skipKeychain: true, defaults: context.defaults, credentials: fake.store)
        #expect(app.hasKey && app.hasImageKey)
        fake.failWrites = true
        #expect(!app.saveKey("replacement-fixture"))
        #expect(!app.saveImageKey("replacement-image-fixture"))
        #expect(app.hasKey && app.hasImageKey)
        #expect(app.keyStatus == .invalid(AppState.saveKeyFailure))
        #expect(app.imageKeyStatus == .invalid(AppState.saveKeyFailure))
        #expect(!app.clearKey() && !app.clearImageKey())
        #expect(app.hasKey && app.hasImageKey)
        #expect(fake.values == ["openAI": "old-text-fixture", "image:openAI": "old-image-fixture"])
        #expect(fake.reads == 0)
    }

    @Test func successfulWritesAndRemovalsKeepProviderNamespacesSeparate() throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let fake = FakeCredentials()
        let app = AppState(skipKeychain: true, defaults: context.defaults, credentials: fake.store)
        #expect(app.saveKey("text-fixture"))
        #expect(app.saveImageKey("image-fixture"))
        #expect(app.hasKey && app.hasImageKey)
        #expect(fake.values == ["openAI": "text-fixture", "image:openAI": "image-fixture"])
        #expect(app.clearKey())
        #expect(!app.hasKey && app.hasImageKey)
        #expect(fake.values == ["image:openAI": "image-fixture"])
        #expect(app.clearImageKey())
        #expect(!app.hasImageKey && fake.values.isEmpty)
        #expect(fake.reads == 0)
    }

    @Test func unavailablePresenceDoesNotBecomeMissingAndCanBeRetried() throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let fake = FakeCredentials()
        fake.presenceOverride = .unavailable(-25308)
        let app = AppState(skipKeychain: true, defaults: context.defaults, credentials: fake.store)
        #expect(app.keyStorageUnavailable && app.imageKeyStorageUnavailable)
        #expect(app.keyStatus == .invalid(AppState.unreadableKeyAdvice))
        #expect(app.imageKeyStatus == .invalid(AppState.unreadableKeyAdvice))
        fake.values["openAI"] = "text-fixture"
        fake.presenceOverride = nil
        app.refreshKeyAvailability()
        #expect(app.hasKey && !app.hasImageKey)
        #expect(!app.keyStorageUnavailable && !app.imageKeyStorageUnavailable)
        fake.presenceOverride = .unavailable(-25293)
        app.refreshKeyAvailability()
        #expect(app.hasKey && app.keyStorageUnavailable)
        #expect(fake.reads == 0)
    }

    @Test func isolatedSessionRejectsAllCredentialActionsAndGeneration() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = context.app
        #expect(app.isTestSession)
        #expect(!app.saveKey("not-a-real-key"))
        #expect(!app.saveImageKey("not-a-real-key"))
        #expect(!app.clearKey() && !app.clearImageKey())
        await app.validateKey()
        await app.validateImageKey()
        #expect(app.keyStatus == .invalid(AppState.testSessionAdvice))
        #expect(app.imageKeyStatus == .invalid(AppState.testSessionAdvice))
        app.prompt = "test session must not generate"
        #expect(!app.canGenerate)
        app.generate()
        #expect(app.phase == .failed(AppState.testSessionAdvice))
        #expect(!app.hasKey && !app.hasImageKey)
        #expect(try FileManager.default.contentsOfDirectory(atPath: context.libraryDirectory.path).isEmpty)
    }

    @Test func isolatedSessionCannotReadInjectedCredentialsForLiveRequests() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let fake = FakeCredentials()
        fake.values = ["openAI": "fixture", "image:openAI": "fixture"]
        let app = AppState(skipKeychain: true, defaults: context.defaults, credentials: fake.store)
        await app.validateKey()
        await app.validateImageKey()
        app.generate()
        #expect(fake.reads == 0)
        #expect(app.phase == .failed(AppState.testSessionAdvice))
    }

    @Test func onlyExplicitMissingReadIsClassifiedAsAbsent() {
        #expect(!AppState.isUnreadable(.success("fixture")))
        #expect(!AppState.isUnreadable(.failure(KeychainStore.ReadProblem.missing)))
        #expect(AppState.isUnreadable(.failure(KeychainStore.ReadProblem.unreadable(-25308))))
        #expect(AppState.isUnreadable(.failure(CredentialStore.IsolationError.disabled)))
    }

    @Test func duplicateGenerateDoesNotInterruptAnActiveRun() throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        context.app.phase = .generating
        context.app.generate()
        #expect(context.app.phase == .generating)
    }

    @Test func dedicatedTestHostIsIsolatedWithoutSchemeEnvironment() throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let app = AppState.forLaunch(environment: [:], testRoot: context.libraryDirectory,
            testDefaults: context.defaults, isTestHostBundle: true)
        #expect(app.isTestSession && !app.saveKey("fixture") && !app.saveImageKey("fixture"))
        #expect(AppState.testHostFlag(true) && AppState.testHostFlag("YES"))
        #expect(!AppState.testHostFlag(false) && !AppState.testHostFlag("NO"))
        #expect(!AppState.testHostFlag(nil))
    }
}

@MainActor
private final class FakeCredentials {
    var values: [String: String] = [:]
    var reads = 0
    var failWrites = false
    var presenceOverride: KeychainStore.Presence?

    var store: CredentialStore {
        CredentialStore(save: { [self] key, account in
            if failWrites { throw CredentialStore.IsolationError.disabled }
            values[account] = key
        }, read: { [self] account in
            reads += 1
            guard let value = values[account] else { throw KeychainStore.ReadProblem.missing }
            return value
        }, delete: { [self] account in
            if failWrites { throw CredentialStore.IsolationError.disabled }
            values[account] = nil
        }, presence: { [self] account in
            presenceOverride ?? (values[account] == nil ? .missing : .present)
        })
    }
}
