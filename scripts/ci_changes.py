from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = sorted(
    path.name for path in (ROOT / "language").iterdir()
    if path.is_dir() and path.name != "matlab-octave-core"
)


def git_diff(base: str, head: str) -> list[str]:
    output = subprocess.check_output(
        ["git", "diff", "--name-only", f"{base}...{head}"],
        cwd=ROOT,
        text=True,
    )
    return [line for line in output.splitlines() if line]


def changed_files() -> list[str]:
    override = os.environ.get("CI_CHANGED_FILES")
    if override is not None:
        return [line for line in override.splitlines() if line]
    event = os.environ.get("EVENT_NAME", "")
    ref_type = os.environ.get("REF_TYPE", "")
    if event in {"schedule", "workflow_dispatch"} or ref_type == "tag":
        return []
    if event == "pull_request":
        base = os.environ.get("PR_BASE_SHA", "")
        head = os.environ.get("HEAD_SHA", "")
        if base and head:
            return git_diff(base, head)
    if event == "push":
        base = os.environ.get("PUSH_BEFORE", "")
        head = os.environ.get("HEAD_SHA", "")
        if base and set(base) != {"0"}:
            return git_diff(base, head)
        return git_diff(f"{head}^", head)
    return git_diff("HEAD^", "HEAD")


def main() -> int:
    event = os.environ.get("EVENT_NAME", "")
    ref_type = os.environ.get("REF_TYPE", "")
    full = event in {"schedule", "workflow_dispatch"} or ref_type == "tag"
    files = changed_files() if not full else []
    languages = set(LANGUAGES) if full else set()
    core = full
    docs = full
    examples = full
    consumers = full
    adapters = full

    for name in files:
        parts = name.split("/")
        if len(parts) > 1 and parts[0] == "language":
            language = parts[1]
            if language == "matlab-octave-core":
                languages.update({"matlab", "octave"})
            elif language in LANGUAGES:
                languages.add(language)
        if name.startswith("examples/consumer-"):
            consumers = True
        elif name.startswith("examples/"):
            examples = True
        if name.startswith("docs/") or name.endswith(".md"):
            docs = True
        if name.startswith(("spec/", "scripts/", ".github/")):
            full = True
            core = True
        if name.startswith(("pkg/", "internal/", "cmd/", "bindings/")):
            core = True
        if name.startswith("adapters/"):
            adapters = True
            core = True
        if name in {"go.mod", "go.sum", "VERSION", "Makefile"} or (
            name.endswith(".go")
            and not name.startswith(("language/", "examples/", "adapters/"))
        ):
            core = True

    if full:
        languages = set(LANGUAGES)
        core = docs = examples = consumers = adapters = True

    values = {
        "full": str(full).lower(),
        "core": str(core).lower(),
        "docs": str(docs).lower(),
        "examples": str(examples).lower(),
        "consumers": str(consumers).lower(),
        "adapters": str(adapters).lower(),
        "languages": json.dumps(sorted(languages), separators=(",", ":")),
    }
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as stream:
            for key, value in values.items():
                stream.write(f"{key}={value}\n")
    else:
        for key, value in values.items():
            print(f"{key}={value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
