from __future__ import annotations

import argparse
import datetime as dt
import json
import platform
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "build" / "compatibility-lab"
SCHEMA = "praxo-compatibility-lab-1"
OUTPUT_TAIL = 4000
DEFAULT_LANGUAGES = ("python", "typescript", "java", "rust")


@dataclass(frozen=True)
class Command:
    label: str
    argv: tuple[str, ...]
    cwd: Path


@dataclass(frozen=True)
class Language:
    key: str
    name: str
    version: tuple[str, ...]
    install: tuple[Command, ...]
    run: tuple[Command, ...]


def command(label: str, cwd: Path, *argv: str) -> Command:
    return Command(label, tuple(argv), cwd)


def language_definitions() -> dict[str, Language]:
    python_dir = ROOT / "language" / "python"
    typescript_dir = ROOT / "language" / "typescript"
    java_dir = ROOT / "language" / "java"
    rust_dir = ROOT / "language" / "rust"
    fortran_dir = ROOT / "language" / "fortran"
    cobol_dir = ROOT / "language" / "cobol"
    return {
        "python": Language(
            "python",
            "Python",
            (sys.executable, "--version"),
            (),
            (
                command("conformance", python_dir, sys.executable, "conformance/run.py"),
                command("api snapshot", python_dir, sys.executable, "api-snapshot.py", "--check"),
                command("api signatures", python_dir, sys.executable, "api-signatures.py", "--check"),
            ),
        ),
        "typescript": Language(
            "typescript",
            "TypeScript",
            ("node", "--version"),
            (command("npm ci", typescript_dir, "npm", "ci"),),
            (
                command("build", typescript_dir, "npm", "run", "build"),
                command("api check", typescript_dir, "npm", "run", "api:check"),
                command("conformance", typescript_dir, "npm", "run", "conformance"),
            ),
        ),
        "java": Language(
            "java",
            "Java",
            ("java", "-version"),
            (),
            (
                command("package", java_dir, "mvn", "-q", "-DskipTests", "package"),
                command(
                    "api snapshot",
                    java_dir,
                    "java",
                    "-cp",
                    "target/classes",
                    "io.axisvela.praxo.conformance.ApiSnapshot",
                    "--check",
                ),
                command(
                    "conformance",
                    java_dir,
                    "java",
                    "-cp",
                    "target/classes",
                    "io.axisvela.praxo.conformance.Run",
                ),
            ),
        ),
        "rust": Language(
            "rust",
            "Rust",
            ("cargo", "--version"),
            (),
            (
                command(
                    "conformance",
                    rust_dir,
                    "cargo",
                    "run",
                    "--quiet",
                    "--bin",
                    "conformance",
                ),
                command("api snapshot", rust_dir, sys.executable, "api-snapshot.py", "--check"),
            ),
        ),
        "fortran": Language(
            "fortran",
            "Fortran",
            ("gfortran", "--version"),
            (),
            (command("tests", fortran_dir, sys.executable, "run-tests.py"),),
        ),
        "cobol": Language(
            "cobol",
            "COBOL",
            ("cobc", "--version"),
            (),
            (command("tests", cobol_dir, sys.executable, "run-tests.py"),),
        ),
    }


def git_metadata() -> dict[str, object]:
    try:
        sha = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        ).stdout.strip()
        dirty = bool(
            subprocess.run(
                ["git", "status", "--porcelain"],
                cwd=ROOT,
                check=True,
                capture_output=True,
                text=True,
                timeout=30,
            ).stdout.strip()
        )
        return {"sha": sha, "dirty": dirty}
    except (OSError, subprocess.SubprocessError):
        return {"sha": None, "dirty": None}


def tail(value: str) -> str:
    value = value or ""
    if len(value) <= OUTPUT_TAIL:
        return value
    return value[-OUTPUT_TAIL:]


def resolve_executable(argv: tuple[str, ...]) -> str | None:
    if not argv:
        return None
    if Path(argv[0]).is_absolute():
        return argv[0] if Path(argv[0]).is_file() else None
    return shutil.which(argv[0])


def executable_available(argv: tuple[str, ...]) -> bool:
    return resolve_executable(argv) is not None


def run_command(item: Command, timeout: float) -> dict[str, object]:
    started = time.monotonic()
    executable = resolve_executable(item.argv)
    if executable is None:
        return {
            "label": item.label,
            "argv": list(item.argv),
            "cwd": str(item.cwd),
            "status": "skipped",
            "exit_code": None,
            "duration_ms": 0,
            "stdout": "",
            "stderr": "",
            "reason": f"executable not found: {item.argv[0]}",
        }
    if not item.cwd.is_dir():
        return {
            "label": item.label,
            "argv": list(item.argv),
            "cwd": str(item.cwd),
            "status": "skipped",
            "exit_code": None,
            "duration_ms": 0,
            "stdout": "",
            "stderr": "",
            "reason": f"working directory not found: {item.cwd}",
        }
    try:
        completed = subprocess.run(
            [executable, *item.argv[1:]],
            cwd=item.cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        status = "passed" if completed.returncode == 0 else "failed"
        return {
            "label": item.label,
            "argv": list(item.argv),
            "cwd": str(item.cwd),
            "status": status,
            "exit_code": completed.returncode,
            "duration_ms": int((time.monotonic() - started) * 1000),
            "stdout": tail(completed.stdout),
            "stderr": tail(completed.stderr),
            "reason": None,
        }
    except subprocess.TimeoutExpired as error:
        return {
            "label": item.label,
            "argv": list(item.argv),
            "cwd": str(item.cwd),
            "status": "failed",
            "exit_code": None,
            "duration_ms": int((time.monotonic() - started) * 1000),
            "stdout": tail(error.stdout or ""),
            "stderr": tail(error.stderr or ""),
            "reason": f"timeout after {timeout}s",
        }
    except OSError as error:
        return {
            "label": item.label,
            "argv": list(item.argv),
            "cwd": str(item.cwd),
            "status": "failed",
            "exit_code": None,
            "duration_ms": int((time.monotonic() - started) * 1000),
            "stdout": "",
            "stderr": "",
            "reason": str(error),
        }


def version_text(argv: tuple[str, ...], timeout: float) -> str:
    executable = resolve_executable(argv)
    if executable is None:
        return "unavailable"
    try:
        completed = subprocess.run(
            [executable, *argv[1:]],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        output = (completed.stdout or "").strip() or (completed.stderr or "").strip()
        return output.splitlines()[0] if output else "unknown"
    except (OSError, subprocess.SubprocessError, IndexError):
        return "unknown"


def run_language(
    item: Language,
    timeout: float,
    install: bool,
) -> dict[str, object]:
    commands: list[dict[str, object]] = []
    if install:
        for setup in item.install:
            result = run_command(setup, timeout)
            commands.append(result)
            if result["status"] != "passed":
                return language_result(item, commands, timeout)
    for step in item.run:
        result = run_command(step, timeout)
        commands.append(result)
        if result["status"] != "passed":
            break
    return language_result(item, commands, timeout)


def language_result(
    item: Language,
    commands: list[dict[str, object]],
    timeout: float,
) -> dict[str, object]:
    statuses = [str(entry["status"]) for entry in commands]
    if "failed" in statuses:
        status = "failed"
    elif "skipped" in statuses:
        status = "skipped"
    else:
        status = "passed"
    reason = next(
        (entry.get("reason") for entry in commands if entry.get("reason")),
        None,
    )
    return {
        "key": item.key,
        "name": item.name,
        "status": status,
        "version": version_text(item.version, timeout),
        "commands": commands,
        "reason": reason,
    }


def summarize(results: list[dict[str, object]]) -> dict[str, int]:
    return {
        "total": len(results),
        "passed": sum(1 for result in results if result["status"] == "passed"),
        "failed": sum(1 for result in results if result["status"] == "failed"),
        "skipped": sum(1 for result in results if result["status"] == "skipped"),
    }


def build_report(
    selected: list[str],
    results: list[dict[str, object]],
) -> dict[str, object]:
    return {
        "schema": SCHEMA,
        "generated_at": dt.datetime.now(dt.timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z"),
        "repository": git_metadata(),
        "environment": {
            "platform": platform.platform(),
            "python": sys.version.split()[0],
        },
        "selection": selected,
        "languages": results,
        "summary": summarize(results),
    }


def markdown_report(report: dict[str, object]) -> str:
    repository = report["repository"]
    summary = report["summary"]
    lines = [
        "# PRAXO-CORE Compatibility Lab",
        "",
        f"- Generated: `{report['generated_at']}`",
        f"- Repository: `{repository.get('sha') or 'unknown'}`"
        f" ({'dirty' if repository.get('dirty') else 'clean' if repository.get('dirty') is False else 'unknown'})",
        f"- Platform: `{report['environment']['platform']}`",
        f"- Summary: {summary['passed']} passed, {summary['failed']} failed, "
        f"{summary['skipped']} skipped of {summary['total']}",
        "",
        "| Language | Status | Toolchain | Detail |",
        "| --- | --- | --- | --- |",
    ]
    for result in report["languages"]:
        detail = result.get("reason") or " ".join(
            str(entry["label"]) for entry in result["commands"]
        )
        lines.append(
            f"| {result['name']} | {result['status']} | `{result['version']}` | {detail} |"
        )
    lines.extend(
        [
            "",
            "This report covers deterministic contract conformance only. It is not",
            "provider, production, or security verification.",
        ]
    )
    return "\n".join(lines) + "\n"


def exit_code(report: dict[str, object], strict: bool) -> int:
    summary = report["summary"]
    if summary["failed"]:
        return 1
    if strict and summary["skipped"]:
        return 1
    return 0


def parse_languages(value: str, available: dict[str, Language]) -> list[str]:
    selected = [item.strip() for item in value.split(",") if item.strip()]
    unknown = [item for item in selected if item not in available]
    if unknown:
        raise ValueError(f"unknown language: {', '.join(unknown)}")
    if not selected:
        raise ValueError("at least one language is required")
    return selected


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Run deterministic Core conformance and write a compatibility report"
    )
    parser.add_argument(
        "--languages",
        default=",".join(DEFAULT_LANGUAGES),
        help="comma-separated languages",
    )
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--timeout", type=float, default=300.0)
    parser.add_argument("--install", action="store_true")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args(argv)

    available = language_definitions()
    try:
        selected = parse_languages(args.languages, available)
    except ValueError as error:
        parser.error(str(error))

    results = [
        run_language(available[key], args.timeout, args.install) for key in selected
    ]
    report = build_report(selected, results)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "report.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    (args.output_dir / "report.md").write_text(
        markdown_report(report),
        encoding="utf-8",
        newline="\n",
    )
    summary = report["summary"]
    print(
        f"compatibility lab: {summary['passed']} passed, "
        f"{summary['failed']} failed, {summary['skipped']} skipped"
    )
    return exit_code(report, args.strict)


if __name__ == "__main__":
    raise SystemExit(main())
