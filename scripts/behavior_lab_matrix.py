from __future__ import annotations

import argparse
import json
from pathlib import Path


LANGUAGES = [
    ("go", "Go", "Go"),
    ("python", "Python", "Py"),
    ("typescript", "TypeScript", "TS"),
    ("java", "Java", "Java"),
    ("rust", "Rust", "Rust"),
    ("fortran", "Fortran", "Ftn"),
    ("cobol", "COBOL", "COB"),
    ("ruby", "Ruby", "Ruby"),
    ("elixir", "Elixir", "Ex"),
    ("erlang", "Erlang", "Erl"),
    ("cpp", "C++", "C++"),
    ("php", "PHP", "PHP"),
    ("csharp", "C#", "C#"),
    ("lua", "Lua", "Lua"),
]

LABELS = {
    "en": {
        "title": "# Behavior Lab Matrix",
        "status": "**Status:** generated evidence matrix, 2026-10-31. The lab is not a stable public API.",
        "intro": (
            "This page expands the summary in [Behavior Lab](behavior-lab.md) into a "
            "scenario-by-language matrix and per-language report sections. The source "
            "is a Behavior Lab JSON report; the raw per-command stdout/stderr remains "
            "in the report artifact."
        ),
        "summary": "## Summary",
        "metric": "Metric",
        "value": "Value",
        "languages": "Languages",
        "scenarios": "Scenarios",
        "cells": "Cells",
        "passed": "Passed",
        "unsupported": "Unsupported",
        "failed": "Failed",
        "source": "Source report",
        "run_id": "Run ID",
        "sha": "Revision",
        "dirty": "Working tree dirty",
        "job": "CI job",
        "legend": "## Matrix legend",
        "cell": "Cell",
        "meaning": "Meaning",
        "scenario": "Named scenario test",
        "group": "Java self-test group covering multiple scenarios",
        "suite": "Native test suite; not isolated to the scenario",
        "none": "No scenario or suite coverage",
        "matrix": "## Scenario matrix",
        "scenario_col": "Scenario",
        "reports": "## Per-language reports",
        "coverage": "Coverage",
        "passed_count": "Passed",
        "unsupported_count": "Unsupported",
        "covered": "Covered scenarios",
        "not_covered": "Unsupported scenarios",
        "commands": "Commands",
        "none_value": "none",
        "raw": "Raw evidence",
        "raw_text": (
            "The CI job and artifact contain the per-command exit code, duration, "
            "stdout, and stderr. This matrix records status and coverage, not the "
            "full command output."
        ),
    },
    "zh": {
        "title": "# 行为实验矩阵",
        "status": "**状态：** 自动生成的证据矩阵，2026-10-31。该实验不是稳定的公开 API。",
        "intro": (
            "本页把[行为实验](behavior-lab.md)的汇总展开为场景×语言矩阵和逐语言报告。"
            "数据源是 Behavior Lab JSON 报告；每条命令的 stdout/stderr 保留在报告 artifact 中。"
        ),
        "summary": "## 汇总",
        "metric": "指标",
        "value": "值",
        "languages": "语言数",
        "scenarios": "场景数",
        "cells": "单元格数",
        "passed": "通过",
        "unsupported": "不支持",
        "failed": "失败",
        "source": "源报告",
        "run_id": "Run ID",
        "sha": "Revision",
        "dirty": "工作区未提交",
        "job": "CI 任务",
        "legend": "## 矩阵图例",
        "cell": "单元格",
        "meaning": "含义",
        "scenario": "具名场景测试",
        "group": "覆盖多个场景的 Java self-test 组",
        "suite": "原生测试套件；不是场景隔离断言",
        "none": "没有场景或套件覆盖",
        "matrix": "## 场景矩阵",
        "scenario_col": "场景",
        "reports": "## 逐语言报告",
        "coverage": "覆盖类型",
        "passed_count": "通过",
        "unsupported_count": "不支持",
        "covered": "已覆盖场景",
        "not_covered": "未覆盖场景",
        "commands": "命令",
        "none_value": "无",
        "raw": "原始证据",
        "raw_text": (
            "CI job 和 artifact 包含每条命令的退出码、耗时、stdout 和 stderr。"
            "本矩阵记录状态和覆盖类型，不复制完整命令输出。"
        ),
    },
}

SYMBOLS = {
    "scenario": "S",
    "group": "G",
    "suite": "N",
}

COVERAGE_LABELS = {
    "en": {"scenario": "scenario", "group": "group", "suite": "suite", "none": "none"},
    "zh": {"scenario": "场景级", "group": "组", "suite": "套件级", "none": "无"},
}


def load_report(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def cell_symbol(cell: dict) -> str:
    if cell.get("status") == "unsupported":
        return "-"
    coverage = cell.get("coverage", "none")
    return SYMBOLS.get(coverage, "P")


def render(report: dict, lang: str, report_name: str, evidence_url: str = "") -> str:
    labels = LABELS[lang]
    scenarios = report["scenarios"]
    summary = report["summary"]
    selected = [key for key, _, _ in LANGUAGES if key in summary or key in scenarios[0]["languages"]]
    language_rows = [(key, name, short) for key, name, short in LANGUAGES if key in selected]
    lines = [
        labels["title"],
        "",
        labels["status"],
        "",
        labels["intro"],
        "",
        labels["summary"],
        "",
        f"| {labels['metric']} | {labels['value']} |",
        "| --- | ---: |",
        f"| {labels['languages']} | {len(language_rows)} |",
        f"| {labels['scenarios']} | {len(scenarios)} |",
        f"| {labels['cells']} | {summary['cells']} |",
        f"| {labels['passed']} | {summary['passed']} |",
        f"| {labels['unsupported']} | {summary['unsupported']} |",
        f"| {labels['failed']} | {summary['failed']} |",
        f"| {labels['source']} | `{report_name}` |",
        f"| {labels['run_id']} | `{report.get('run_id', '')}` |",
        f"| {labels['sha']} | `{report.get('repository', {}).get('sha', '')}` |",
        f"| {labels['dirty']} | {report.get('repository', {}).get('dirty', '')} |",
        *( [f"| {labels['job']} | [GitHub Actions]({evidence_url}) |"] if evidence_url else [] ),
        "",
        labels["legend"],
        "",
        f"| {labels['cell']} | {labels['meaning']} |",
        "| --- | --- |",
        f"| `S` | {labels['scenario']} |",
        f"| `G` | {labels['group']} |",
        f"| `N` | {labels['suite']} |",
        f"| `-` | {labels['none']} |",
        "",
        labels["matrix"],
        "",
        "| " + labels["scenario_col"] + " | " + " | ".join(short for _, _, short in language_rows) + " |",
        "| --- | " + " | ".join("---" for _ in language_rows) + " |",
    ]
    for scenario in scenarios:
        cells = [
            cell_symbol(scenario["languages"][key])
            for key, _, _ in language_rows
        ]
        lines.append(f"| `{scenario['key']}` | " + " | ".join(cells) + " |")
    lines.extend(["", labels["reports"], ""])
    for key, name, _ in language_rows:
        passed = [s["key"] for s in scenarios if s["languages"][key].get("status") == "passed"]
        unsupported = [s["key"] for s in scenarios if s["languages"][key].get("status") != "passed"]
        coverage_values = sorted({
            s["languages"][key].get("coverage", "none")
            for s in scenarios
            if s["languages"][key].get("status") == "passed"
        })
        commands = []
        for scenario in scenarios:
            cell = scenario["languages"][key]
            for command in cell.get("commands", []):
                if command.get("status") == "passed":
                    label = command.get("label") or command.get("argv")
                    if label and label not in commands:
                        commands.append(label)
        lines.extend([
            f"### {name}",
            "",
            f"- {labels['coverage']}: {', '.join(COVERAGE_LABELS[lang].get(value, value) for value in coverage_values) or labels['none_value']}",
            f"- {labels['passed_count']}: {len(passed)}/{len(scenarios)}",
            f"- {labels['unsupported_count']}: {len(unsupported)}",
            f"- {labels['covered']}: {', '.join(f'`{item}`' for item in passed) or labels['none_value']}",
            f"- {labels['not_covered']}: {', '.join(f'`{item}`' for item in unsupported) or labels['none_value']}",
            "",
        ])
        if commands:
            lines.extend([f"{labels['commands']}:", "", "```text", *commands, "```", ""])
    lines.extend([
        f"## {labels['raw']}",
        "",
        labels["raw_text"],
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Render the Behavior Lab comparison matrix")
    parser.add_argument("--report", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--lang", choices=("en", "zh"), default="en")
    parser.add_argument("--evidence-url", default="")
    args = parser.parse_args()
    report = load_report(Path(args.report))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        render(report, args.lang, Path(args.report).name, args.evidence_url),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
