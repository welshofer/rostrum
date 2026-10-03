## What & why

<!-- One paragraph. Link the issue if there is one. -->

## Checklist

- [ ] `./scripts/verify.sh` passes; disclose if only `--fast` ran (it excludes app builds and app-hosted tests)
- [ ] Rostrum remains dependency-free; Lectern uses its documented local dependency/platform boundaries
- [ ] Rostrum and the headless LecternCore path remain portable across macOS, iOS, and Linux
- [ ] Round-trip safety: opening + saving an untouched deck stays byte-identical
- [ ] Output verified against an oracle where relevant (`unzip -t`,
      python-pptx open, or `Tools/ppt-check.sh`)
- [ ] Determinism preserved: same input → byte-identical output
