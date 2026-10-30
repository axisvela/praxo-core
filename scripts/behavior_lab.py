from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path

from compatibility_lab import (
    Command,
    git_metadata,
    new_run_id,
    run_command,
    utc_now,
)


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "build" / "behavior-lab"
SCHEMA = "praxo-behavior-lab-1"
LANGUAGES = ("go", "python", "typescript", "java")


@dataclass(frozen=True)
class Scenario:
    key: str
    title: str
    commands: dict[str, tuple[Command, ...]]
    coverage: dict[str, str]


def go_test(pattern: str, package: str = "./pkg/agent") -> Command:
    return Command(
        "go test " + package + " " + pattern,
        ("go", "test", package, "-run", pattern, "-count=1"),
        ROOT,
    )


def python_test(*names: str) -> Command:
    return Command(
        "python " + " ".join(names),
        (sys.executable, "-m", "unittest", *names),
        ROOT / "language" / "python",
    )


def typescript_test(
    pattern: str,
    file: str = "tests/sdk.test.js",
) -> Command:
    return Command(
        "node --test " + file + " " + pattern,
        ("node", "--test", "--test-name-pattern", pattern, file),
        ROOT / "language" / "typescript",
    )


def java_class_test(qualified_name: str) -> Command:
    classpath = "target/classes" + os.pathsep + "target/test-classes"
    return Command(
        "java " + qualified_name,
        ("java", "-cp", classpath, qualified_name),
        ROOT / "language" / "java",
    )


def java_test(name: str) -> Command:
    return java_class_test("io.axisvela.praxo.agent." + name)


def scenarios() -> tuple[Scenario, ...]:
    auth = java_test("AgentAuthorizationSelfTest")
    lifecycle = java_test("AgentLifecycleSelfTest")
    guardrail = java_test("AgentGuardrailSelfTest")
    schema = java_class_test("io.axisvela.praxo.jsonschema.JsonSchemaSelfTest")
    checkpoint = java_class_test("io.axisvela.praxo.checkpoint.CheckpointSelfTest")
    pii = java_class_test("io.axisvela.praxo.middleware.PiiMiddlewareSelfTest")
    stream = java_test("AgentStreamSelfTest")
    concurrency = java_test("AgentConcurrencySelfTest")
    return (
        Scenario(
            "final-arguments",
            "Middleware-mutated arguments are reauthorized before effects",
            {
                "go": (go_test("^TestFinalToolArgumentsAuthorized$"),),
                "python": (
                    python_test(
                        "tests.test_authorization.AuthorizationTest."
                        "test_middleware_argument_change_is_reauthorized"
                    ),
                ),
                "typescript": (
                    typescript_test("middleware argument changes"),
                ),
                "java": (auth,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group"},
        ),
        Scenario(
            "final-name",
            "Final tool name is checked against allowlist and policy",
            {
                "go": (
                    go_test(
                        "^(TestFinalToolNameReauthorized|TestFinalToolNameChecksAllowlist)$"
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_authorization.AuthorizationTest."
                        "test_middleware_name_change_uses_final_tool_and_authorization",
                        "tests.test_authorization.AuthorizationTest."
                        "test_final_name_must_remain_allowed",
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "middleware name changes|final name must remain allowed"
                    ),
                ),
                "java": (auth,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group"},
        ),
        Scenario(
            "unchanged-single-auth",
            "Unchanged tool calls keep one authorization",
            {
                "go": (go_test("^TestFinalToolArgumentsAuthorized$"),),
                "python": (
                    python_test(
                        "tests.test_authorization.AuthorizationTest."
                        "test_unchanged_tool_is_authorized_once"
                    ),
                ),
                "typescript": (
                    typescript_test("unchanged tool is authorized once"),
                ),
                "java": (auth,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group"},
        ),
        Scenario(
            "initial-denial",
            "Initial policy denial prevents middleware and effects",
            {
                "go": (go_test("^TestOriginalToolDenialStillPrecedesMiddleware$"),),
                "python": (
                    python_test(
                        "tests.test_authorization.AuthorizationTest."
                        "test_initial_denial_prevents_middleware_and_effect"
                    ),
                ),
                "typescript": (
                    typescript_test("initial policy denial prevents middleware"),
                ),
                "java": (auth,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group"},
        ),
        Scenario(
            "startup-cleanup",
            "Before-run failure cleans entered middleware without run events",
            {
                "go": (go_test("^TestRunCleansUpEnteredMiddlewareOnStartFailure$"),),
                "python": (
                    python_test(
                        "tests.test_lifecycle.LifecycleTest."
                        "test_startup_failure_cleans_entered_and_emits_no_events"
                    ),
                ),
                "typescript": (
                    typescript_test("startup failure cleans entered middleware"),
                ),
                "java": (lifecycle,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group"},
        ),
        Scenario(
            "after-run-continue",
            "After-run continues later callbacks and preserves run error",
            {
                "go": (go_test("^TestRunCleansUpAfterMiddlewareFailure$"),),
                "python": (
                    python_test(
                        "tests.test_lifecycle.LifecycleTest."
                        "test_cleanup_continues_and_preserves_run_error"
                    ),
                ),
                "typescript": (
                    typescript_test("cleanup continues and preserves"),
                ),
                "java": (lifecycle,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group"},
        ),
        Scenario(
            "cleanup-failclosed",
            "Cleanup failure fails a successful run closed",
            {
                "go": (
                    go_test(
                        "^(TestRunCompletionCallbackFailureHasSingleTerminalEvent|"
                        "TestRunFailurePreservesOriginalError)$"
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_lifecycle.LifecycleTest."
                        "test_cleanup_error_after_success_fails_closed"
                    ),
                ),
                "typescript": (
                    typescript_test("cleanup error after success"),
                ),
                "java": (lifecycle,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group"},
        ),
        Scenario(
            "model-cancel-cleanup",
            "Cancellation during model work runs after-run and emits failed",
            {
                "go": (go_test("^TestRunCancellationKeepsOriginalErrorOverAfterRunError$"),),
                "python": (
                    python_test(
                        "tests.test_lifecycle.LifecycleTest."
                        "test_cancellation_runs_after_run_and_emits_failed"
                    ),
                ),
                "typescript": (
                    typescript_test("^cancellation runs after-run and emits failed$"),
                ),
                "java": (lifecycle,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group"},
        ),
        Scenario(
            "tool-cancel-cleanup",
            "Cancellation during tool work stops effects and runs after-run",
            {
                "go": (go_test("^TestRunStopsStartingToolsAfterCancellation$"),),
                "python": (
                    python_test(
                        "tests.test_lifecycle.LifecycleTest."
                        "test_tool_cancellation_runs_after_run"
                    ),
                ),
                "typescript": (
                    typescript_test("tool cancellation runs after-run"),
                ),
                "java": (lifecycle,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group"},
        ),
        Scenario(
            "schema-number-unicode",
            "Schema rejects fractional integers and counts Unicode code points",
            {
                "go": (
                    go_test(
                        "^(TestIntegerRejectsFractions|TestLengthCountsRunes)$",
                        "./pkg/tool/jsonschema",
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_jsonschema.JsonSchemaTest."
                        "test_integer_rejects_fractions",
                        "tests.test_jsonschema.JsonSchemaTest."
                        "test_length_counts_unicode_code_points",
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "schema integer rejects fractions|"
                        "schema length counts Unicode",
                        "tests/behavior.test.js",
                    ),
                ),
                "java": (schema,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "scenario"},
        ),
        Scenario(
            "call-limit",
            "Model and tool call limits fail closed",
            {
                "go": (
                    go_test(
                        "^(TestCallLimitMiddlewareModelLimit|"
                        "TestCallLimitMiddlewareToolLimit)$",
                        "./pkg/agent/middleware",
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_middleware.MiddlewareTest."
                        "test_model_call_limit",
                        "tests.test_middleware.MiddlewareTest."
                        "test_tool_call_limit",
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "model call limit fails closed|tool call limit fails closed",
                        "tests/behavior.test.js",
                    ),
                ),
                "java": (guardrail,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group"},
        ),
        Scenario(
            "pii-tool-history",
            "PII middleware redacts nested tool-call history without mutating input",
            {
                "go": (
                    go_test(
                        "^TestPIIMiddlewareRedactsToolCallHistory$",
                        "./pkg/agent/middleware",
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_middleware.MiddlewareTest."
                        "test_pii_redacts_tool_call_history"
                    ),
                ),
                "typescript": (
                    typescript_test("PII middleware redacts tool-call history"),
                ),
                "java": (pii,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "scenario"},
        ),
        Scenario(
            "checkpoint-content",
            "Checkpoint allowlist round-trips nested payload content",
            {
                "go": (
                    go_test("^TestAllowlistRoundTrip$", "./pkg/checkpoint"),
                ),
                "python": (
                    python_test(
                        "tests.test_checkpoint.CheckpointTest."
                        "test_allowlist_round_trips_content"
                    ),
                ),
                "typescript": (
                    typescript_test("checkpoint allowlist round-trips"),
                ),
                "java": (checkpoint,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "scenario"},
        ),
        Scenario(
            "capacity-failclosed",
            "Context budget fails closed instead of silently dropping required input",
            {
                "go": (go_test("^TestAgentContextBudgetFailsClosed$"),),
                "python": (
                    python_test(
                        "tests.test_middleware.MiddlewareTest."
                        "test_context_budget_fails_closed"
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "context budget fails closed",
                        "tests/behavior.test.js",
                    ),
                ),
                "java": (guardrail,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group"},
        ),
        Scenario(
            "parallel-tools",
            "Tools start concurrently up to the configured limit and keep result order",
            {
                "go": (go_test("^TestRunInvokesToolsInParallel$"),),
                "python": (
                    python_test(
                        "tests.test_parallel.ParallelToolTest."
                        "test_tools_start_in_parallel_and_keep_call_order"
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "maxParallelTools starts tools concurrently and keeps order",
                        "tests/behavior.test.js",
                    ),
                ),
                "java": (concurrency,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group"},
        ),
        Scenario(
            "run-state-isolation",
            "Call-limit state is isolated across concurrent runs",
            {
                "go": (
                    go_test(
                        "^TestCallLimitMiddlewareSeparatesRuns$",
                        "./pkg/agent/middleware",
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_middleware.MiddlewareTest."
                        "test_call_limit_state_is_isolated_by_run"
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "call limit state is isolated by run",
                        "tests/behavior.test.js",
                    ),
                ),
                "java": (guardrail,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group"},
        ),
        Scenario(
            "stream-callback-error",
            "Stream callback failure aborts the run instead of completing it",
            {
                "go": (go_test("^TestAgentStreamErrorAbortsRun$"),),
                "python": (
                    python_test(
                        "tests.test_openaicompat.StreamingAgentTest."
                        "test_stream_callback_failure_aborts_run"
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "stream callback failure aborts run",
                        "tests/behavior.test.js",
                    ),
                ),
                "java": (stream,),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "scenario"},
        ),
    )


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
            result = run_command(command, timeout)
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
    counts = {"cells": 0, "passed": 0, "failed": 0, "skipped": 0, "not_run": 0, "unsupported": 0}
    for result in results:
        for cell in result["languages"].values():
            counts["cells"] += 1
            counts[str(cell["status"])] += 1
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
        "| Scenario | Go | Python | TypeScript | Java |",
        "| --- | --- | --- | --- | --- |",
    ]
    for result in report["scenarios"]:
        cells = []
        for language in LANGUAGES:
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
        summary["not_run"] or summary["skipped"] or summary["unsupported"]
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
    parser.add_argument("--languages", default=",".join(LANGUAGES))
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
    results = [
        run_scenario(scenario, selected, args.timeout)
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
