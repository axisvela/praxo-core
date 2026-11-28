from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path

from scripts.labs.behavior_scenario_builders import Scenario
from scripts.labs.behavior_scenarios import scenarios
from scripts.labs.compatibility_lab import (
    Command,
    git_metadata,
    new_run_id,
    run_command,
    utc_now,
)


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = ROOT / "build" / "behavior-lab"
SCHEMA = "praxo-behavior-lab-1"
SCENARIO_ISOLATED_LANGUAGES = ("go", "python", "typescript", "java")
NATIVE_SUITE_LANGUAGES = (
    "rust",
    "fortran",
    "cobol",
    "ruby",
    "elixir",
    "erlang",
    "cpp",
    "php",
    "csharp",
    "lua",
    "r",
    "c",
)
LANGUAGES = (*SCENARIO_ISOLATED_LANGUAGES, *NATIVE_SUITE_LANGUAGES)
DEFAULT_LANGUAGES = SCENARIO_ISOLATED_LANGUAGES
LANGUAGE_NAMES = {
    "go": "Go",
    "python": "Python",
    "typescript": "TypeScript",
    "java": "Java",
    "rust": "Rust",
    "fortran": "Fortran",
    "cobol": "COBOL",
    "ruby": "Ruby",
    "elixir": "Elixir",
    "erlang": "Erlang",
    "cpp": "C++",
    "php": "PHP",
    "csharp": "C#",
    "lua": "Lua",
    "r": "R",
    "c": "C",
}


def cell_status(commands: list[dict[str, object]]) -> str:
    if not commands:
        return "unsupported"
    statuses = {str(item["status"]) for item in commands}
    if "failed" in statuses:
        return "failed"
    if "skipped" in statuses:
        return "skipped"
    if "not_run" in statuses:
        return "not_run"
    return "passed"


def run_scenario(
    scenario: Scenario,
    languages: list[str],
    timeout: float,
    cache: dict[tuple[tuple[str, ...], str], dict[str, object]],
) -> dict[str, object]:
    cells: dict[str, object] = {}
    for language in languages:
        commands = scenario.commands.get(language, ())
        results: list[dict[str, object]] = []
        if not commands:
            cells[language] = {
                "status": "unsupported",
                "coverage": scenario.coverage.get(language, "none"),
                "commands": [],
                "reason": "no scenario test implemented for this language",
            }
            continue
        for index, command in enumerate(commands):
            key = (command.argv, str(command.cwd))
            if key not in cache:
                cache[key] = run_command(command, timeout)
            result = cache[key]
            results.append(result)
            if result["status"] != "passed":
                for rest in commands[index + 1:]:
                    results.append(
                        {
                            "label": rest.label,
                            "argv": list(rest.argv),
                            "cwd": str(rest.cwd),
                            "status": "not_run",
                            "exit_code": None,
                            "duration_ms": 0,
                            "stdout": "",
                            "stderr": "",
                            "reason": "not run because a previous command did not pass",
                        }
                    )
                break
        status = cell_status(results)
        reason = next(
            (item.get("reason") for item in results if item.get("reason")),
            None,
        )
        cells[language] = {
            "status": status,
            "coverage": scenario.coverage.get(language, "scenario"),
            "commands": results,
            "reason": reason,
        }
    return {
        "key": scenario.key,
        "title": scenario.title,
        "languages": cells,
    }


def summarize(results: list[dict[str, object]]) -> dict[str, int]:
    counts = {
        "cells": 0,
        "passed": 0,
        "failed": 0,
        "skipped": 0,
        "not_run": 0,
        "unsupported": 0,
        "strict_unsupported": 0,
    }
    for result in results:
        for language, cell in result["languages"].items():
            counts["cells"] += 1
            status = str(cell["status"])
            counts[status] += 1
            if status == "unsupported" and language in SCENARIO_ISOLATED_LANGUAGES:
                counts["strict_unsupported"] += 1
    return counts


def build_report(
    selected: list[str],
    results: list[dict[str, object]],
    run_id: str,
    started_at: str,
    finished_at: str,
    repository: dict[str, object],
) -> dict[str, object]:
    return {
        "schema": SCHEMA,
        "run_id": run_id,
        "started_at": started_at,
        "finished_at": finished_at,
        "repository": repository,
        "environment": {"platform": sys.platform, "python": sys.version.split()[0]},
        "selection": selected,
        "scenarios": results,
        "summary": summarize(results),
    }


def markdown_report(report: dict[str, object]) -> str:
    repository = report["repository"]
    summary = report["summary"]
    selected = [str(item) for item in report.get("selection", SCENARIO_ISOLATED_LANGUAGES)]
    lines = [
        "# PRAXO-CORE Behavior Lab",
        "",
        f"- Run: `{report['run_id']}`",
        f"- Started: `{report['started_at']}`",
        f"- Finished: `{report['finished_at']}`",
        f"- Repository: `{repository.get('sha') or 'unknown'}`",
        f"- Summary: {summary['passed']} passed, {summary['failed']} failed, "
        f"{summary['skipped']} skipped, {summary['not_run']} not run, "
        f"{summary['unsupported']} unsupported of {summary['cells']} cells",
        "",
        "| Scenario | "
        + " | ".join(LANGUAGE_NAMES[item] for item in selected)
        + " |",
        "| --- | " + " | ".join("---" for _ in selected) + " |",
    ]
    for result in report["scenarios"]:
        cells = []
        for language in selected:
            cell = result["languages"].get(language)
            if cell is None:
                cells.append("not-run")
            else:
                cells.append(f"{cell['status']} ({cell['coverage']})")
        lines.append(
            "| " + result["key"] + " | " + " | ".join(cells) + " |"
        )
    lines.extend(
        [
            "",
            "This report compares scenario-level tests, not complete feature parity.",
            "Group coverage means one language self-test covers multiple scenarios.",
            "Suite coverage means the native suite passed; it is not scenario-isolated.",
        ]
    )
    return "\n".join(lines) + "\n"


def write_report(report: dict[str, object], output: Path) -> Path:
    run_id = str(report["run_id"])
    directory = output / run_id
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "report.json"
    path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    (directory / "report.md").write_text(
        markdown_report(report), encoding="utf-8", newline="\n"
    )
    (output / "latest.json").write_text(
        json.dumps({"run_id": run_id, "report": f"{run_id}/report.json"}) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    return path


def exit_code(report: dict[str, object], strict: bool) -> int:
    summary = report["summary"]
    if summary["failed"]:
        return 1
    if strict and (
        summary["not_run"]
        or summary["skipped"]
        or summary["strict_unsupported"]
    ):
        return 1
    return 0


def parse_languages(value: str, available: list[str]) -> list[str]:
    selected = [item.strip() for item in value.split(",") if item.strip()]
    unknown = [item for item in selected if item not in available]
    if unknown:
        raise ValueError("unknown language: " + ", ".join(unknown))
    if not selected:
        raise ValueError("at least one language is required")
    return selected


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Run cross-language agent behavior scenarios and write a report"
    )
    parser.add_argument("--languages", default=",".join(DEFAULT_LANGUAGES))
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--timeout", type=float, default=300.0)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args(argv)
    try:
        selected = parse_languages(args.languages, list(LANGUAGES))
    except ValueError as error:
        parser.error(str(error))

    run_id = new_run_id()
    started_at = utc_now()
    repository = git_metadata()
    cache: dict[tuple[tuple[str, ...], str], dict[str, object]] = {}
    results = [
        run_scenario(scenario, selected, args.timeout, cache)
        for scenario in scenarios()
    ]
    finished_at = utc_now()
    report = build_report(
        selected, results, run_id, started_at, finished_at, repository
    )
    path = write_report(report, args.output_dir)
    summary = report["summary"]
    print(
        f"behavior lab: {summary['passed']} passed, {summary['failed']} failed, "
        f"{summary['skipped']} skipped, {summary['not_run']} not run, "
        f"{summary['unsupported']} unsupported"
    )
    print(f"behavior lab report: {path}")
    return exit_code(report, args.strict)


if __name__ == "__main__":
    raise SystemExit(main())
