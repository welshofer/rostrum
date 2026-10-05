import Foundation
import Testing
#if canImport(Security)
import Security
#if KEYCHAIN_FAKE_ONLY
@testable import KeychainHarness
#else
@testable import Lectern
#endif

/// Every operation is injected. These tests never query, modify, or decrypt
/// a real Keychain item, even when compiled by an app-hosted target later.
@Suite struct KeychainStoreTests {
    @Test func replacementUpdatesOnlyDataWithoutDeletingExistingAccessControl() throws {
        let fake = FakeSecurity(value: Data("old-fixture".utf8))
        try KeychainStore.saveOrFail("new-fixture", account: "openAI", operations: fake.operations)
        #expect(fake.value == Data("new-fixture".utf8))
        #expect(fake.events == ["update"])
        #expect(fake.updates.count == 1)
        #expect(Set(fake.updates[0].1.keys) == [kSecValueData as String])
        assertAccount(fake.updates[0].0, "openAI")
        #expect(fake.updates[0].0[kSecReturnData as String] == nil)
        #expect(fake.updates[0].0[kSecAttrAccessible as String] == nil)
    }

    @Test(arguments: [errSecAuthFailed, errSecInteractionNotAllowed, errSecUserCanceled, errSecNotAvailable])
    func failedUpdatePreservesOldValueAndOriginalStatus(_ status: OSStatus) {
        let fake = FakeSecurity(value: Data("old-fixture".utf8))
        fake.updateStatuses = [status]
        #expect(throws: KeychainStore.WriteProblem.failed(status)) {
            try KeychainStore.saveOrFail("new-fixture", account: "openAI", operations: fake.operations)
        }
        #expect(fake.value == Data("old-fixture".utf8))
        #expect(fake.events == ["update"])
    }

    @Test func missingItemAddsWithDeviceUnlockProtectionAndImageAccountNamespace() throws {
        let fake = FakeSecurity()
        try KeychainStore.saveOrFail("new-fixture", account: "image:openAI", operations: fake.operations)
        #expect(fake.events == ["update", "add"])
        #expect(fake.value == Data("new-fixture".utf8))
        assertAccount(fake.additions[0], "image:openAI")
        #expect(fake.additions[0][kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlocked as String)
    }

    @Test func failedAddIsReportedWithoutAnyDelete() {
        let fake = FakeSecurity()
        fake.addStatus = errSecNotAvailable
        #expect(throws: KeychainStore.WriteProblem.failed(errSecNotAvailable)) {
            try KeychainStore.saveOrFail("new-fixture", account: "openAI", operations: fake.operations)
        }
        #expect(fake.events == ["update", "add"] && fake.value == nil)
    }

    @Test func duplicateAddRaceRetriesUpdateOnceWithoutDeleting() throws {
        let fake = FakeSecurity(value: Data("concurrent-fixture".utf8))
        fake.updateStatuses = [errSecItemNotFound, errSecSuccess]
        fake.addStatus = errSecDuplicateItem
        try KeychainStore.saveOrFail("new-fixture", account: "openAI", operations: fake.operations)
        #expect(fake.events == ["update", "add", "update"])
        #expect(fake.value == Data("new-fixture".utf8))
        #expect(Set(fake.updates[1].1.keys) == [kSecValueData as String])
    }

    @Test func failedRaceRetryRetainsOtherWritersItemAndDoesNotLoop() {
        let fake = FakeSecurity(value: Data("concurrent-fixture".utf8))
        fake.updateStatuses = [errSecItemNotFound, errSecAuthFailed]
        fake.addStatus = errSecDuplicateItem
        #expect(throws: KeychainStore.WriteProblem.failed(errSecAuthFailed)) {
            try KeychainStore.saveOrFail("new-fixture", account: "openAI", operations: fake.operations)
        }
        #expect(fake.events == ["update", "add", "update"])
        #expect(fake.value == Data("concurrent-fixture".utf8))
    }

    @Test(arguments: [errSecAuthFailed, errSecInteractionNotAllowed, errSecUserCanceled, errSecNotAvailable])
    func unavailableReadRetainsStatusWithoutAnExistenceProbe(_ status: OSStatus) {
        let fake = FakeSecurity()
        fake.copyStatus = status
        #expect(throws: KeychainStore.ReadProblem.unreadable(status)) {
            _ = try KeychainStore.readOrFail(account: "openAI", operations: fake.operations)
        }
        #expect(fake.events == ["copy"])
        #expect(fake.queries[0][kSecReturnData as String] as? Bool == true)
    }

    @Test func onlyNotFoundMeansMissingAndSuccessfulReadUsesReturnedBytes() throws {
        let fake = FakeSecurity()
        fake.copyStatus = errSecItemNotFound
        #expect(throws: KeychainStore.ReadProblem.missing) {
            _ = try KeychainStore.readOrFail(account: "openAI", operations: fake.operations)
        }
        fake.copyStatus = errSecSuccess
        fake.copyItem = Data("read-fixture".utf8) as CFData
        #expect(try KeychainStore.readOrFail(account: "openAI", operations: fake.operations) == "read-fixture")
        #expect(fake.events == ["copy", "copy"])
    }

    @Test func malformedSuccessReportsDecodeFailureRatherThanSuccessfulOSStatus() {
        let fake = FakeSecurity()
        for item: CFTypeRef? in [nil, "wrong-type" as CFString, Data([0xff]) as CFData] {
            fake.copyItem = item
            #expect(throws: KeychainStore.ReadProblem.unreadable(errSecDecode)) {
                _ = try KeychainStore.readOrFail(account: "openAI", operations: fake.operations)
            }
        }
        #expect(fake.events == ["copy", "copy", "copy"])
    }

    @Test func presenceDistinguishesAbsenceFromFailedQueriesWithoutRequestingSecretData() {
        let fake = FakeSecurity()
        for (status, expected): (OSStatus, KeychainStore.Presence) in [
            (errSecSuccess, .present), (errSecItemNotFound, .missing),
            (errSecAuthFailed, .unavailable(errSecAuthFailed)),
            (errSecInteractionNotAllowed, .unavailable(errSecInteractionNotAllowed)),
            (errSecUserCanceled, .unavailable(errSecUserCanceled))] {
            fake.copyStatus = status
            #expect(KeychainStore.presence(account: "openAI", operations: fake.operations) == expected)
        }
        #expect(fake.queries.allSatisfy { $0[kSecReturnData as String] as? Bool == false })
        #expect(fake.events == Array(repeating: "copy", count: 5))
    }

    @Test func deleteFailurePreservesItemAndNotFoundIsIdempotent() throws {
        let fake = FakeSecurity(value: Data("old-fixture".utf8))
        fake.deleteStatus = errSecAuthFailed
        #expect(throws: KeychainStore.WriteProblem.failed(errSecAuthFailed)) {
            try KeychainStore.deleteOrFail(account: "openAI", operations: fake.operations)
        }
        #expect(fake.value == Data("old-fixture".utf8))
        fake.deleteStatus = errSecSuccess
        try KeychainStore.deleteOrFail(account: "openAI", operations: fake.operations)
        #expect(fake.value == nil)
        fake.deleteStatus = errSecItemNotFound
        try KeychainStore.deleteOrFail(account: "openAI", operations: fake.operations)
        #expect(fake.events == ["delete", "delete", "delete"])
    }

    private func assertAccount(_ query: [String: Any], _ account: String) {
        #expect(query[kSecClass as String] as? String == kSecClassGenericPassword as String)
        #expect(query[kSecAttrService as String] as? String == "com.lectern.app.apikeys")
        #expect(query[kSecAttrAccount as String] as? String == account)
    }
}

private final class FakeSecurity {
    var value: Data?
    var updateStatuses: [OSStatus] = []
    var addStatus: OSStatus = errSecSuccess
    var copyStatus: OSStatus = errSecSuccess
    var copyItem: CFTypeRef?
    var deleteStatus: OSStatus = errSecSuccess
    var events: [String] = []
    var updates: [([String: Any], [String: Any])] = []
    var additions: [[String: Any]] = []
    var queries: [[String: Any]] = []

    init(value: Data? = nil) { self.value = value }

    var operations: KeychainStore.Operations {
        KeychainStore.Operations(
            update: { query, changes in
                self.events.append("update"); self.updates.append((query, changes))
                let status = self.updateStatuses.isEmpty
                    ? (self.value == nil ? errSecItemNotFound : errSecSuccess)
                    : self.updateStatuses.removeFirst()
                if status == errSecSuccess { self.value = changes[kSecValueData as String] as? Data }
                return status
            }, add: { attributes in
                self.events.append("add"); self.additions.append(attributes)
                if self.addStatus == errSecSuccess { self.value = attributes[kSecValueData as String] as? Data }
                return self.addStatus
            }, copyMatching: { query in
                self.events.append("copy"); self.queries.append(query)
                return (self.copyStatus, self.copyItem)
            }, delete: { query in
                self.events.append("delete"); self.queries.append(query)
                if self.deleteStatus == errSecSuccess { self.value = nil }
                return self.deleteStatus
            })
    }
}
#endif
