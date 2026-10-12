"""CPU comparisons must not inherit scheduling noise or invent missing samples."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BenchmarkReportingTests(unittest.TestCase):
    def compare(self, baseline_cpu):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            for name, wall, cpu in [("baseline", 100, baseline_cpu), ("candidate", 200, 5)]:
                sample = {"phases": {"render": wall}, "scenario": "control"}
                if cpu is not None:
                    sample["cpuPhases"] = {"render": cpu}
                binary = folder / name
                binary.write_text(
                    f"#!{sys.executable}\nimport os\nfrom pathlib import Path\n"
                    "Path(os.environ['ROSTRUM_BENCH_OUTPUT']).write_bytes(b'same saved bytes')\n"
                    f"print({json.dumps(sample)!r})\n"
                )
                binary.chmod(0o755)
            # The runner records the compiler version but does not build when
            # both binaries are supplied. This test needs no Swift toolchain.
            swift = folder / "swift"
            swift.write_text(f"#!{sys.executable}\nprint('test compiler')\n")
            swift.chmod(0o755)
            output = folder / "report.json"
            subprocess.run(
                [sys.executable, str(ROOT / "Tools/rostrum-bench/run.py"),
                 "--binary", str(folder / "candidate"),
                 "--paired-binary", str(folder / "baseline"),
                 "--runs", "2", "--warmups", "0", "--scenarios", "control",
                 "--output", str(output)],
                cwd=ROOT, env=dict(os.environ, PATH=str(folder) + os.pathsep + os.environ["PATH"]),
                check=True, capture_output=True,
            )
            return json.loads(output.read_text())["scenarios"]["control"]

    def test_scheduling_delay_is_distinct_from_cpu_work(self):
        result = self.compare(baseline_cpu=7)
        self.assertGreater(result["phases"]["render"]["candidate"]["medianMS"],
                           result["phases"]["render"]["baseline"]["medianMS"])
        self.assertEqual(result["cpuPhases"]["render"]["baseline"]["medianMS"], 7)
        self.assertEqual(result["cpuPhases"]["render"]["candidate"]["medianMS"], 5)

    def test_older_baseline_does_not_get_a_fabricated_cpu_comparison(self):
        result = self.compare(baseline_cpu=None)
        self.assertNotIn("cpuPhases", result)
        self.assertEqual(result["samples"]["candidate"][0]["cpuPhases"]["render"], 5)


if __name__ == "__main__":
    unittest.main()
