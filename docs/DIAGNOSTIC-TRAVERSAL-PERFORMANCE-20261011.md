# Diagnostic traversal — October 11, 2026

The diagnostic scanner now queues child elements in one forward pass, then
reverses only the newly queued entries to preserve document order. This removes
an intermediate child array and the second sibling-counting pass. It keeps
same-name path indices, hidden-child handling, group ownership, inline-style
selection and inspection of malformed descendants unchanged.

The initial isolated Release profile put diagnostic scanning at 49.64 ms of
282.39 ms process CPU on the 10,000-cell fallback table (about 18%). Text layout
used 80.08 ms and text SVG emission 70.26 ms. These instrumented, inclusive
phases identify where work occurs; nested phase totals must not be added.
Instrumentation lives in a separate scratch source copy, not the library.

A five-pair instrumented follow-up measures scanner CPU at 49.11 → 44.41 ms
(about 9.6% lower), while text layout stays near 81 ms and text emission near
71 ms. The production measurements below use uninstrumented library builds.

## Paired production measurements

The [measurement record](benchmarks/2026-10-11-diagnostic-traversal.json) includes
raw render samples, input/output and binary hashes, source hashes, CPU model,
Swift version, and the proof corpus. The baseline is the validated workspace
after the grouped-diagnostic fix, including its earlier uncommitted fidelity
work; it is **not** clean `15315cc3`. Only `RenderDiagnostics.swift` changes
between these library builds. Both binaries use the same CPU-capable driver.

Swift 6.1.3 Release binaries ran on Linux x86_64 with five CPUs available to the
process. Each scenario had two warmup pairs and 15 alternating AB/BA fresh-process
pairs. No builds or tests ran concurrently. Arial regular was supplied for the
registered-font scenario; its hash is recorded and its bytes remain outside Git.

| Render workload | CPU median, baseline → candidate | Change | Faster pairs |
| --- | --- | --- | --- |
| Fallback table, 200 cells | 4.507 → 4.457 ms | −1.11% | 10/15 |
| Fallback table, 10,000 cells | 261.410 → 256.779 ms | −1.77% | 14/15 |
| Registered Arial table, 2,000 cells | 101.500 → 103.201 ms | +1.68% | 8/15 |
| 250 distinct images | 3.529 → 3.362 ms | −4.73% | 15/15 |
| 200 nested shadow shapes | 8.481 → 8.315 ms | −1.96% | 10/15 |

The large table's elapsed median changes from 261.427 to 256.783 ms (−1.78%).
The image control also improves consistently. The registered-font table remains
inconclusive: its ratio of medians worsens while the median matched-pair time
improves 2.22%, with broad overlapping ranges. Smaller cases also have overlapping
ranges. These results establish a modest workload-specific improvement, not a
general speedup or a regression budget. They do not settle the earlier noisy
8% table observation, and percentages from different baselines must not be added.

Process CPU time is now recorded beside elapsed time in the reusable benchmark.
It separates CPU work from descheduling, but processor frequency and shared-host
contention still affect measurements. Whole-process peak RSS is approximately
unchanged; no per-render allocation or memory improvement is claimed. Older
baseline binaries continue to work, with CPU comparisons omitted when unavailable.

## Preservation and limits

Across 20 fixtures and 265 slides, all 815 proof files are byte-identical:
SVGs, ordered fidelity diagnostics, inheritance reports and saved PPTX files.
Every saved archive passes a CRC check and reopens with python-pptx. The corpus
includes native table styles, defaults, fallback styles, joins, transitions,
double borders, typography, image mapping and the synthetic grouped-shadow and
large-table stress fixtures. Rendering also leaves saved bytes unchanged.

`scripts/verify.sh --fast` passes with 1,249 root Swift tests, 309 LecternCore
tests, 12 conformance Python tests, 12 workflow Python tests (and two
XcodeGen-dependent skips), and both runnable README examples. All 36 saved
PowerPoint image comparisons pass at the unchanged channel-16 / fraction-0.005
limits. Workflow YAML parses; the new iOS simulator step still awaits remote
Apple CI execution.

This preservation proof does not establish broader native visual equivalence.
The synthetic stress decks are not independent PowerPoint references. Live
PowerPoint acceptance and Apple application execution require their respective
platforms; uploaded fonts do not close the historical full-typography gate.
