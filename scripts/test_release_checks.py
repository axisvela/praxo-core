import copy
import io
import json
import os
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

import verify_release_checks as gate


REPO = "axisvela/praxo-core"
SHA = "a" * 40
ROOT = Path(__file__).resolve().parents[1]


def run_fixture(name="ci", **changes):
    run = {
        "id": 101 if name == "ci" else 201,
        "workflow_id": 10 if name == "ci" else 20,
        "name": name,
        "path": f".github/workflows/{name}.yml",
        "head_sha": SHA,
        "head_branch": "main",
        "event": "push",
        "repository": {"full_name": REPO},
        "head_repository": {"full_name": REPO},
        "run_number": 1,
        "run_attempt": 1,
        "status": "completed",
        "conclusion": "success",
    }
    run.update(changes)
    return run


def pages_fixture(*runs, total=None):
    return [{"total_count": len({run["id"] for run in runs}) if total is None else total,
             "workflow_runs": list(runs)}]


class ReleaseChecksTests(unittest.TestCase):
    def setUp(self):
        self.responses = {}
        for name, workflow_id in (("ci", 10), ("docs", 20)):
            run = run_fixture(name)
            self.responses[f"repos/{REPO}/actions/workflows/{name}.yml"] = {
                "id": workflow_id,
                "name": name,
                "path": f".github/workflows/{name}.yml",
                "state": "active",
            }
            self.responses[f"repos/{REPO}/actions/workflows/{workflow_id}/runs"] = pages_fixture(run)
            self.responses[f"repos/{REPO}/actions/runs/{run['id']}"] = run
        self.environment = patch.dict(os.environ, {"GH_TOKEN": "fixture-token"}, clear=True)
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.process = patch.object(gate.subprocess, "run", side_effect=self.fake_gh)
        self.mock_process = self.process.start()
        self.addCleanup(self.process.stop)

    def fake_gh(self, command, **kwargs):
        self.assertEqual(command[:4], ["gh", "api", "--method", "GET"])
        self.assertTrue(kwargs["check"])
        self.assertTrue(kwargs["capture_output"])
        self.assertTrue(kwargs["text"])
        self.assertEqual(kwargs["timeout"], 120)
        endpoint = command[4]
        if endpoint.endswith("/runs"):
            self.assertEqual(command[5:], [
                "-f", f"head_sha={SHA}", "-f", "branch=main", "-f", "event=push",
                "-f", "per_page=100", "--paginate", "--slurp",
            ])
        else:
            self.assertEqual(command[5:], [])
        response = self.responses[endpoint]
        if isinstance(response, Exception):
            raise response
        return subprocess.CompletedProcess(command, 0, json.dumps(response), "")

    def set_runs(self, *runs, total=None):
        self.responses[f"repos/{REPO}/actions/workflows/10/runs"] = pages_fixture(*runs, total=total)
        for run in runs:
            self.responses[f"repos/{REPO}/actions/runs/{run['id']}"] = run

    def verify(self):
        return gate.verify_release_checks(REPO, SHA)

    def test_success_queries_both_workflows_and_latest_attempts(self):
        self.assertEqual(self.verify(), ["ci: run 101 attempt 1", "docs: run 201 attempt 1"])
        self.assertEqual(self.mock_process.call_count, 6)

    def test_identity_negative_fixtures(self):
        cases = [
            {"head_sha": "b" * 40},
            {"head_sha": SHA[:7]},
            {"path": ".github/workflows/spoof.yml"},
            {"name": "docs"},
            {"workflow_id": 99},
            {"event": "pull_request"},
            {"event": "workflow_dispatch"},
            {"head_branch": "feature"},
            {"head_branch": "v2.5.0"},
            {"repository": {"full_name": "other/praxo-core"}},
            {"head_repository": {"full_name": "fork/praxo-core"}},
            {"head_repository": None},
            {"repository": None},
            {"id": 0},
            {"run_number": None},
            {"run_attempt": True},
        ]
        for changes in cases:
            with self.subTest(changes=changes):
                self.set_runs(run_fixture(**changes))
                with self.assertRaises(gate.GateError):
                    self.verify()

    def test_workflow_identity_cannot_be_spoofed_by_name(self):
        endpoint = f"repos/{REPO}/actions/workflows/ci.yml"
        original = copy.deepcopy(self.responses[endpoint])
        for changes in ({"path": ".github/workflows/other.yml"}, {"name": "docs"},
                        {"state": "disabled_manually"}, {"id": None}):
            with self.subTest(changes=changes):
                self.responses[endpoint] = dict(original, **changes)
                with self.assertRaises(gate.GateError):
                    self.verify()

    def test_absent_pending_and_unsuccessful_fixtures_block(self):
        cases = [(status, conclusion)
                 for status in ("queued", "in_progress", "waiting", "pending", None)
                 for conclusion in (None, "success")]
        cases += [("completed", conclusion) for conclusion in (
            None, "failure", "cancelled", "skipped", "neutral", "timed_out",
            "action_required", "stale", "startup_failure",
        )]
        for status, conclusion in cases:
            with self.subTest(status=status, conclusion=conclusion):
                self.set_runs(run_fixture(status=status, conclusion=conclusion))
                with self.assertRaises(gate.GateError):
                    self.verify()
        self.set_runs()
        with self.assertRaises(gate.GateError):
            self.verify()

    def test_docs_failure_blocks_even_when_ci_succeeds(self):
        self.responses[f"repos/{REPO}/actions/runs/201"]["conclusion"] = "failure"
        with self.assertRaisesRegex(gate.GateError, "docs:.*blocks release"):
            self.verify()

    def test_newest_run_wins_independent_of_page_order(self):
        older = run_fixture()
        newer = run_fixture(id=102, run_number=2, conclusion="failure")
        for runs in ((older, newer), (newer, older)):
            with self.subTest(order=[run["id"] for run in runs]):
                self.set_runs(*runs)
                with self.assertRaisesRegex(gate.GateError, "run 102"):
                    self.verify()
        older["conclusion"] = "failure"
        newer["conclusion"] = "success"
        self.set_runs(newer, older)
        self.assertIn("ci: run 102 attempt 1", self.verify())

    def test_latest_rerun_attempt_wins_independent_of_order(self):
        old = run_fixture()
        rerun = run_fixture(run_attempt=2, conclusion="failure")
        for runs in ((old, rerun), (rerun, old)):
            with self.subTest(order=[run["run_attempt"] for run in runs]):
                self.set_runs(*runs)
                self.responses[f"repos/{REPO}/actions/runs/101"] = rerun
                with self.assertRaisesRegex(gate.GateError, "attempt 2"):
                    self.verify()
        old["conclusion"] = "failure"
        rerun["conclusion"] = "success"
        self.set_runs(old, rerun)
        self.assertIn("ci: run 101 attempt 2", self.verify())

    def test_fresh_detail_prevents_stale_success_masking_rerun(self):
        for changes in ({"run_attempt": 2, "conclusion": "failure"},
                        {"run_attempt": 2, "status": "queued", "conclusion": None},
                        {"head_sha": "b" * 40}, {"event": "pull_request"},
                        {"id": 102}, {"run_number": 2}):
            with self.subTest(changes=changes):
                self.responses[f"repos/{REPO}/actions/runs/101"] = run_fixture(**changes)
                with self.assertRaises(gate.GateError):
                    self.verify()
        self.set_runs(run_fixture(run_attempt=2))
        self.responses[f"repos/{REPO}/actions/runs/101"] = run_fixture()
        with self.assertRaisesRegex(gate.GateError, "inconsistent"):
            self.verify()

    def test_identical_duplicates_are_safe_conflicting_duplicates_block(self):
        self.set_runs(run_fixture(), run_fixture())
        self.verify()
        for changes in ({"conclusion": "failure"}, {"run_number": 2}):
            with self.subTest(changes=changes):
                self.set_runs(run_fixture(), run_fixture(**changes))
                with self.assertRaisesRegex(gate.GateError, "conflicting"):
                    self.verify()

    def test_pagination_includes_failure_on_later_page(self):
        first = run_fixture()
        last = run_fixture(id=102, run_number=2, conclusion="failure")
        self.set_runs(first, last)
        self.responses[f"repos/{REPO}/actions/workflows/10/runs"] = [
            {"total_count": 2, "workflow_runs": [first]},
            {"total_count": 2, "workflow_runs": [last]},
        ]
        with self.assertRaisesRegex(gate.GateError, "run 102"):
            self.verify()
        last["conclusion"] = "success"
        self.assertIn("ci: run 102 attempt 1", self.verify())

    def test_incomplete_malformed_or_capped_pages_block(self):
        cases = [None, {}, [], [None], [{}],
                 [{"total_count": 0, "workflow_runs": []}],
                 [{"total_count": 1, "workflow_runs": None}],
                 [{"total_count": True, "workflow_runs": [run_fixture()]}],
                 [{"total_count": 1, "workflow_runs": [None]}],
                 pages_fixture(run_fixture(), total=2),
                 pages_fixture(run_fixture(), total=1001),
                 pages_fixture(run_fixture(), total=-1),
                 pages_fixture(run_fixture()) + pages_fixture(run_fixture(), total=2)]
        for pages in cases:
            with self.subTest(pages=pages):
                self.responses[f"repos/{REPO}/actions/workflows/10/runs"] = pages
                with self.assertRaises(gate.GateError):
                    self.verify()

    def test_missing_token_and_invalid_cli_inputs_make_no_queries(self):
        for repo, sha in ((REPO, SHA[:7]), (REPO, "b" * 39 + "z"),
                          (REPO, SHA.upper()), ("owner/repo/extra", SHA), ("", SHA)):
            with self.subTest(repo=repo, sha=sha), self.assertRaises(gate.GateError):
                gate.verify_release_checks(repo, sha)
        with patch.dict(os.environ, {}, clear=True), self.assertRaises(gate.GateError):
            self.verify()
        self.mock_process.assert_not_called()

    def test_github_token_is_also_supported(self):
        with patch.dict(os.environ, {"GITHUB_TOKEN": "fixture-token"}, clear=True):
            self.verify()

    def test_command_and_json_errors_propagate_as_nonzero(self):
        endpoints = list(self.responses)
        for endpoint in endpoints:
            original = self.responses[endpoint]
            for error in (subprocess.CalledProcessError(1, ["gh", "api"]),
                          subprocess.TimeoutExpired(["gh", "api"], 120),
                          FileNotFoundError("gh unavailable"),
                          json.JSONDecodeError("bad response", "", 0)):
                with self.subTest(endpoint=endpoint, error=error):
                    self.responses[endpoint] = error
                    with patch("sys.stderr", new_callable=io.StringIO) as stderr:
                        self.assertEqual(gate.main(["--repo", REPO, "--sha", SHA]), 1)
                        self.assertIn("Release checks blocked", stderr.getvalue())
            self.responses[endpoint] = original

    def test_cli_success_and_gate_failure_exit_codes(self):
        with patch("sys.stdout", new_callable=io.StringIO) as stdout:
            self.assertEqual(gate.main(["--repo", REPO, "--sha", SHA]), 0)
            self.assertIn(SHA, stdout.getvalue())
        self.set_runs()
        with patch("sys.stderr", new_callable=io.StringIO):
            self.assertEqual(gate.main(["--repo", REPO, "--sha", SHA]), 1)

    def test_release_job_requires_read_only_gate_before_write_job(self):
        text = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
        preflight, release = text.split("\n  release:\n", 1)
        self.assertIn("actions: read", preflight)
        self.assertNotIn("contents: write", preflight)
        self.assertIn("persist-credentials: false", preflight)
        self.assertIn('python -m unittest discover -s scripts -p "test_release_checks.py" -v', preflight)
        self.assertIn('python scripts/verify_release_checks.py --repo "$GITHUB_REPOSITORY"', preflight)
        self.assertIn('--sha "$(git rev-parse HEAD)"', preflight)
        self.assertIn("GH_TOKEN: ${{ github.token }}", preflight)
        self.assertIn("    needs: verify-checks\n", release)
        self.assertIn("contents: write", release)
        self.assertNotIn("continue-on-error", text)
        self.assertNotIn("always()", text)
        for command in ('test "v${version}" = "${GITHUB_REF_NAME}"', "go test ./...",
                        "go vet ./...", "go build ./...", "cyclonedx-gomod mod",
                        "git archive", "release_manifest.py", "gh release create"):
            self.assertIn(command, release)

    def test_docs_triggers_include_release_metadata_and_gate_files(self):
        text = (ROOT / ".github/workflows/docs.yml").read_text(encoding="utf-8")
        for pattern in ("**/README*.md", "VERSION", "CHANGELOG*.md", "ROADMAP*.md",
                        "scripts/verify_release_checks.py", "scripts/test_release_checks.py",
                        ".github/workflows/release.yml"):
            self.assertEqual(text.count(f'- "{pattern}"'), 1, pattern)

    def test_python_release_uses_trusted_publishing(self):
        text = (ROOT / ".github/workflows/python-release.yml").read_text(encoding="utf-8")
        for expected in (
            '"python/v*"',
            "workflow_dispatch:",
            "id-token: write",
            "name: testpypi",
            "name: pypi",
            "repository-url: https://test.pypi.org/legacy/",
            "pypa/gh-action-pypi-publish@release/v1",
            "python -m twine check dist/*",
            "installed_smoke.py",
            "test \"python/v${version}\" = \"${GITHUB_REF_NAME}\"",
        ):
            self.assertIn(expected, text)
        self.assertNotIn("PYPI_API_TOKEN", text)
        self.assertNotIn("password:", text)

    def test_manual_dispatch_cannot_publish(self):
        text = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
        triggers = text.split("\npermissions:", 1)[0]
        self.assertIn("  workflow_dispatch:\n", triggers)
        release = text.split("\n  release:\n", 1)[1]
        self.assertIn("    if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')\n", release)

    def test_docs_main_push_is_not_path_filtered(self):
        text = (ROOT / ".github/workflows/docs.yml").read_text(encoding="utf-8")
        push = text.split("\n  push:\n", 1)[1].split("\n  pull_request:\n", 1)[0]
        self.assertIn("branches: [main]", push)
        self.assertNotIn("paths:", push)
        self.assertNotIn("paths-ignore:", push)


if __name__ == "__main__":
    unittest.main()
