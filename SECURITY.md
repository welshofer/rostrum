# Security policy

## Supported versions

Rostrum is pre-1.0; only the latest release receives fixes.

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Use GitHub's
[private vulnerability reporting](https://github.com/welshofer/rostrum/security/advisories/new)
on this repository. You should receive an acknowledgment within a week.

## Scope notes

- Rostrum parses untrusted `.pptx` files: zip container, DEFLATE stream, and
  XML are all hand-written here, so malformed-input crashes, hangs
  (decompression bombs, entity expansion), and memory-safety issues in
  `Sources/Rostrum/Zip`, `XML`, and `OPC` are in scope and taken seriously.
  The fuzz suite (`FuzzTests`) is the first line of defense — reproduction
  cases are welcome in reports.
- Reads are budgeted by default: `Presentation(data:limits:)` and
  `OPCPackage.read` apply `ZipReader.Limits.default` (4 GiB of declared
  uncompressed bytes) before anything is decompressed, and document type
  declarations are rejected outright. For hostile input, pass a tighter
  budget — `Tools/pptx-tool` uses 1 GiB — rather than `.unlimited`.
- The Lectern sample app sends prompts to the LLM provider you configure and
  stores API keys in the system Keychain only. A path that writes a key
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
[publication audit](PUBLICATION-HYGIENE.md) for this update's scope and limitations.
