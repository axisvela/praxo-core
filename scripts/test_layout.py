from pathlib import Path
import re
import subprocess
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = "python typescript java rust c cpp csharp php ruby perl lua dart swift julia r d zig cobol fortran haskell matlab delphi ocaml".split()
BINDINGS = ["shell", "powershell"]
SAMPLES = ["javascript", "kotlin", "scala"]


class LayoutTests(unittest.TestCase):
    def test_language_locations(self):
        self.assertFalse((ROOT / "sdk").exists())
        for category, names in (("language", LANGUAGES), ("bindings", BINDINGS), ("examples", SAMPLES)):
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
        self.assertNotIn("uses: language/", text)

    def test_rust_binary_source_is_not_ignored(self):
        result = subprocess.run(["git", "check-ignore", "--no-index", "-q", "language/rust/src/bin/conformance.rs"], cwd=ROOT)
        self.assertEqual(result.returncode, 1)

    def test_delivered_languages_have_site_entries(self):
        matrix = (ROOT / "spec/languages.md").read_text(encoding="utf-8")
        navigation = (ROOT / "mkdocs.yml").read_text(encoding="utf-8")
        for line in matrix.splitlines():
            if not line.startswith("| "):
                continue
            cells = [cell.strip() for cell in line.split("|")]
            if len(cells) < 7 or cells[3] not in ("released", "in progress"):
                continue
            slug = {"C++": "cpp", "C#": "csharp", "OCaml / Caml": "ocaml"}.get(cells[1], cells[1].lower().replace(" ", "-"))
            path = "languages/" + slug + ".md"
            self.assertTrue((ROOT / "docs" / path).is_file(), cells[1])
            self.assertIn(path, navigation)

    def test_planned_languages_do_not_claim_release_tags(self):
        matrix = (ROOT / "spec/languages.md").read_text(encoding="utf-8")
        for line in matrix.splitlines():
            if not line.startswith("| "):
                continue
            cells = [cell.strip() for cell in line.split("|")]
            if len(cells) >= 7 and cells[3] in ("planned", "consumer-gated"):
                self.assertEqual(cells[4], "none", cells[1])

    def test_bridge_parity_scope(self):
        version = (ROOT / "spec/SPEC_VERSION").read_text().strip()
        for language in BINDINGS:
            text = (ROOT / "spec/parity" / ("bridge-" + language + ".md")).read_text()
            self.assertIn("- Tier: bridge", text)
            self.assertIn("- SPEC_VERSION: " + version, text)
            self.assertIn("toolcall.ParseToolCall", text)
            self.assertIn("event.Sink", text)


if __name__ == "__main__":
    unittest.main()
