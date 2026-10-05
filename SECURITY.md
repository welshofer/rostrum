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
