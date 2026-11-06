#!/usr/bin/env python3
"""Run a declared Execution Correctness scope and write a scoped report.

The default scope is local EC-D mechanics only. A scope-passed report does not
establish a complete EC scenario, a Profile, EC-I, or EC-O.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from uuid import uuid4


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INVENTORY = ROOT / "scripts" / "execution_correctness_inventory.json"
DEFAULT_OUTPUT = ROOT / "build" / "execution-correctness"
SCHEMA = "praxo-execution-correctness-1"
TERMINAL_ACTIONS = {"pass", "fail", "skip"}


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def new_run_id() -> str:
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"{stamp}-{uuid4().hex[:8]}"


def decode_output(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    return str(value)


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


@dataclass(frozen=True)
class Selector:
    scenario: str
    package: str
    test: str
    selector: str
    assertion: str


class RunnerError(Exception):
    pass


def load_inventory(path: Path) -> dict[str, object]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RunnerError(f"cannot read inventory {path}: {error}") from error
    if not isinstance(data, dict) or not isinstance(data.get("scenarios"), list):
        raise RunnerError("inventory must contain a scenarios list")
    return data


def select_scope(inventory: dict[str, object], scope_name: str | None) -> tuple[list[Selector], dict[str, object]]:
    scope = inventory.get("initialScope")
    if not isinstance(scope, dict):
        raise RunnerError("inventory has no initialScope")
    if scope_name and scope.get("name") != scope_name:
        raise RunnerError(f"unknown initial scope: {scope_name}")
    scenario_ids = scope.get("scenarioIds")
    if not isinstance(scenario_ids, list) or not scenario_ids:
        raise RunnerError("initialScope.scenarioIds must be a non-empty list")
    scenarios = {item.get("id"): item for item in inventory["scenarios"] if isinstance(item, dict)}
    missing = [identifier for identifier in scenario_ids if identifier not in scenarios]
    if missing:
        raise RunnerError(f"scope references unknown scenarios: {', '.join(missing)}")

    selectors: list[Selector] = []
    for identifier in scenario_ids:
        scenario = scenarios[identifier]
        for test in scenario.get("localTests", []):
            package = test.get("package")
            test_name = test.get("test")
            file_name = test.get("file")
            assertion = test.get("assertion", "")
            if not isinstance(package, str) or not package.startswith("./pkg/"):
                raise RunnerError(f"{identifier}: invalid package {package!r}")
            if not isinstance(test_name, str) or not re.fullmatch(r"Test[A-Za-z0-9_]+", test_name):
                raise RunnerError(f"{identifier}: invalid test name {test_name!r}")
            if not isinstance(file_name, str) or not file_name.startswith("pkg/") or not file_name.endswith("_test.go"):
                raise RunnerError(f"{identifier}: invalid test file {file_name!r}")
            subtests = test.get("requiredSubtests", [])
            if not isinstance(subtests, list) or any(
                not isinstance(item, str) or not item or item.startswith("/") or item.endswith("/")
                for item in subtests
            ):
                raise RunnerError(f"{identifier}: invalid requiredSubtests")
            names = subtests or [None]
            for subtest in names:
                selector = test_name if subtest is None else f"{test_name}/{subtest}"
                selectors.append(Selector(identifier, package, test_name, selector, assertion))
    if not selectors:
        raise RunnerError("scope selected no required assertions")
    seen: set[str] = set()
    for selector in selectors:
        if selector.selector in seen:
            raise RunnerError(f"duplicate selector: {selector.selector}")
        seen.add(selector.selector)
    packages: dict[str, list[Selector]] = {}
    for selector in selectors:
        packages.setdefault(selector.package, []).append(selector)
    scope_meta = {
        "name": scope.get("name"),
        "track": scope.get("track"),
        "scenarioIds": scenario_ids,
        "claim": scope.get("claim"),
        "selectors": len(selectors),
        "packages": sorted(packages),
    }
    return selectors, scope_meta


def resolve_go(command: str) -> tuple[str, str]:
    candidate = Path(command)
    executable = str(candidate) if candidate.is_file() else shutil.which(command)
    if not executable:
        raise RunnerError(f"Go executable not found: {command}")
    try:
        completed = subprocess.run(
            [executable, "version"], cwd=ROOT, capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=30,
        )
    except (OSError, subprocess.SubprocessError) as error:
        raise RunnerError(f"cannot run {executable} version: {error}") from error
    if completed.returncode != 0:
        raise RunnerError(f"{executable} version failed: {completed.stderr or completed.stdout}")
    return executable, (completed.stdout or completed.stderr).strip()


def build_command(go_bin: str, package: str, tests: list[str], timeout: int) -> list[str]:
    unique = sorted(set(tests))
    expression = "^(?:" + "|".join(re.escape(name) for name in unique) + ")$"
    return [
        go_bin, "test", "-json", "-count=1", "-timeout", f"{timeout}s",
        "-run", expression, package,
    ]


def parse_events(stdout: str) -> tuple[list[dict[str, object]], list[dict[str, str]]]:
    events: list[dict[str, object]] = []
    malformed: list[dict[str, str]] = []
    for line_number, line in enumerate((stdout or "").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            malformed.append({"line": str(line_number), "text": line[:1000]})
            continue
        if not isinstance(item, dict) or not isinstance(item.get("Action"), str):
            malformed.append({"line": str(line_number), "text": line[:1000]})
            continue
        events.append(item)
    return events, malformed


def terminal_events(events: list[dict[str, object]]) -> tuple[dict[str, dict[str, object]], list[str]]:
    terminal: dict[str, dict[str, object]] = {}
    conflicts: list[str] = []
    for event in events:
        test = event.get("Test")
        action = event.get("Action")
        if not isinstance(test, str) or action not in TERMINAL_ACTIONS:
            continue
        record = {
            "action": action,
            "elapsed": event.get("Elapsed"),
            "output": event.get("Output", ""),
        }
        previous = terminal.get(test)
        if previous is not None and previous.get("action") != action:
            conflicts.append(test)
        terminal[test] = record
    return terminal, sorted(set(conflicts))


def run_package(go_bin: str, package: str, tests: list[str], timeout: int) -> dict[str, object]:
    command = build_command(go_bin, package, tests, timeout)
    started = time.monotonic()
    env = dict(os.environ)
    env["GOWORK"] = "off"
    try:
        completed = subprocess.run(
            command, cwd=ROOT, env=env, capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=timeout + 60,
        )
        stdout, stderr = completed.stdout, completed.stderr
        exit_code: int | None = completed.returncode
        timed_out = False
        error = None
    except subprocess.TimeoutExpired as caught:
        stdout = decode_output(caught.stdout)
        stderr = decode_output(caught.stderr)
        exit_code = None
        timed_out = True
        error = f"process timeout after {timeout + 60}s"
    except OSError as caught:
        stdout = ""
        stderr = str(caught)
        exit_code = None
        timed_out = False
        error = str(caught)
    events, malformed = parse_events(stdout)
    return {
        "package": package,
        "command": command,
        "exitCode": exit_code,
        "timedOut": timed_out,
        "error": error,
        "elapsedMs": int((time.monotonic() - started) * 1000),
        "events": events,
        "malformed": malformed,
        "stdout": stdout,
        "stderr": stderr,
    }


def evaluate(selectors: list[Selector], runs: list[dict[str, object]]) -> dict[str, object]:
    if not selectors:
        return {"status": "invalid", "results": [], "packages": [], "counts": {}, "errors": ["no selectors"]}
    selector_keys: set[str] = set()
    errors: list[str] = []
    for selector in selectors:
        if selector.selector in selector_keys:
            errors.append(f"duplicate selector: {selector.selector}")
        selector_keys.add(selector.selector)
    by_package = {run["package"]: run for run in runs if isinstance(run.get("package"), str)}
    results: list[dict[str, object]] = []
    package_rows: list[dict[str, object]] = []
    for package, run in sorted(by_package.items()):
        malformed = run.get("malformed", [])
        timed_out = bool(run.get("timedOut"))
        exit_code = run.get("exitCode")
        run_error = run.get("error")
        terminal, conflicts = terminal_events(run.get("events", []))
        if malformed or conflicts:
            package_status = "invalid"
        elif timed_out or run_error:
            package_status = "blocked"
        elif exit_code != 0:
            package_status = "failed"
        else:
            package_status = "passed"
        package_rows.append({
            "package": package,
            "status": package_status,
            "exitCode": exit_code,
            "timedOut": timed_out,
            "error": run_error,
            "eventCount": len(run.get("events", [])),
            "malformedCount": len(malformed),
            "conflicts": conflicts,
            "elapsedMs": run.get("elapsedMs", 0),
            "command": run.get("command", []),
        })
        for selector in [item for item in selectors if item.package == package]:
            if malformed:
                outcome, reason = "blocked", "malformed go test JSON output"
            elif conflicts:
                outcome, reason = "blocked", "conflicting terminal events"
            elif timed_out:
                outcome, reason = "blocked", "package process timed out"
            elif run_error:
                outcome, reason = "blocked", run_error
            elif selector.selector not in terminal:
                if exit_code != 0:
                    outcome, reason = "blocked", "package failed before selector terminal event"
                else:
                    outcome, reason = "not-run", "selector terminal event missing"
            else:
                action = terminal[selector.selector].get("action")
                if action == "pass":
                    outcome, reason = "passed", None
                elif action == "fail":
                    outcome, reason = "failed", "go test reported fail"
                elif action == "skip":
                    outcome, reason = "skipped", "go test reported skip"
                else:
                    outcome, reason = "blocked", f"unexpected terminal action: {action}"
            results.append({
                "scenario": selector.scenario,
                "package": package,
                "selector": selector.selector,
                "assertion": selector.assertion,
                "outcome": outcome,
                "reason": reason,
                "elapsed": terminal.get(selector.selector, {}).get("elapsed"),
            })
    for selector in selectors:
        if selector.package not in by_package:
            results.append({
                "scenario": selector.scenario,
                "package": selector.package,
                "selector": selector.selector,
                "assertion": selector.assertion,
                "outcome": "blocked",
                "reason": "package was not executed",
                "elapsed": None,
            })
    counts = {key: 0 for key in ("required", "passed", "failed", "skipped", "not-run", "blocked")}
    counts["required"] = len(results)
    for item in results:
        counts[item["outcome"]] = counts.get(item["outcome"], 0) + 1
    if errors:
        status = "invalid"
    elif package_rows and all(row["status"] == "passed" for row in package_rows) and counts["passed"] == counts["required"]:
        status = "scope-passed"
    else:
        status = "scope-failed"
    return {
        "status": status,
        "results": results,
        "packages": package_rows,
        "counts": counts,
        "errors": errors,
    }


def git_metadata() -> dict[str, object]:
    try:
        sha = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, check=True,
            capture_output=True, text=True, timeout=30,
        ).stdout.strip()
        dirty = bool(subprocess.run(
            ["git", "status", "--porcelain"], cwd=ROOT, check=True,
            capture_output=True, text=True, timeout=30,
        ).stdout.strip())
        return {"sha": sha, "dirty": dirty}
    except (OSError, subprocess.SubprocessError):
        return {"sha": None, "dirty": None}


def build_report(
    *,
    inventory_path: Path,
    inventory: dict[str, object],
    scope: dict[str, object],
    selectors: list[Selector],
    runs: list[dict[str, object]],
    evaluation: dict[str, object],
    go_bin: str,
    go_version: str,
    started_at: str,
    finished_at: str,
) -> dict[str, object]:
    return {
        "schema": SCHEMA,
        "kind": "execution-correctness-scope",
        "runId": new_run_id(),
        "startedAt": started_at,
        "finishedAt": finished_at,
        "status": evaluation["status"],
        "scope": scope,
        "claim": "Local EC-D mechanics only; full EC scenarios, EC-I, EC-O, and profiles remain not-run.",
        "inventory": {
            "path": str(inventory_path.relative_to(ROOT)) if inventory_path.is_relative_to(ROOT) else str(inventory_path),
            "sha256": sha256_file(inventory_path),
            "designCommit": inventory.get("designCommit"),
        },
        "repository": git_metadata(),
        "toolchain": {"goBinary": go_bin, "goVersion": go_version, "gowork": "off"},
        "environment": {"platform": platform.platform(), "python": sys.version.split()[0]},
        "packages": evaluation["packages"],
        "selectors": evaluation["results"],
        "counts": evaluation["counts"],
        "errors": evaluation["errors"],
        "limitations": [
            "This report covers only the selected EC-D local mechanics selectors.",
            "The inventory's full EC scenarios, EC-I, EC-O, and Profile acceptance remain not-run.",
            "Go test JSON assertions are local behavior evidence, not external effect or production evidence.",
            "No race, deployment, real database, sandbox, device, or independent validation was run.",
        ],
    }


def markdown_report(report: dict[str, object]) -> str:
    lines = [
        "# Execution Correctness Scope Report",
        "",
        f"- Run: `{report['runId']}`",
        f"- Status: **{report['status']}**",
        f"- Scope: `{report['scope']['name']}` ({report['scope']['track']})",
        f"- Claim: {report['claim']}",
        f"- Repository: `{(report.get('repository') or {}).get('sha')}` (dirty={(report.get('repository') or {}).get('dirty')})",
        f"- Go: `{(report.get('toolchain') or {}).get('goVersion')}`",
        f"- Inventory: `{(report.get('inventory') or {}).get('sha256')}`",
        "",
        "## Selectors",
        "",
        "| EC | Selector | Outcome | Package |",
        "| --- | --- | --- | --- |",
    ]
    for item in report["selectors"]:
        lines.append(
            f"| {item['scenario']} | `{item['selector']}` | {item['outcome']} | `{item['package']}` |"
        )
    counts = report["counts"]
    lines.extend([
        "",
        "## Counts",
        "",
        "| Required | Passed | Failed | Skipped | Not run | Blocked |",
        "| --- | --- | --- | --- | --- | --- |",
        f"| {counts['required']} | {counts['passed']} | {counts['failed']} | "
        f"{counts['skipped']} | {counts['not-run']} | {counts['blocked']} |",
        "",
        "## Packages",
        "",
        "| Package | Status | Exit | Timed out | Events | Malformed |",
        "| --- | --- | --- | --- | --- | --- |",
    ])
    for package in report["packages"]:
        lines.append(
            f"| `{package['package']}` | {package['status']} | {package['exitCode']} | "
            f"{package['timedOut']} | {package['eventCount']} | {package['malformedCount']} |"
        )
    lines.extend(["", "## Limitations", ""])
    lines.extend(f"- {item}" for item in report["limitations"])
    return "\n".join(lines) + "\n"


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "-", value.strip("./").replace("/", "-")) or "package"


def write_report(report: dict[str, object], runs: list[dict[str, object]], output_root: Path) -> Path:
    output_root.mkdir(parents=True, exist_ok=True)
    base = output_root / str(report["runId"])
    run_dir = base
    suffix = 2
    while run_dir.exists():
        run_dir = output_root / f"{base.name}-{suffix}"
        suffix += 1
    run_dir.mkdir()
    (run_dir / "events").mkdir()
    (run_dir / "stdout").mkdir()
    (run_dir / "stderr").mkdir()

    for run in runs:
        package = str(run["package"])
        name = safe_name(package)
        event_lines = [json.dumps(item, ensure_ascii=False) for item in run.get("events", [])]
        (run_dir / "events" / f"{name}.jsonl").write_text("\n".join(event_lines) + ("\n" if event_lines else ""), encoding="utf-8")
        (run_dir / "stdout" / f"{name}.txt").write_text(str(run.get("stdout", "")), encoding="utf-8")
        (run_dir / "stderr" / f"{name}.txt").write_text(str(run.get("stderr", "")), encoding="utf-8")
        for package_row in report["packages"]:
            if package_row["package"] == package:
                package_row["eventsPath"] = str((run_dir / "events" / f"{name}.jsonl").relative_to(output_root))
                package_row["stdoutPath"] = str((run_dir / "stdout" / f"{name}.txt").relative_to(output_root))
                package_row["stderrPath"] = str((run_dir / "stderr" / f"{name}.txt").relative_to(output_root))

    (run_dir / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (run_dir / "report.md").write_text(markdown_report(report), encoding="utf-8")
    (run_dir / "meta.json").write_text(json.dumps({
        "runId": report["runId"],
        "status": report["status"],
        "scope": report["scope"]["name"],
        "startedAt": report["startedAt"],
        "finishedAt": report["finishedAt"],
    }, indent=2) + "\n", encoding="utf-8")
    pointer = {
        "runId": report["runId"],
        "path": str(run_dir.relative_to(output_root)),
        "status": report["status"],
        "finishedAt": report["finishedAt"],
    }
    temporary = output_root / f".latest-{uuid4().hex}.tmp"
    temporary.write_text(json.dumps(pointer, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, output_root / "latest.json")
    return run_dir


def exit_code(status: str, strict: bool = True) -> int:
    if status == "scope-passed":
        return 0
    if status == "invalid":
        return 2
    return 1 if strict else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run a declared Execution Correctness scope")
    parser.add_argument("--inventory", type=Path, default=DEFAULT_INVENTORY)
    parser.add_argument("--scope", default=None, help="initialScope name; defaults to inventory initialScope")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--timeout", type=int, default=300, help="Go test timeout in seconds")
    parser.add_argument("--go", default="go")
    parser.add_argument("--strict", action="store_true", help="fail on any required selector that does not pass (default)")
    parser.add_argument("--advisory", action="store_true", help="write a report but return success for scope failures")
    args = parser.parse_args(argv)
    if args.strict and args.advisory:
        parser.error("--strict and --advisory are mutually exclusive")

    started_at = utc_now()
    try:
        inventory = load_inventory(args.inventory)
        selectors, scope = select_scope(inventory, args.scope)
        go_bin, go_version = resolve_go(args.go)
        packages: dict[str, list[Selector]] = {}
        for selector in selectors:
            packages.setdefault(selector.package, []).append(selector)
        runs = [
            run_package(go_bin, package, sorted({item.test for item in items}), args.timeout)
            for package, items in sorted(packages.items())
        ]
        evaluation = evaluate(selectors, runs)
        report = build_report(
            inventory_path=args.inventory,
            inventory=inventory,
            scope=scope,
            selectors=selectors,
            runs=runs,
            evaluation=evaluation,
            go_bin=go_bin,
            go_version=go_version,
            started_at=started_at,
            finished_at=utc_now(),
        )
        run_dir = write_report(report, runs, args.output)
    except (RunnerError, ValueError, OSError) as error:
        print(f"execution-correctness: {error}", file=sys.stderr)
        return 2

    counts = report["counts"]
    print(f"{report['status']}: {counts['passed']}/{counts['required']} selected selectors passed")
    print(f"report: {run_dir}")
    for item in report["selectors"]:
        if item["outcome"] != "passed":
            print(f"  {item['scenario']} {item['selector']}: {item['outcome']} ({item['reason']})")
    return exit_code(report["status"], strict=not args.advisory)


if __name__ == "__main__":
    raise SystemExit(main())
