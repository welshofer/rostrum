# Lectern credential persistence and test-session isolation

Saving a replacement API key previously deleted the existing Keychain item before adding its replacement. A failed add could therefore lose a working key. Replacement now updates only the secret data, preserving the existing item's access controls. An add occurs only after an explicit missing-item result; a duplicate-add race permits one update retry. Saving never deletes an item.

Only `errSecItemNotFound` means a credential is absent. Locked, denied, cancelled, unavailable, and malformed reads remain access failures. Metadata queries do not request secret bytes. Settings retains pasted input and the storage error after a failed save, and validates only after success. Failed removal keeps the previously known state. Keychain-unavailable copy is consistent across Settings, composition, and the library's empty state; it does not ask the user to replace a potentially intact credential.

All AppState credential actions share one injected dependency. Isolated sessions use a disabled store, disable live generation, and display a test-session banner. The dedicated test-host bundle flag also selects isolation when launched without a scheme environment. Availability refresh invalidates prior validation requests, and duplicate generation requests cannot change an active run's phase.

The production Keychain service (`com.lectern.app.apikeys`), account namespaces, and signing requirements are unchanged. No migration, deletion, access-control broadening, credential inspection, or production credential rewrite was performed during this repair. This establishes the source fixes; it does not establish whether a particular user's existing key is currently present or accessible.

## Verification

The exact application Swift sources, excluding the `@main` entry point, were compiled into a standalone SwiftPM library. The actual KeychainStoreTests and CredentialStateTests ran against fake or disabled credential operations: **19 test definitions, 25 executions, two suites, all passed**. This exercised replacement failure, add failure, duplicate-item races, denied reads, metadata availability, failed removal, namespaces, disabled sessions, and active-generation protection. Test-only preferences and filesystem paths were isolated.

Receipt and raw log: [credential safety evidence](verification/2026-10-04-credential-safety/headless-tests.json). Source hashes identify the tested snapshot. Subsequent independent changes require their own verification.

The earlier S22 full verification run was interrupted during its hosted-app stage and is **not a completed acceptance gate**. App-hosted tests, app launches, runtime Keychain verification, and replacing/relaunching the user's app remain deferred to preserve the active session. The headless check does not claim UI or native-app end-to-end acceptance.

## Hosted-test product separation

`LecternTests` now builds and hosts tests in `LecternTestHost.app`, with bundle ID `com.lectern.app.testhost`, its own executable name, and the explicit test-session Info.plist flag. The normal app retains its identity and build settings. The test script defaults to `.build-xcode-tests`, preserves the stable signing configuration, and refuses to start if either app is already running or process inspection fails. It checks again after project generation and never terminates an app. A dedicated `LECTERN_TEST_DERIVED_DATA_PATH` override prevents the production `LECTERN_DERIVED_DATA_PATH` override from selecting the same products directory.

Five mocked/static wrapper tests passed, including an app becoming active during project generation, process-query failure, preserved normal identity, the generated test host/scheme mapping, and separate derived-data overrides. These checks invoke XcodeGen in temporary directories and mocked build commands; they do not launch or build an app. Runtime hosted-test acceptance remains deferred.


## Integrated credential and demo persistence checks

After integrating automatic demo persistence, the exact application source was compiled and tested again without an app entry point: **26 definitions, 33 executions, three suites passed** in 65.645 seconds. The full 33-demo catalog persisted a byte-exact saved deck for each completed result. Additional checks cover reopening through a fresh AppState and the inspector, preserving prior runs, failed-check results, save errors, cancellation and retired tasks. The four focused Core storage tests also passed.

The normal macOS app builds successfully using the canonical script into a separate `/tmp/lectern-credential-repair-build-20261004` directory. Its designated signing requirement matches the pre-existing development-signed app. It was not opened or copied over an existing app. These checks add compile-time and headless workflow evidence; hosted testing, actual UI interaction, and user Keychain access remain unperformed. See the [combined receipt](verification/2026-10-04-credential-safety/persistence-and-credentials-headless.json).
