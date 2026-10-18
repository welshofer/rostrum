"""Failure annotations must preserve test status and remain one workflow command."""
import pathlib
import subprocess
import sys
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'ci-test.py'


class CIAnnotationTests(unittest.TestCase):
    def run_child(self, source):
        return subprocess.run([sys.executable, str(SCRIPT), sys.executable, '-c', source],
                              capture_output=True, text=True)

    def test_success_does_not_create_an_error(self):
        result = self.run_child("print('test passed')")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, 'test passed\n')

    def test_failure_preserves_status_and_escapes_context(self):
        result = self.run_child("print('✘ expectation at Example.swift:4:2: 100%')\nprint('::warning::context, not a new annotation')\nraise SystemExit(7)")
        self.assertEqual(result.returncode, 7)
        annotation = next(line for line in result.stdout.splitlines() if line.startswith('::error '))
        self.assertIn('100%25%0A::warning::context', annotation)
        self.assertIn('Example.swift:4:2', annotation)

    def test_unknown_failure_uses_a_bounded_tail(self):
        result = self.run_child("print('x' * 10000)\nprint('command stopped')\nraise SystemExit(3)")
        self.assertEqual(result.returncode, 3)
        annotation = next(line for line in result.stdout.splitlines() if line.startswith('::error '))
        self.assertIn('command stopped', annotation)
        self.assertLess(len(annotation), 6100)


if __name__ == '__main__':
    unittest.main()
