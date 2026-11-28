from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LANGUAGE = ROOT / "language"
WORKFLOWS = ROOT / ".github" / "workflows"
GO_ONLY = {"clojure", "fsharp", "groovy", "javascript", "kotlin", "opencl", "scala"}
THEMES = (
    "checkpoint",
    "event-sink",
    "retry",
    "provider-fallback",
    "streaming",
    "structured-output",
    "identity-policy",
    "service",
    "mcp",
)
ALIGNED_THEMES = ("consumer", "live-model", *THEMES, "hitl", "session-checkpoint")
ADVANCED_THEMES = (
    "advanced-delegation",
    "advanced-long-running",
    "advanced-workspace",
)
IGNORED_DIRECTORIES = {
    ".git", "__pycache__", "bin", "build", "dist", "node_modules", "obj",
    "target",
}
CODE_SUFFIXES = {
    ".c", ".cc", ".clj", ".cljc", ".cljs", ".cmd", ".cob", ".cpp", ".cs",
    ".cxx", ".d", ".dart", ".erl", ".escript", ".ex", ".exs", ".f", ".f90", ".f95",
    ".for", ".fs", ".fsx", ".go", ".groovy", ".h", ".hh", ".hpp", ".hrl",
    ".hs", ".java", ".jl", ".js", ".jsx", ".kt", ".lua", ".m", ".mjs",
    ".ml", ".mli", ".mm", ".nim", ".pas", ".php", ".pl", ".pm", ".ps1",
    ".py", ".r", ".rb", ".rs", ".scala", ".sh", ".swift", ".ts", ".tsx",
    ".v", ".zig",
}
NOT_APPLICABLE: dict[str, set[str]] = {}
CORE_PATTERN = re.compile(r"praxo", re.IGNORECASE)
R_CORE_PATTERN = re.compile(r"source\([^)]*core\.R|praxo", re.IGNORECASE)
ASSERTION_PATTERN = re.compile(
    r"assert|stopifnot|expect\(|@Test|#\[test\]|func Test|def test_|"
    r"test\(|Assert\.",
    re.IGNORECASE,
)

GO_THEMES = {
    "consumer": ROOT / "language/go/examples/consumer-go",
    "live-model": ROOT / "language/go/examples/live-model",
    "checkpoint": ROOT / "language/go/examples/recipes/checkpoint-store-go",
    "event-sink": ROOT / "language/go/examples/recipes/event-sinks-go",
    "retry": ROOT / "language/go/examples/recipes/retry-go",
    "provider-fallback": ROOT / "language/go/examples/recipes/provider-fallback-go",
    "streaming": ROOT / "language/go/examples/recipes/streaming-go",
    "structured-output": ROOT / "language/go/examples/recipes/structured-output-go",
    "identity-policy": ROOT / "language/go/examples/recipes/identity-go",
    "service": ROOT / "language/go/examples/embedded-service",
    "mcp": ROOT / "language/go/examples/ecosystem/mcp",
    "hitl": ROOT / "language/go/examples/hitl",
    "session-checkpoint": ROOT / "language/go/examples/session-checkpoint",
}

GO_ADVANCED_THEMES = {
    "advanced-delegation": ROOT / "language/go/examples/multiagent",
    "advanced-long-running": ROOT / "language/go/examples/recipes/long-running-go",
    "advanced-workspace": ROOT / "language/go/examples/governed-workspace",
}


def languages() -> list[str]:
    return sorted(
        path.name
        for path in LANGUAGE.iterdir()
        if path.is_dir() and path.name not in GO_ONLY and (path / "examples").is_dir()
    )


def example_path(language: str, theme: str) -> Path:
    if language == "go":
        return GO_THEMES[theme]
    if language == "octave":
        candidate = LANGUAGE / "octave" / "examples" / theme
        if (candidate / "README.md").is_file():
            return candidate
        return LANGUAGE / "matlab" / "examples" / theme
    return LANGUAGE / language / "examples" / theme


def advanced_path(language: str, theme: str) -> Path:
    if language == "go":
        return GO_ADVANCED_THEMES[theme]
    if language == "octave":
        candidate = LANGUAGE / "octave" / "examples" / theme
        if (candidate / "README.md").is_file():
            return candidate
        return LANGUAGE / "matlab" / "examples" / theme
    return LANGUAGE / language / "examples" / theme


def advanced_report_lines() -> list[str]:
    lines = ["language | advanced themes"]
    for language in languages():
        implemented = [
            theme
            for theme in ADVANCED_THEMES
            if implementation_files(advanced_path(language, theme))
        ]
        lines.append(f"{language} | {', '.join(implemented) or '-'}")
    return lines


def implementation_files(path: Path) -> list[Path]:
    if not path.is_dir():
        return []
    return sorted(
        file
        for file in path.rglob("*")
        if file.is_file()
        and file.name != "README.md"
        and file.suffix.lower() in CODE_SUFFIXES
        and not any(
            part in IGNORED_DIRECTORIES
            for part in file.relative_to(path).parts
        )
    )


def example_text(language: str, theme: str) -> str:
    paths = [example_path(language, theme)]
    if language == "octave":
        paths.append(example_path("matlab", theme))
    files: list[Path] = []
    for path in paths:
        files.extend(implementation_files(path))
    return "\n".join(
        file.read_text(encoding="utf-8", errors="replace") for file in files
    )


def uses_core(language: str, text: str) -> bool:
    pattern = R_CORE_PATTERN if language == "r" else CORE_PATTERN
    return bool(pattern.search(text))


def has_assertion(text: str) -> bool:
    return bool(ASSERTION_PATTERN.search(text))


def depth_report_lines() -> list[str]:
    lines = [
        "theme | Core reference | non-Core (mechanism or handler) | assertions",
    ]
    for theme in ALIGNED_THEMES:
        core: list[str] = []
        non_core: list[str] = []
        asserted: list[str] = []
        for language in languages():
            text = example_text(language, theme)
            if not text:
                continue
            (core if uses_core(language, text) else non_core).append(language)
            if has_assertion(text):
                asserted.append(language)
        total = len(core) + len(non_core)
        lines.append(
            f"{theme} | {len(core)}/{total} | "
            f"{', '.join(non_core) or '-'} | {len(asserted)}/{total}"
        )
    return lines


def missing_code() -> list[str]:
    failures = []
    for language in languages():
        for theme in ALIGNED_THEMES:
            if language in NOT_APPLICABLE.get(theme, set()):
                continue
            path = example_path(language, theme)
            if not implementation_files(path):
                failures.append(f"{language}/{theme}")
    return failures


def language_gaps(language: str) -> list[str]:
    gaps = []
    for theme in ALIGNED_THEMES:
        if language in NOT_APPLICABLE.get(theme, set()):
            continue
        if not implementation_files(example_path(language, theme)):
            gaps.append(theme)
    return gaps


def report_lines() -> list[str]:
    lines = ["language | coverage | n/a | missing source"]
    for language in languages():
        na = [
            theme
            for theme in ALIGNED_THEMES
            if language in NOT_APPLICABLE.get(theme, set())
        ]
        implemented = len(ALIGNED_THEMES) - len(na)
        note = ""
        if language == "go":
            note = " (root examples)"
        elif language == "octave":
            note = " (MATLAB fallback)"
        lines.append(
            f"{language} | {implemented}/{len(ALIGNED_THEMES)}{note} | "
            f"{', '.join(na) or '-'} | {', '.join(language_gaps(language)) or '-'}"
        )
    return lines


def missing() -> list[str]:
    failures = []
    for language in languages():
        for theme in THEMES:
            path = example_path(language, theme)
            if not (path / "README.md").is_file():
                failures.append(f"{language}/{theme}")
    return failures


def missing_aligned() -> list[str]:
    failures = []
    for language in languages():
        for theme in ALIGNED_THEMES:
            if language in NOT_APPLICABLE.get(theme, set()):
                continue
            path = example_path(language, theme)
            if not (path / "README.md").is_file():
                failures.append(f"{language}/{theme}")
    return failures


def missing_ci() -> list[str]:
    workflows = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted(WORKFLOWS.glob("ci*.yml"))
    )
    failures = []
    for theme, path in GO_THEMES.items():
        relative = path.relative_to(ROOT).as_posix()
        if relative not in workflows:
            failures.append(f"go/{theme}")
    return failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--report",
        action="store_true",
        help="print per-language aligned coverage and explicit n/a themes",
    )
    parser.add_argument(
        "--report-advanced",
        action="store_true",
        help="print per-language advanced example coverage without failing",
    )
    parser.add_argument(
        "--depth-report",
        action="store_true",
        help="print a source-level depth audit for the aligned example themes",
    )
    args = parser.parse_args(argv)
    if args.report:
        print("\n".join(report_lines()))
    if args.report_advanced:
        print("\n".join(advanced_report_lines()))
    if args.depth_report:
        print("\n".join(depth_report_lines()))
    failures = missing()
    if failures:
        print("missing examples: " + ", ".join(failures), file=sys.stderr)
        return 1
    failures = missing_aligned()
    if failures:
        print("missing aligned examples: " + ", ".join(failures), file=sys.stderr)
        return 1
    failures = missing_code()
    if failures:
        print("missing example source: " + ", ".join(failures), file=sys.stderr)
        return 1
    failures = missing_ci()
    if failures:
        print("missing example CI runs: " + ", ".join(failures), file=sys.stderr)
        return 1
    counts = {0: 0, 1: 0, 2: 0}
    for language in languages():
        count = sum(
            1
            for theme in ALIGNED_THEMES
            if language in NOT_APPLICABLE.get(theme, set())
        )
        counts[count] = counts.get(count, 0) + 1
    print(
        f"Example coverage ok: {len(languages())} languages; "
        f"{len(ALIGNED_THEMES)} themes; "
        f"{counts.get(0, 0)} full, {counts.get(1, 0)} with 1 n/a, "
        f"{counts.get(2, 0)} with 2 n/a; all resolved examples have source"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
