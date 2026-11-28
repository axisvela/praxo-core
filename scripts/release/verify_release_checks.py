import argparse
import json
import os
import re
import subprocess
import sys


WORKFLOWS = ("ci", "docs")


class GateError(Exception):
    pass


def gh_api(endpoint, fields=(), paginate=False):
    command = ["gh", "api", "--method", "GET", endpoint]
    for key, value in fields:
        command.extend(["-f", f"{key}={value}"])
    if paginate:
        command.extend(["--paginate", "--slurp"])
    result = subprocess.run(command, capture_output=True, text=True, check=True, timeout=120)
    return json.loads(result.stdout)


def positive_integer(value):
    return type(value) is int and value > 0


def validate_run(run, repo, sha, name, workflow_id):
    if not isinstance(run, dict):
        raise GateError(f"{name}: malformed run")
    expected = {
        "head_sha": sha,
        "head_branch": "main",
        "event": "push",
        "path": f".github/workflows/{name}.yml",
        "name": name,
        "workflow_id": workflow_id,
    }
    for key, value in expected.items():
        if run.get(key) != value:
            raise GateError(f"{name}: untrusted run {key}: {run.get(key)!r}")
    for key in ("repository", "head_repository"):
        repository = run.get(key)
        if not isinstance(repository, dict) or repository.get("full_name") != repo:
            raise GateError(f"{name}: untrusted {key}")
    for key in ("id", "run_number", "run_attempt"):
        if not positive_integer(run.get(key)):
            raise GateError(f"{name}: missing or invalid {key}")


def verify_release_checks(repo, sha):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
        raise GateError("repository must be owner/name")
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise GateError("tag commit must be a full lowercase 40-character SHA")
    if not (os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")):
        raise GateError("GH_TOKEN or GITHUB_TOKEN is required with actions:read")
    verified = []
    for name in WORKFLOWS:
        workflow = gh_api(f"repos/{repo}/actions/workflows/{name}.yml")
        if (
            not isinstance(workflow, dict)
            or not positive_integer(workflow.get("id"))
            or workflow.get("name") != name
            or workflow.get("path") != f".github/workflows/{name}.yml"
            or workflow.get("state") != "active"
        ):
            raise GateError(f"{name}: unexpected workflow identity or state")
        pages = gh_api(
            f"repos/{repo}/actions/workflows/{workflow['id']}/runs",
            (("head_sha", sha), ("branch", "main"), ("event", "push"), ("per_page", "100")),
            paginate=True,
        )
        if not isinstance(pages, list) or not pages:
            raise GateError(f"{name}: missing run pages")
        runs = {}
        total = None
        for page in pages:
            if not isinstance(page, dict):
                raise GateError(f"{name}: malformed run page")
            count = page.get("total_count")
            if type(count) is not int or not 0 <= count <= 1000:
                raise GateError(f"{name}: invalid or truncated run count")
            if total is not None and total != count:
                raise GateError(f"{name}: run count changed during pagination")
            total = count
            if not isinstance(page.get("workflow_runs"), list):
                raise GateError(f"{name}: missing workflow_runs")
            for run in page["workflow_runs"]:
                validate_run(run, repo, sha, name, workflow["id"])
                previous = runs.get(run["id"])
                if previous is not None:
                    if previous["run_number"] != run["run_number"]:
                        raise GateError(f"{name}: conflicting run number")
                    if previous["run_attempt"] == run["run_attempt"] and previous != run:
                        raise GateError(f"{name}: conflicting duplicate attempt")
                    if previous["run_attempt"] > run["run_attempt"]:
                        continue
                runs[run["id"]] = run
        if not runs or len(runs) != total:
            raise GateError(f"{name}: absent or incomplete same-commit runs")
        latest = max(runs.values(), key=lambda run: (run["run_number"], run["id"]))
        current = gh_api(f"repos/{repo}/actions/runs/{latest['id']}")
        validate_run(current, repo, sha, name, workflow["id"])
        if (
            current["id"] != latest["id"]
            or current["run_number"] != latest["run_number"]
            or current["run_attempt"] < latest["run_attempt"]
        ):
            raise GateError(f"{name}: inconsistent latest attempt")
        if current.get("status") != "completed" or current.get("conclusion") != "success":
            raise GateError(
                f"{name}: run {current['id']} attempt {current['run_attempt']} blocks release: "
                f"{current.get('status')}/{current.get('conclusion')}"
            )
        verified.append(f"{name}: run {current['id']} attempt {current['run_attempt']}")
    return verified


def main(argv=None):
    parser = argparse.ArgumentParser(description="Require same-commit main push release checks")
    parser.add_argument("--repo", required=True)
    parser.add_argument("--sha", required=True)
    args = parser.parse_args(argv)
    try:
        verified = verify_release_checks(args.repo, args.sha)
    except (GateError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Release checks blocked: {error}", file=sys.stderr)
        return 1
    print(f"Release checks passed for {args.repo}@{args.sha}: " + "; ".join(verified))
    return 0


if __name__ == "__main__":
    sys.exit(main())
