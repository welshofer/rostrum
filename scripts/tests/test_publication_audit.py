"""Check scope boundaries and redaction with deliberately synthetic inputs."""

import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile


SPEC = importlib.util.spec_from_file_location(
    "publication_audit", Path(__file__).resolve().parents[1] / "publication-audit.py"
)
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


class PublicationAuditTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.git("init", "--quiet")
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.com",
                 "commit", "--allow-empty", "--quiet", "-m", "Synthetic fixture")

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], stderr=subprocess.DEVNULL)

    def test_candidates_are_redacted_in_text_and_archived_xml(self):
        candidate = "sk-proj-" + "syntheticOnly1234567890" * 3
        (self.root / "example.txt").write_text("example\n" + candidate + "\n")
        with zipfile.ZipFile(self.root / "example.pptx", "w") as archive:
            archive.writestr("ppt/slides/slide1.xml", "<text>" + candidate + "</text>")
        self.git("add", "example.txt", "example.pptx")
        report = AUDIT.audit(self.root, False)
        self.assertEqual(report["finding_counts"], {"provider_credential_candidate": 2})
        self.assertEqual(report["counts"]["archive_text_members"], 1)
        self.assertNotIn(candidate, json.dumps(report))
        self.assertEqual({entry["path"] for entry in report["findings"]},
                         {"example.txt", "example.pptx!ppt/slides/slide1.xml"})

    def test_nonignored_untracked_scope_preserves_ignored_files(self):
        (self.root / ".gitignore").write_text(".env\n.signing.local\n")
        self.git("add", ".gitignore")
        # A candidate is present only in private ignored inputs.
        candidate = "ghp_" + "syntheticOnly1234567890" * 2
        (self.root / ".env").write_text(candidate)
        (self.root / ".signing.local").write_text(candidate)
        (self.root / "public.txt").write_text("Public fixture text.")
        tracked = AUDIT.audit(self.root, False)
        prepared = AUDIT.audit(self.root, True)
        self.assertEqual(tracked["counts"]["files"], 1)
        self.assertEqual(prepared["counts"]["files"], 2)
        self.assertEqual(prepared["findings"], [])
        self.assertEqual(prepared["limitations"], [])

    def test_profanity_is_located_without_echoing_it(self):
        word = "\u0066\u0075\u0063\u006b\u0069\u006e\u0067"
        (self.root / "example.txt").write_text("First line\n" + word + "\n")
        self.git("add", "example.txt")
        report = AUDIT.audit(self.root, False)
        self.assertEqual(report["findings"], [{"category": "profanity", "path": "example.txt", "line": 2}])
        self.assertNotIn(word, json.dumps(report))

    def test_tracked_symlinks_do_not_read_their_targets(self):
        (self.root / "link.txt").symlink_to(self.root / "unavailable-private-input.txt")
        self.git("add", "link.txt")
        report = AUDIT.audit(self.root, False)
        self.assertEqual(report["findings"], [])
        self.assertEqual(report["limitations"], [{"path": "link.txt", "reason": "symlink not followed"}])


if __name__ == "__main__":
    unittest.main()
