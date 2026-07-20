## What & why

<!-- One paragraph. Link the issue if there is one. -->

## Checklist

- [ ] `swift test` passes (and `cd Lectern && swift test` if LecternCore is touched)
- [ ] No new SwiftPM dependencies (zero-dependency rule — see CONTRIBUTING.md)
- [ ] No APIs missing on macOS, iOS, or Linux (notably `XMLDocument`/`XMLNode`)
- [ ] Round-trip safety: opening + saving an untouched deck stays byte-identical
- [ ] Output verified against an oracle where relevant (`unzip -t`,
      python-pptx open, or `Tools/ppt-check.sh`)
- [ ] Determinism preserved: same input → byte-identical output
