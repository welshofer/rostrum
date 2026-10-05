# Lectern credential persistence and test-session isolation

Saving a replacement API key previously deleted the existing Keychain item before adding its replacement. A failed add could therefore lose a working key. Replacement now updates only the secret data, preserving the existing item's access controls. An add occurs only after an explicit missing-item result; a duplicate-add race permits one update retry. Saving never deletes an item.

Only `errSecItemNotFound` means a credential is absent. Locked, denied, cancelled, unavailable, and malformed reads remain access failures. Metadata queries do not request secret bytes. Settings retains pasted input and the storage error after a failed save, and validates only after success. Failed removal keeps the previously known state. Keychain-unavailable copy is consistent across Settings, composition, and the library's empty state; it does not ask the user to replace a potentially intact credential.

All AppState credential actions share one injected dependency. Isolated sessions use a disabled store, disable live generation, and display a test-session banner. The dedicated test-host bundle flag also selects isolation when launched without a scheme environment. Availability refresh invalidates prior validation requests, and duplicate generation requests cannot change an active run's phase.

The production Keychain service (`com.lectern.app.apikeys`), account namespaces, and signing requirements are unchanged. No migration, deletion, access-control broadening, credential inspection, or production credential rewrite was performed during this repair. This establishes the source fixes; it does not establish whether a particular user's existing key is currently present or accessible.

## Verification

The exact application Swift sources, excluding the `@main` entry point, were compiled into a standalone SwiftPM library. The actual KeychainStoreTests and CredentialStateTests ran against fake or disabled credential operations: **19 test definitions, 25 executions, two suites, all passed**. This exercised replacement failure, add failure, duplicate-item races, denied reads, metadata availability, failed removal, namespaces, disabled sessions, and active-generation protection. Test-only preferences and filesystem paths were isolated.

Receipt and raw log: [credential safety evidence](verification/2026-10-04-credential-safety/headless-tests.json). Source hashes identify the tested snapshot. Subsequent independent changes require their own verification.

The earlier S22 full verification run was interrupted during its hosted-app stage and is **not a completed acceptance gate**. App-hosted tests, app launches, runtime Keychain verification, and replacing/relaunching the user's app remain deferred to preserve the active session. The headless check does not claim UI or native-app end-to-end acceptance.
