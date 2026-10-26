from pathlib import Path
import re
import subprocess
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = "python typescript java rust c cpp csharp php ruby perl lua dart swift julia r d zig cobol fortran".split()
BINDINGS = ["shell", "powershell"]
SAMPLES = ["javascript", "kotlin", "scala"]


class LayoutTests(unittest.TestCase):
    def test_language_locations(self):
        for category, names in (("sdk", LANGUAGES), ("bindings", BINDINGS), ("examples", SAMPLES)):
            for name in names:
                self.assertFalse((ROOT / name).exists(), name)
                self.assertTrue((ROOT / category / name / "README.md").is_file(), name)

    def test_go_layout_is_unchanged(self):
        self.assertIn("module github.com/axisvela/praxo-core/v2", (ROOT / "go.mod").read_text())
        for path in ("pkg/agent", "internal/spec", "cmd/praxo-bridge", "spec/vectors"):
            self.assertTrue((ROOT / path).is_dir(), path)

    def test_workflow_directories(self):
        workflow = yaml.safe_load((ROOT / ".github/workflows/ci.yml").read_text())
        for job in workflow["jobs"].values():
            runs = [job.get("defaults", {}).get("run", {})] + job["steps"]
            for run in runs:
                path = run.get("working-directory", "")
                if path and "${{" not in path:
                    self.assertTrue((ROOT / path).is_dir(), path)
                command = run.get("run", "")
                if isinstance(command, str):
                    for source in re.findall(r"cmake -S (\S+)", command):
                        base = ROOT / path if path else ROOT
                        self.assertTrue((base / source).is_dir(), source)

    def test_workflow_language_paths(self):
        text = (ROOT / ".github/workflows/ci.yml").read_text()
        names = "|".join(LANGUAGES + BINDINGS + SAMPLES)
        runs = "\n".join(str(step.get("run", "")) for job in yaml.safe_load(text)["jobs"].values() for step in job["steps"])
        stale = re.findall(r"(?<![\w/.-])(?:\./)?(?:" + names + r")/(?=[\w?.])", runs)
        self.assertEqual(stale, [])
        self.assertIn("node ../../examples/javascript/sample.mjs", text)
        self.assertIn("uses: ruby/setup-ruby@v1", text)
        self.assertNotIn("uses: sdk/", text)

    def test_rust_binary_source_is_not_ignored(self):
        result = subprocess.run(["git", "check-ignore", "--no-index", "-q", "sdk/rust/src/bin/conformance.rs"], cwd=ROOT)
        self.assertEqual(result.returncode, 1)


if __name__ == "__main__":
    unittest.main()
