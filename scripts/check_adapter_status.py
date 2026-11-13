#!/usr/bin/env python3
"""Validate the language adapter matrix against source and generated docs.

The check catches the drift that is easy to introduce when a new adapter is
added: a source implementation without an adapter-status row, duplicate rows,
stale reference baselines, or a registry Positioning tag that no longer matches
the registry metadata.
"""

from __future__ import annotations

import argparse
import importlib.util
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / "docs" / "languages" / "adapter-status.md"
MCP_REFERENCE = ROOT / "docs" / "reference" / "mcp-client.md"
HARMOVELA_REFERENCE = ROOT / "docs" / "reference" / "harmovela-sink.md"
SYNC_SCRIPT = ROOT / "scripts" / "sync_language_registry_docs.py"

SECTIONS = (
    ("Model (OpenAI-Compatible)", "openai", "OpenAI-compatible model"),
    ("Model (Anthropic Native)", "anthropic", "Anthropic model"),
    ("Model (Gemini Native)", "gemini", "Gemini model"),
    ("MCP", "mcp", "MCP client"),
    ("Harmovela", "harmovela", "Harmovela sink"),
    ("OpenTelemetry", "otel", "OpenTelemetry sink"),
    ("Delegation", "delegation", "Subagent delegation"),
    ("Retriever", "retriever", "Retriever"),
)

SKIP_PARTS = {
    ".git", ".hg", ".svn", "__pycache__", "build", "dist", "target", "_build",
    "node_modules", "vendor", "deps", ".venv", "venv", "docs", "doc", "tests",
    "test", "coverage", "api", "spec",
}
SOURCE_SUFFIXES = {
    ".go", ".py", ".ts", ".tsx", ".js", ".mjs", ".dart", ".java", ".kt", ".scala",
    ".cs", ".fs", ".rs", ".c", ".h", ".cc", ".cpp", ".cxx", ".hpp", ".rb",
    ".php", ".ex", ".exs", ".erl", ".hrl", ".lua", ".pl", ".pm", ".d", ".di",
    ".pas", ".pp", ".m", ".mm", ".swift", ".jl", ".hs", ".ml", ".mli", ".nim",
    ".v", ".zig", ".cbl", ".cob", ".f90", ".f95", ".f", ".F90", ".F95",
    ".psm1", ".ps1", ".r", ".R", ".CBL", ".COB", ".PAS", ".P",
}

# directory under language/ -> display name used in adapter-status.md
LANGUAGE_DIRS = {
    "c": "C",
    "cobol": "COBOL",
    "cpp": "C++",
    "csharp": "C#",
    "d": "D",
    "dart": "Dart",
    "delphi": "Delphi / Free Pascal",
    "elixir": "Elixir",
    "erlang": "Erlang",
    "fortran": "Fortran",
    "haskell": "Haskell",
    "java": "Java",
    "julia": "Julia",
    "lua": "Lua",
    "matlab-octave-core": "shared",
    "nim": "Nim",
    "objc": "Objective-C",
    "ocaml": "OCaml",
    "perl": "Perl",
    "php": "PHP",
    "powershell": "PowerShell",
    "python": "Python",
    "r": "R",
    "ruby": "Ruby",
    "rust": "Rust",
    "swift": "Swift",
    "typescript": "TypeScript",
    "v": "V",
    "zig": "Zig",
}

SHARED_DISPLAYS = ("MATLAB", "GNU Octave")
MARKERS = {
    "openai": re.compile(r"openai", re.IGNORECASE),
    "anthropic": re.compile(r"anthropic", re.IGNORECASE),
    "gemini": re.compile(r"gemini", re.IGNORECASE),
    "mcp": re.compile(r"Mcp|MCP|(?<![a-z])mcp(?![a-z])"),
    "harmovela": re.compile(r"harmovela", re.IGNORECASE),
    "otel": re.compile(r"opentelemetry|otlp|(?<![a-z])otel(?![a-z])", re.IGNORECASE),
    "delegation": re.compile(r"delegation|subagent", re.IGNORECASE),
    "retriever": re.compile(r"retriever", re.IGNORECASE),
}
TAG = re.compile(r"`([a-z0-9-]+/v[0-9]+\.[0-9]+\.[0-9]+)`")
CAPABILITY_LABELS = (
    "OpenAI-compatible model",
    "Anthropic model",
    "Gemini model",
    "MCP client",
    "Harmovela sink",
    "OpenTelemetry sink",
    "Subagent delegation",
    "Retriever",
)


def sync_module():
    spec = importlib.util.spec_from_file_location("sync_language_registry_docs", SYNC_SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load " + str(SYNC_SCRIPT))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def parse_tables(text: str) -> tuple[dict[str, dict[str, tuple[str, str]]], list[str]]:
    tables: dict[str, dict[str, tuple[str, str]]] = {}
    problems: list[str] = []
    for heading, key, label in SECTIONS:
        match = re.search(r"## " + re.escape(heading) + r"\n(.*?)(?=\n## |\Z)", text, re.DOTALL)
        if not match:
            problems.append("adapter-status.md: missing section " + heading)
            continue
        rows: dict[str, tuple[str, str]] = {}
        for line in match.group(1).splitlines():
            if not line.startswith("| ") or line.startswith("| Language") or line.startswith("| ---"):
                continue
            cells = [cell.strip() for cell in line.strip("|").split("|")]
            language = cells[0]
            if language.startswith("All other") or language.startswith("Other"):
                continue
            if language in rows:
                problems.append(f"adapter-status.md: duplicate {label} row for {language}")
                continue
            rows[language] = (cells[1], " | ".join(cells[2:]).strip())
        tables[key] = rows
    return tables, problems


def source_files(directory: Path):
    for path in directory.rglob("*"):
        if not path.is_file() or path.suffix not in SOURCE_SUFFIXES:
            continue
        if any(part in SKIP_PARTS for part in path.relative_to(directory).parts):
            continue
        if path.stat().st_size > 5 * 1024 * 1024:
            continue
        yield path


def detect_categories() -> dict[str, set[str]]:
    detected = {key: set() for _, key, _ in SECTIONS}
    roots: list[tuple[str, Path]] = [
        ("Go", ROOT / "adapters"),
        ("Go", ROOT / "pkg" / "agent" / "delegation"),
        ("Go", ROOT / "pkg" / "retriever"),
    ]
    for directory, display in LANGUAGE_DIRS.items():
        roots.append((display, ROOT / "language" / directory))
    for display, directory in roots:
        if not directory.is_dir():
            continue
        displays = SHARED_DISPLAYS if display == "shared" else (display,)
        for path in source_files(directory):
            text = path.read_text(encoding="utf-8", errors="ignore")
            for key, pattern in MARKERS.items():
                if pattern.search(text):
                    detected[key].update(displays)
    return detected


def first_paragraph(path: Path) -> str:
    lines = path.read_text(encoding="utf-8").splitlines()
    paragraph: list[str] = []
    started = False
    for line in lines:
        if line.startswith("# "):
            continue
        if not line.strip():
            if started and paragraph:
                break
            continue
        started = True
        paragraph.append(line.strip())
    return " ".join(paragraph)


def registry_positioning(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    match = re.search(r"## Positioning\n\n(.*?)(?=\n## |\Z)", text, re.DOTALL)
    return match.group(1) if match else ""


def validate(root: Path = ROOT) -> list[str]:
    adapter_text = (root / ADAPTER.relative_to(ROOT)).read_text(encoding="utf-8")
    tables, problems = parse_tables(adapter_text)
    detected = detect_categories()

    for _, key, label in SECTIONS:
        rows = tables.get(key, {})
        missing = sorted(detected[key] - set(rows))
        for language in missing:
            problems.append(
                f"adapter-status.md: {language} has a {label} implementation but no row"
            )
        phantom = sorted(
            language
            for language, (status, _) in rows.items()
            if status.startswith("native") and language not in detected[key]
        )
        for language in phantom:
            problems.append(
                f"adapter-status.md: {language} is listed as {label} but no source marker was found"
            )

    mcp_text = (root / MCP_REFERENCE.relative_to(ROOT)).read_text(encoding="utf-8")
    if "languages/adapter-status.md#mcp" not in mcp_text:
        problems.append("mcp-client.md: baseline must link to languages/adapter-status.md#mcp")
    harmovela_text = (root / HARMOVELA_REFERENCE.relative_to(ROOT)).read_text(encoding="utf-8")
    if "languages/adapter-status.md#harmovela" not in harmovela_text:
        problems.append(
            "harmovela-sink.md: baseline must link to languages/adapter-status.md#harmovela"
        )

    sync = sync_module()
    capabilities = sync.adapter_capabilities()
    for entry in sync.LANGUAGES:
        directory = root / entry["dir"]
        tag = entry["tag"]
        readme = directory / "README.md"
        registry = directory / "REGISTRY.md"
        for name, scope in (
            ("README.md", first_paragraph(readme)),
            ("REGISTRY.md", registry_positioning(registry)),
        ):
            for found in TAG.findall(scope):
                if found != tag:
                    problems.append(
                        f"{directory.name}/{name}: Positioning tag {found} != {tag}"
                    )
        if entry["dir"] == "." or entry["name"] == "MATLAB/Octave shared core":
            continue
        if "## Capabilities and Status" not in registry.read_text(encoding="utf-8"):
            problems.append(f"{directory.name}/REGISTRY.md: missing Capabilities and Status")
            continue
        registry_text = registry.read_text(encoding="utf-8")
        for _, _, label in SECTIONS:
            status, _ = capabilities[label].get(entry["name"], ("not implemented", ""))
            expected = f"| {label} | {status} |"
            if expected not in registry_text:
                problems.append(
                    f"{directory.name}/REGISTRY.md: missing capability row {expected}"
                )
    return problems


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    problems = validate()
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1
    if args.check:
        print("adapter status and registry capabilities are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
