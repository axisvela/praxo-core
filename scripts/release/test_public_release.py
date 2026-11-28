import io
import json
import subprocess
import unittest
from unittest.mock import patch

from scripts.release import check_public_release as gate


def release(tag="v2.11.0", **changes):
    return dict(tag_name=tag, draft=False, prerelease=False, **changes)


class PublicReleaseTests(unittest.TestCase):
    def run_check(self, latest=None, expected=None, args=()):
        responses = [release() if latest is None else latest,
                     release() if expected is None else expected]

        def fake_gh(command, **kwargs):
            self.assertEqual(command[:4], ["gh", "api", "--method", "GET"])
            self.assertEqual(len(command), 5)
            self.assertEqual(kwargs, dict(check=True, capture_output=True, text=True, timeout=30))
            response = responses.pop(0)
            if isinstance(response, Exception):
                raise response
            return subprocess.CompletedProcess(command, 0, json.dumps(response), "")

        with patch.object(gate.subprocess, "run", side_effect=fake_gh) as process, \
                patch.object(gate.Path, "read_text", return_value="2.11.0\n"), \
                patch("sys.stdout", new_callable=io.StringIO) as out, \
                patch("sys.stderr", new_callable=io.StringIO) as err:
            status = gate.main(list(args))
        return status, out.getvalue() + err.getvalue(), process.call_args_list

    def test_current_root_release(self):
        status, output, calls = self.run_check()
        self.assertEqual(status, 0)
        self.assertIn("PASS", output)
        self.assertEqual([call.args[0][4] for call in calls], [
            "repos/axisvela/praxo-core/releases/latest",
            "repos/axisvela/praxo-core/releases/tags/v2.11.0",
        ])

    def test_language_and_non_root_tags_fail(self):
        for tag in ("python/v2.11.0", "v2.11.0-beta", "2.11.0", "v02.11.0"):
            with self.subTest(tag=tag):
                status, output, _ = self.run_check(latest=release(tag))
                self.assertEqual(status, 1)
                self.assertIn("root Go tag", output)

    def test_older_latest_and_missing_version_release(self):
        missing = subprocess.CalledProcessError(1, "gh", stderr="HTTP 404: Not Found")
        status, output, _ = self.run_check(release("v2.9.0"), missing)
        self.assertEqual(status, 1)
        self.assertIn("missing v2.11.0 release", output)
        self.assertIn("Latest is v2.9.0, expected v2.11.0", output)
        self.assertIn("approved release process", output)
        self.assertIn("no release was created", output)

    def test_existing_expected_release_not_latest(self):
        status, output, _ = self.run_check(latest=release("v2.9.0"))
        self.assertEqual(status, 1)
        self.assertIn("review release designation", output)

    def test_expected_version_and_repository_overrides(self):
        status, _, calls = self.run_check(release("v2.9.0"), release("v2.9.0"),
                                         ("--repository", "owner/repo", "--expected-version", "2.9.0"))
        self.assertEqual(status, 0)
        self.assertEqual(calls[1].args[0][4], "repos/owner/repo/releases/tags/v2.9.0")

    def test_invalid_arguments_do_not_query(self):
        for args in (("--expected-version", "v2.11.0"), ("--repository", "bad")):
            status, _, calls = self.run_check(args=args)
            self.assertEqual(status, 1)
            self.assertEqual(calls, [])

    def test_invalid_or_unpublished_responses(self):
        for response in ([], {}, {"tag_name": 12}, release("wrong"),
                         dict(release(), draft=True), dict(release(), prerelease=True)):
            with self.subTest(response=response):
                self.assertEqual(self.run_check(expected=response)[0], 1)

    def test_api_failures_are_not_success_or_missing_release(self):
        for error in (FileNotFoundError("gh"), subprocess.TimeoutExpired("gh", 30),
                      subprocess.CalledProcessError(1, "gh", stderr="HTTP 403: Forbidden")):
            status, output, _ = self.run_check(latest=error)
            self.assertEqual(status, 1)
            self.assertIn("cannot verify Latest", output)
            self.assertNotIn("missing Latest", output)


if __name__ == "__main__":
    unittest.main()
