# Publication hygiene and reconciliation

This update reconciles the imported-fidelity documentation based on `40f28e5`
with published `main` at `4df1c71`, which includes PR #39 and 122 subsequent
commits relative to that base. The combined branch preserves that ancestry and
the later table, image-ownership, credential-safety and demo-persistence work.
The original dirty checkout and external recovery snapshots were preserved.
This receipt covers published repository history; it does not certify the
absence of unpublished work on another device.

## Documentation and attribution

The new [layout engine guide](LAYOUT-ENGINE.md) distinguishes shared text geometry,
native glyph painting, live table-cell context, template composition, authored
fitting and pagination. The [preview guide](IMPORTING-AND-PREVIEWING.md) explains
font registration, explicit fallback and fidelity diagnostics. The performance
ledger retains separate baselines and does not add historical percentages.

The README's **Acknowledgments** and **License** sections, `LICENSE` and
`THIRD_PARTY_LICENSES.md` remain byte-for-byte unchanged from `40f28e5`.
The project's acknowledgment of python-pptx, Steve Canny's work, derived schema
attribution and use of python-pptx as a release oracle is preserved.

## Publication cleanup

- Generalized private home-directory paths in tracked documentation and benchmark
  receipts without changing recorded timing values or historical source hashes.
- Removed the private maintainer contact address, private template identifiers,
  escaped home paths, local user names and personal signing identities in logs.
- Replaced personal author metadata in three owned PPTX fixtures with synthetic
  fixture values. Every other uncompressed ZIP member is byte-identical to its
  original. Updated the current fixture manifest and kept prior acceptance hashes
  explicitly separate from the sanitized hashes.
- Ignored local `.env` files while retaining deliberately checked-in examples.
  Local signing configuration and private evidence remain outside Git.

The audit covers tracked text, XML/relationship/text/JSON members inside tracked
ZIP packages and metadata and extracted text in 54 tracked PDFs. Public repository URLs, reserved
`example.com` addresses, synthetic fixture identities and required third-party
copyright/license attribution are retained. These are not private user records.
No private identity, private contact address, personal home path, profanity,
private key or confirmed API credential was found in the reviewed current tree.

A redacted Gitleaks scan of reachable history through integration commit
`a7a64ca` reported 785 heuristic matches. Review of the original lines classified 784 as recorded
SHA-256 checksums and one as a historical Keychain access-group identifier;
none was a credential. A separate current-tree scan reported 738 matches, all
recorded SHA-256 checksums. No broad detector exclusion or credential-looking value
was added to silence the scan. Local raw reports are not publication artifacts.

## History boundary

Current-tree cleanup does not erase private paths, contact information or old
fixture metadata from prior commits. This update does not rewrite Git history.
It must not be described as retroactive removal from every clone, fork or hosted
cache. Any history purge requires a separate coordinated migration. Public Git
attribution and third-party licenses are not removed as personal-data cleanup.

## Validation

The preview-guide Swift example typechecks against the reconciled library.
The Linux failure in the saved-file table kerning test was caused by relying on
installed fonts: its native-profile assertion now uses an embedded licensed
DejaVu Sans face, with an assertion that inspection recovered that face. All
three kerning thresholds pass locally without changing production layout rules.

The full local gate on the combined main tree passed 1,218 Rostrum tests,
18 layout tests and 315 LecternCore tests, plus offline checks, README examples
and macOS/iOS simulator builds. The app-hosted run passed 124 of 125 definitions.
Its one failure was a stale template-selection expectation: an isolated test
session deliberately rejects generation before credential validation, so it
must report the test-session advice rather than a missing-key error.

The test now checks that exact isolation result after the pending template is
cancelled, while retaining the assertions that a pending template blocks the
action without changing generation state. Production credential behavior is
unchanged. The complete TemplateSelectionTests and CredentialStateTests suites
then passed all 15 definitions. The other 124 app tests passed in the full run;
the entire app stage was not repeated after this test-only correction.

The native acceptance records remain scoped to the cases they actually cover;
see [checkpoint 17](LAYOUT-FIDELITY-20261004-17.md),
[checkpoint 16](LAYOUT-FIDELITY-20261004-16.md) and
[checkpoint 15](LAYOUT-FIDELITY-20261004-15.md). Publication documentation does
not turn a computed-fit or preservation check into a native pixel-fidelity claim.

All three sanitized PPTX fixtures opened in native PowerPoint without repair
using `Tools/ppt-check.sh` and isolated copies. The manifest records their current
hashes separately from prior visual acceptance. This proves opening, not a new
pixel-fidelity comparison.
