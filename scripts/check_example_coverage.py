from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
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

GO_THEMES = {
    "consumer": ROOT / "language/go/examples/consumer-go",
    "live-model": ROOT / "language/go/examples/live-model",
    "checkpoint": ROOT / "examples/recipes/checkpoint-store-go",
    "event-sink": ROOT / "examples/recipes/event-sinks-go",
    "retry": ROOT / "examples/recipes/retry-go",
    "provider-fallback": ROOT / "examples/recipes/provider-fallback-go",
    "streaming": ROOT / "examples/recipes/streaming-go",
    "structured-output": ROOT / "examples/recipes/structured-output-go",
    "identity-policy": ROOT / "examples/recipes/identity-go",
    "service": ROOT / "examples/embedded-service",
    "mcp": ROOT / "examples/ecosystem/mcp",
    "hitl": ROOT / "examples/hitl",
    "session-checkpoint": ROOT / "examples/session-checkpoint",
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
    args = parser.parse_args(argv)
    if args.report:
        print("\n".join(report_lines()))
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
