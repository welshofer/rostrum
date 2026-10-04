# Line-break reuse integration — 2026-10-04

Registered and explicitly supplied font metrics now reuse the original-source
line breaks returned by shaping. The previous path computed those same breaks
twice. Latin and Arabic shaping preserve the original coordinates; fallback
Unicode and ASCII paths retain their existing behavior. No shaper policy,
mutable-DOM cache or serialization change is introduced.

One matched experiment measured registered rendering 0.76% faster and fitting
5.51% faster, with nine of ten pairs faster for each. Supplemental accented/CJK
and long-combining workloads improved 5.52% and 3.58%. Mixed RTL has mixed
statistical evidence, whole-process RSS is mixed, and substantial WindowServer
load remains a limitation. These results use their own accepted post-reservation
baseline; gains are not summed. The
[performance report](LAYOUT-PERFORMANCE-20261004-10.md) retains the complete
protocol and statistical qualifications.

Independent review accepted source equivalence and the frozen evidence. Exact
preservation includes 1,728 complete layout/DOM records across three font modes,
101,022 main and 288 supplementary shaping records, 114 cases over 780 slides,
and 273 saved-file reopens. Root rehashed all 115 manifest pins; the worker's
full preservation pass checked 5,250 artifact/input hashes.

## Integrated verification

At `7fbb9bc`, the full `./scripts/verify.sh` gate exits successfully:

- 1,140 Rostrum tests in 161 suites and 18 layout tests in three suites.
- 281 Lectern Core tests in 38 suites and 76 native app tests in 21 suites,
  representing 106 executions, with zero failures, skips or known issues.
- Offline checks, README examples, signed macOS and arm64/x86_64 iOS simulator
  builds, and the actual rebuilt app inspector/export tests.
- 26 Lab recipes and 362 passing checks; 56 independent ZIP/python-pptx reopens
  covering 199 slides. All 302 external input files remained unchanged and were
  independently rehashed by root.

The initial quiet macOS/iOS builds emitted five contradictory messages saying a
compiler command failed with exit code zero. Both build stages returned success
and the app tests passed. Additional canonical, nonquiet incremental builds
explicitly report `BUILD SUCCEEDED` with no error lines. The original diagnostics
and both confirmation logs are preserved; no source/settings change or error
suppression was used.

Both final six-slide paragraph files exactly match the preceding gate and the
PowerPoint-accepted specimens. Prior native PDF and manual GUI evidence for
slides 2–6 transfers by strict byte identity. No fresh manual capture is claimed
for this line-break reuse change. The paragraph demo retains 54 passing checks
and zero findings; the full Lab retains 359 findings.

The [integration receipt](benchmarks/2026-10-04-break-reuse-integration-verification.json)
pins the source, gate, build confirmations, external reopens and evidence
transfer. Native glyph painting, explicit glyph positioning and the seventh
Lectern paragraph slide remain separate ongoing work.
