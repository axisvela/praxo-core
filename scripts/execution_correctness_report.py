import json
import os
import re
from pathlib import Path
from uuid import uuid4


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
        (run_dir / "events" / f"{name}.jsonl").write_text(
            "\n".join(event_lines) + ("\n" if event_lines else ""), encoding="utf-8")
        (run_dir / "stdout" / f"{name}.txt").write_text(str(run.get("stdout", "")), encoding="utf-8")
        (run_dir / "stderr" / f"{name}.txt").write_text(str(run.get("stderr", "")), encoding="utf-8")
        for package_row in report["packages"]:
            if package_row["package"] == package:
                package_row["eventsPath"] = str((run_dir / "events" / f"{name}.jsonl").relative_to(output_root))
                package_row["stdoutPath"] = str((run_dir / "stdout" / f"{name}.txt").relative_to(output_root))
                package_row["stderrPath"] = str((run_dir / "stderr" / f"{name}.txt").relative_to(output_root))

    (run_dir / "report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
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
