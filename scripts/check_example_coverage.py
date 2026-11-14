from __future__ import annotations

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
GO_THEMES = {
    "checkpoint": ROOT / "examples/recipes/checkpoint-store-go",
    "event-sink": ROOT / "examples/recipes/event-sinks-go",
    "retry": ROOT / "examples/recipes/retry-go",
    "provider-fallback": ROOT / "examples/recipes/provider-fallback-go",
    "streaming": ROOT / "examples/recipes/streaming-go",
    "structured-output": ROOT / "examples/recipes/structured-output-go",
    "identity-policy": ROOT / "examples/recipes/identity-go",
    "service": ROOT / "examples/embedded-service",
    "mcp": ROOT / "examples/ecosystem/mcp",
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
    return LANGUAGE / language / "examples" / theme


def missing() -> list[str]:
    failures = []
    for language in languages():
        for theme in THEMES:
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


def main() -> int:
    failures = missing()
    if failures:
        print("missing examples: " + ", ".join(failures), file=sys.stderr)
        return 1
    failures = missing_ci()
    if failures:
        print("missing example CI runs: " + ", ".join(failures), file=sys.stderr)
        return 1
    print(f"Example coverage ok: {len(languages())} languages x {len(THEMES)} themes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
