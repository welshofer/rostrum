# Security policy

## Supported versions

Rostrum provides security fixes for the latest published release. Older releases
do not have a separate maintenance commitment.

## Reporting a vulnerability

Please do **not** open a public issue for a suspected vulnerability. Use
[GitHub private vulnerability reporting](https://github.com/welshofer/rostrum/security/advisories/new)
so the report and any reproduction material remain private. We aim to
acknowledge reports within seven days.

Include the affected version, platform, impact, and the smallest safe
reproduction you can provide. Do not include live credentials or confidential
documents.

## Security scope

Rostrum parses untrusted PowerPoint files. Reports involving malformed archives,
decompression limits, XML handling, hangs, crashes, unexpected network access,
or disclosure of document contents are in scope.

Lectern stores provider API keys in the system Keychain. A path that writes a
key to preferences, logs, repository files, or an unintended network
destination is also a security issue.

## Disclosure

Please allow time to investigate and publish a fix before public disclosure.
When a report is confirmed, the project will coordinate remediation and release
notes with the reporter.

## Scope notes

- Rostrum parses untrusted `.pptx` files. The zip container and DEFLATE
  decoder are hand-written here; XML is tokenized by Foundation's `XMLParser`
  (libxml2) and modeled by Rostrum's own tree, with hazardous constructs
  rejected before the parser sees them. Malformed-input crashes, hangs
  (decompression bombs, entity expansion), and memory-safety issues in
  `Sources/Rostrum/Zip`, `XML`, and `OPC` are in scope and taken seriously.
  The fuzz suite (`FuzzTests`) is the first line of defense — reproduction
  cases are welcome in reports.
- Reads are budgeted by default: `Presentation(data:limits:)` and
  `OPCPackage.read` apply `ZipReader.Limits.default` (4 GiB of declared
  uncompressed bytes) before anything is decompressed, and document type
  declarations are rejected outright. For hostile input, pass a tighter
  budget — `Tools/pptx-tool` uses 1 GiB — rather than `.unlimited`.
- The Lectern sample app sends prompts and source material to OpenAI (its only
  generation provider) and stores the API key in the system Keychain only. A path that writes a key
  anywhere else (defaults, logs, network other than the key's own provider)
  is a security bug.

## Publication hygiene

Before publishing, review the complete tracked tree and proposed diff for
credentials, private contact details and local machine paths. Inspect archived
fixtures too: PPTX files can contain creator identities, comment-author IDs,
notes and embedded documents. Keep private decks, proprietary fonts, provider
responses and local signing settings outside version control. Use synthetic
identities and reserved example domains for test data; retain required licenses
and attribution.

Run a redacted secret scan of both the publication snapshot and reachable Git
history. Investigate matches without copying candidate secrets into logs or PRs;
checksums and identifiers can be false positives. If a credential is found,
revoke or rotate it before relying on removal. Removing a tracked value does
not remove it from old commits, forks or caches. See the
[publication hygiene record](docs/PUBLICATION-HYGIENE.md) for the prior cleanup's
scope and limitations, and the [1.0 release audit](docs/RELEASE-1.0-AUDIT.md) for
the current publication review.

The focused check can be repeated with
`python3 scripts/publication-audit.py --include-untracked`. It scans Git-selected
text, textual ZIP/PPTX members, and PDF metadata and extracted text, and reports
only paths, categories and line numbers. It requires `pdfinfo` and `pdftotext` for
the PDF checks. Run a separate redacted Gitleaks scan for its provider-specific
rules and reachable Git history; the focused check does not replace that review.
