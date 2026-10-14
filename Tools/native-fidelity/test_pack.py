#!/usr/bin/env python3
"""Integration checks against a built executable; no native acceptance implied."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile

from run import collect

ROOT = Path(__file__).resolve().parents[2]
NS = {"a": "http://schemas.openxmlformats.org/drawingml/2006/main",
      "p": "http://schemas.openxmlformats.org/presentationml/2006/main"}


class FidelityPackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = Path(os.environ.get("ROSTRUM_NATIVE_FIDELITY_BINARY", ROOT / ".build/debug/native-fidelity"))
        if not cls.binary.is_file():
            raise RuntimeError("Build native-fidelity before running this suite")
        cls.temp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temp.cleanup)
        cls.directory = Path(cls.temp.name)
        fixture = ROOT / "Tests/RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts"
        cls.config = {"family": "DejaVu Sans", "regular": str(fixture / "DejaVuSans.ttf"),
                      "bold": str(fixture / "DejaVuSans-Bold.ttf"), "italic": str(fixture / "DejaVuSans-Oblique.ttf")}
        cls.fonts = cls.directory / "fonts.json"
        cls.fonts.write_text(json.dumps(cls.config))
        cls.output = cls.directory / "pack"
        cls.manifest = collect(cls.binary, cls.fonts, cls.output, runs=2, build_mode="unspecified")

    def test_four_profiles_repeat_identically_but_stay_unreviewed(self):
        self.assertTrue(self.manifest["complete"])
        self.assertEqual(len(self.manifest["profiles"]), 4)
        for key in ("powerpointSlideView", "powerpointExport", "lecternInspect"):
            self.assertEqual(self.manifest[key], "pending")
        for profile in self.manifest["profiles"]:
            first, second = profile["samples"]
            self.assertEqual(first["artifactSHA256"], second["artifactSHA256"])
            self.assertGreater(first["peakRSSBytes"], 0)
            self.assertGreater(first["userCPUSeconds"] + first["systemCPUSeconds"], 0)

    def test_native_content_geometry_and_font_storage(self):
        for profile in self.manifest["profiles"]:
            case = self.output / profile["samples"][0]["directory"]
            report = json.loads((case / "report.json").read_text())
            with zipfile.ZipFile(case / "deck.pptx") as deck, zipfile.ZipFile(case / "input.potx") as template:
                size = ET.fromstring(deck.read("ppt/presentation.xml")).find("p:sldSz", NS)
                self.assertEqual(int(size.attrib["cy"]), 540 * 12700)
                self.assertEqual(int(size.attrib["cx"]), (720 if report["aspect"] == "4x3" else 960) * 12700)
                embedded = ET.fromstring(deck.read("ppt/presentation.xml")).find("p:embeddedFontLst", NS)
                self.assertEqual(embedded is not None, report["fontMode"] == "embedded")
                if embedded is not None:
                    for role in ("regular", "bold", "italic"):
                        self.assertIsNotNone(embedded.find(f"p:embeddedFont/p:{role}", NS))
                for name in template.namelist():
                    if name.startswith(("ppt/slideLayouts/", "ppt/slideMasters/", "ppt/theme/")):
                        self.assertEqual(template.read(name), deck.read(name), name)
                first_slide = ET.fromstring(deck.read("ppt/slides/slide1.xml"))
                self.assertIn("Rostrum in Lectern", "".join(first_slide.itertext()))
                self.assertEqual(len(first_slide.findall(".//a:br", NS)), 2)
                self.assertIn("Indented line retained", "".join(first_slide.itertext()))
                styles = [node.attrib for node in first_slide.findall(".//a:rPr", NS)]
                self.assertTrue(any(p.get("b") == "1" for p in styles))
                self.assertTrue(any(p.get("i") == "1" for p in styles))
                self.assertTrue(any(p.get("sz") == "2200" for p in styles))
                self.assertEqual([row for page in report["pages"] for row in page["sourceRows"]], list(range(1, 25)))
                for page in report["pages"]:
                    root = ET.fromstring(deck.read(f"ppt/slides/slide{page['slide']}.xml"))
                    table = root.find(".//a:tbl", NS)
                    rows = table.findall("a:tr", NS)
                    self.assertEqual(rows[0].find("a:tc", NS).attrib.get("gridSpan"), "2")
                    for native, source in zip(rows[1:], page["sourceRows"]):
                        texts = ["".join(cell.itertext()) for cell in native.findall("a:tc", NS)]
                        self.assertEqual(texts, [f"Record {source}",
                            f"Exact source evidence {source} stays editable and wraps at full size.", "Reviewed"])
                    self.assertEqual([int(row.attrib["h"]) for row in rows], page["rowHeightsEMU"])

    def test_refuses_existing_output(self):
        with self.assertRaisesRegex(ValueError, "already exists"):
            collect(self.binary, self.fonts, self.output)
        result = subprocess.run([str(self.binary), str(self.fonts), str(self.output), "4x3", "external"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already exists", result.stderr)

    def assert_invalid_font(self, change, message):
        with tempfile.TemporaryDirectory(dir=self.directory) as temporary:
            directory = Path(temporary)
            config = dict(self.config, **change)
            path = directory / "fonts.json"
            path.write_text(json.dumps(config))
            output = directory / "result"
            result = subprocess.run([str(self.binary), str(path), str(output), "4x3", "external"], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(message, result.stderr)
            self.assertFalse(output.exists())

    def test_face_substitution_is_rejected(self):
        self.assert_invalid_font({"regular": self.config["bold"]}, "expected exact family")

    def test_family_substitution_is_rejected(self):
        self.assert_invalid_font({"family": "Calibri"}, "expected exact family")

    def test_missing_face_is_rejected(self):
        self.assert_invalid_font({"italic": str(self.directory / "absent.ttf")}, "native-fidelity:")


if __name__ == "__main__":
    unittest.main()
