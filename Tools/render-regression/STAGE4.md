# Construction comparison methodology

`compare_construction.py` accepts already-built `rostrum-bench` executables.
It does not build, edit source, invoke PowerPoint, or run the test suite.
No construction result is claimed by adding this runner.

Supply both executable paths, source roots, declared revisions, and the actual
build commands and flags. Use new paths for `--output` and `--work-dir`; even an
existing empty work directory is refused. All benchmark Swift source files must
have identical paths and bytes in both supplied source trees.

```sh
python3 Tools/render-regression/compare_construction.py \
  --baseline /path/to/baseline/rostrum-bench \
  --candidate /path/to/candidate/rostrum-bench \
  --baseline-source /path/to/baseline-source \
  --candidate-source /path/to/candidate-source \
  --baseline-revision BASELINE_REVISION \
  --candidate-revision CANDIDATE_REVISION \
  --baseline-build-command 'ACTUAL BASELINE BUILD COMMAND' \
  --candidate-build-command 'ACTUAL CANDIDATE BUILD COMMAND' \
  --baseline-build-flags='ACTUAL BASELINE FLAGS' \
  --candidate-build-flags='ACTUAL CANDIDATE FLAGS' \
  --output /path/to/new-construction-report.json \
  --work-dir /path/to/new-construction-artifacts
```

Defaults are 10, 100 and 1,000 slides, one excluded warmup pair per scenario,
and ten measured pairs. Each sample gets a fresh process; measured order
alternates baseline/candidate then candidate/baseline. Neither variant runs
concurrently. `--runs` accepts 10–100 pairs. `--slide-counts` permits up to eight
distinct scenarios of at most 5,000 slides each. `--phase` changes the primary
reported phase from `construct`; every phase is retained regardless.

Construction uses the original driver's loop and text settings. The driver
writes its saved PPTX after all timed phases, using a unique
`ROSTRUM_BENCH_OUTPUT` path for every invocation. All samples, including warmups,
must have matching captured PPTX SHA-256 and byte counts across both variants.
Reported output size must also match the captured file. The SVG-derived
`checksum` is retained in raw samples but is not an equality gate, because
renderer semantics can differ even when the serialized presentation is exact.

Every invocation retains its raw stdout JSON and stderr. The first measured
PPTX per variant/scenario is retained, along with each scenario's initial baseline
PPTX as a mismatch reference; other matching copies are removed after hashing.
A mismatch retains its PPTX and fails. Failed runs leave a failure
report and partial artifacts, never a completed report at `--output`.

The runner hashes all actual `Sources` files, `Package.swift`, optional
`Package.resolved`, all files under the original benchmark target, executables, and itself
before and after measurement, and rejects changes. An optional `--font` is also
hashed; it only enables the driver's separate post-render text-fitting phase.
Without that option, benchmark font variables are removed. Rendering does not
register fonts. Other host environment settings are inherited.

Actual file hashes establish the measured inputs and detect changes during the
run. Build commands, flags, revisions, and source-to-executable correspondence
remain caller-supplied provenance. Run after builds and other heavy work stop.
Median ratios, individual pair ratios/deltas, ranges, and every phase sample are
reported without an automatic speedup threshold. Observed p95 is a small-sample
quantile. Saved-PPTX equality does not establish SVG or Office fidelity, and
unchanged output does not prove that changed library internals do identical work.
