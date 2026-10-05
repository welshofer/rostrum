# Rostrum 1.0 publication review

Reviewed on October 4, 2026 (America/Los_Angeles), against the working-tree release
candidate based on `8c069ec37a69cb39424af90b7099422bb7d0ea70`.

## Results

| Review | Result |
| --- | --- |
| Git-selected source and documentation | No matched profanity, private-key material, provider-credential candidate, Google-key candidate or personal home path |
| Archived documents | 104 ZIP/PPTX packages; 4,429 textual members inspected |
| PDF evidence | Metadata and extracted text inspected in all 54 tracked PDFs |
| Gitleaks working-tree snapshot | 738 heuristic findings, all recorded SHA-256 checksums |
| Gitleaks reachable history | 1,521 heuristic findings: 1,520 recorded SHA-256 checksums and one historical Keychain access-group identifier |
| Unresolved credential candidates | None after contextual review |
| Attribution | python-pptx acknowledgment and licensing retained |

The history scan covered every locally reachable reference, including work
branches. Its larger count is not comparable to a scan restricted to `main`.
The access-group value is an application-signing identifier, not a credential.
Hash findings were checked against their original JSON records and the artifact,
source-file, binary or receipt fields they identify. No detector-wide exclusion
was added to suppress these findings.

Gitleaks 8.30.1 was downloaded from its upstream release, and the archive was
checked against the upstream SHA-256 list. Both scans used full redaction.
The current-tree scan used an isolated copy of Git-selected files, including
the nonignored release additions, with archive traversal enabled. Local raw
scanner reports are not included in the release.

## Repeatable focused check

```sh
python3 scripts/publication-audit.py --include-untracked --output /tmp/rostrum-publication-audit.json
python3 -m unittest discover -s scripts/tests -p test_publication_audit.py -v
```

The script examines UTF-8 text, textual ZIP/PPTX members and PDF metadata and
extracted text. Install `pdfinfo` and `pdftotext` for the PDF checks. Reports
contain categories, file paths and line numbers only; matching values are never
emitted. Four regression tests verify redaction, archive scanning, the ignored-file
boundary, profanity locations and refusal to follow symbolic links. The tests
use synthetic inputs in temporary Git repositories.

Use a separate redacted Gitleaks scan for its provider-specific detectors and
reachable history. Investigate its findings individually; a checksum-shaped
string alone is not enough to classify a candidate. Google browser/site keys,
if encountered in future reviews, require a separate context and restrictions
assessment rather than automatic classification as server credentials.

## Scope and preservation

No live API key or macOS Keychain entry was read, changed or deleted for this
review. Ignored environment files, local signing settings, private decks and
other ignored user files were outside the scan. The hygiene scans did not
start, stop or replace Lectern or PowerPoint. Documentation capture and native
table inspection are recorded separately in the [release validation](RELEASE-1.0-VALIDATION.md).

`LICENSE` and `THIRD_PARTY_LICENSES.md` remain byte-identical to the baseline.
The README keeps its acknowledgment of python-pptx and Steve Canny, the praise
for that library, and its MIT/derived-schema attribution. Public repository URLs,
reserved example addresses and required third-party legal notices are retained.

The focused text scan does not OCR image pixels or inspect arbitrary binary
image, audio, video or font payloads. Passing it does not establish the absence
of every possible credential or offensive phrase. Earlier identity cleanup and
its archived-fixture checks are recorded in [Publication hygiene](PUBLICATION-HYGIENE.md).

This release does not rewrite Git history or erase old personal paths and
metadata from prior commits, clones or hosted caches. No confirmed credential
was found that requires revocation or rotation. Library correctness, native
PowerPoint fidelity, performance measurements and release CI are separate
acceptance checks; this review is a publication-hygiene receipt.
