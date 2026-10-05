"""No app launch: process checks and xcodebuild are mocked in owned temp trees."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]

class AppTestPreflightTests(unittest.TestCase):
    def test_active_apps_or_failed_inspection_stop_before_any_generation(self):
        for blocked in ('Lectern', 'LecternTestHost', 'inspection-error'):
            with self.subTest(blocked=blocked), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                (root / 'scripts').mkdir()
                shutil.copy(ROOT / 'Lectern/scripts/test-app.sh', root / 'scripts/test-app.sh')
                (root / 'scripts/generate-project.sh').write_text('touch generated\n')
                (root / 'bin').mkdir()
                probe = root / 'bin/pgrep'
                probe.write_text('#!/bin/bash\nif [ "$BLOCKED" = inspection-error ]; then exit 2; fi\n[ "$2" = "$BLOCKED" ]\n')
                probe.chmod(0o755)
                builder = root / 'bin/xcodebuild'
                builder.write_text('#!/bin/bash\ntouch built\n')
                builder.chmod(0o755)
                env = dict(os.environ, PATH=str(root / 'bin') + os.pathsep + os.environ['PATH'], BLOCKED=blocked)
                result = subprocess.run(['/bin/bash', str(root / 'scripts/test-app.sh')], env=env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((root / 'generated').exists())
                self.assertFalse((root / 'built').exists())
                self.assertIn('error:', result.stderr)
                if blocked != 'inspection-error':
                    self.assertIn(blocked + ' is running', result.stderr)
                    self.assertIn('no process was stopped', result.stderr)

    def test_app_starting_during_generation_still_prevents_test_execution(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'scripts').mkdir()
            shutil.copy(ROOT / 'Lectern/scripts/test-app.sh', root / 'scripts/test-app.sh')
            (root / 'scripts/generate-project.sh').write_text('touch app-started\n')
            (root / 'bin').mkdir()
            probe = root / 'bin/pgrep'
            probe.write_text('#!/bin/bash\n[ -f app-started ] && [ "$2" = Lectern ]\n')
            probe.chmod(0o755)
            builder = root / 'bin/xcodebuild'
            builder.write_text('#!/bin/bash\ntouch built\n')
            builder.chmod(0o755)
            env = dict(os.environ, PATH=str(root / 'bin') + os.pathsep + os.environ['PATH'])
            result = subprocess.run(['/bin/bash', str(root / 'scripts/test-app.sh')], env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue((root / 'app-started').exists())
            self.assertFalse((root / 'built').exists())
            self.assertIn('Lectern is running', result.stderr)

    @unittest.skipUnless(shutil.which('xcodegen'), 'XcodeGen required')
    def test_generated_test_host_is_separate_and_normal_identity_is_unchanged(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            shutil.copy(ROOT / 'Lectern/project.yml', root / 'project.yml')
            for directory in ['App/Resources/Styles', 'AppTests/Fixtures']:
                (root / directory).mkdir(parents=True)
            subprocess.run(['xcodegen', 'generate', '--quiet'], cwd=root, check=True, capture_output=True)
            project = (root / 'Lectern.xcodeproj/project.pbxproj').read_text()
            self.assertIn('PRODUCT_BUNDLE_IDENTIFIER = com.lectern.app;', project)
            self.assertIn('PRODUCT_BUNDLE_IDENTIFIER = com.lectern.app.testhost;', project)
            self.assertIn('PRODUCT_MODULE_NAME = Lectern;', project)
            self.assertIn('INFOPLIST_KEY_LecternTestHost = YES;', project)
            self.assertIn('TEST_HOST = "$(BUILT_PRODUCTS_DIR)/LecternTestHost.app/Contents/MacOS/LecternTestHost";', project)
            self.assertNotIn('TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Lectern.app/', project)
            schemes = root / 'Lectern.xcodeproj/xcshareddata/xcschemes'
            normal = ET.parse(schemes / 'Lectern.xcscheme')
            self.assertEqual(normal.findall('.//TestableReference'), [])
            tests = ET.parse(schemes / 'LecternTests.xcscheme')
            self.assertEqual([r.attrib['BlueprintName'] for r in tests.findall('.//TestableReference/BuildableReference')], ['LecternAppTests'])
            self.assertEqual(tests.find('.//MacroExpansion/BuildableReference').attrib['BuildableName'], 'LecternTestHost.app')

if __name__ == '__main__':
    unittest.main()
