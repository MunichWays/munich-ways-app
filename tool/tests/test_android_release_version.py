import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "android_release_version.py"
spec = importlib.util.spec_from_file_location("android_release_version", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseVersionTest(unittest.TestCase):
    def test_failed_release_tag_81_with_pubspec_80_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "does not match pubspec.yaml"):
            module.validate_release("3.2.1+81", "version: 3.2.1+80\n")

    def test_matching_tag_and_pubspec_are_accepted(self):
        module.validate_release("3.2.1+81", "name: munich_ways\nversion: 3.2.1+81\n")

    def test_missing_version_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "does not match pubspec.yaml"):
            module.validate_release("3.2.1+81", "name: munich_ways\n")

    def test_android_version_code_boundaries(self):
        for number in ("1", "2100000000"):
            self.assertEqual(module.release_version(f"3.2.1+{number}")[1], number)

    def test_invalid_tags_are_rejected(self):
        for tag in ("", "master", "3.2.1", "v3.2.1+81", "3.2.1+0",
                    "3.2.1+081", "3.2.1+2100000001", "3.2.1+81\n",
                    "3.2.1+81; echo unsafe", "3.2.1+81\nbuild_number=80"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                module.release_version(tag)

    def test_cli_checks_pubspec_without_overriding_it(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "outputs"
            pubspec = Path(directory) / "pubspec.yaml"
            pubspec.write_text("version: 3.2.1+81\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT)], cwd=directory,
                env={**os.environ, "RELEASE_TAG": "3.2.1+81", "GITHUB_OUTPUT": str(output)},
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(output.exists())
            self.assertEqual(pubspec.read_text(encoding="utf-8"), "version: 3.2.1+81\n")

    def test_cli_rejects_mismatch_without_changing_pubspec(self):
        with tempfile.TemporaryDirectory() as directory:
            pubspec = Path(directory) / "pubspec.yaml"
            pubspec.write_text("version: 3.2.1+80\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT)], cwd=directory,
                env={**os.environ, "RELEASE_TAG": "3.2.1+81"},
                capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("does not match pubspec.yaml", result.stderr)
            self.assertEqual(pubspec.read_text(encoding="utf-8"), "version: 3.2.1+80\n")

    def test_invalid_tag_exits_before_writing_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "outputs"
            (Path(directory) / "pubspec.yaml").write_text("version: 3.2.1+81\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT)], cwd=directory,
                env={**os.environ, "RELEASE_TAG": "3.2.1", "GITHUB_OUTPUT": str(output)},
                capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
