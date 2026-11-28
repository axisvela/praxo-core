from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LANGUAGES = sorted(
    path.name for path in (ROOT / "language").iterdir()
    if path.is_dir() and path.name != "matlab-octave-core"
)
DOCS_SCRIPT_PREFIXES = (
    "scripts/discovery/",
    "scripts/checks/",
    "scripts/release/",
    "scripts/execution/",
    "scripts/metrics/",
    "scripts/validation/",
)
CI_SCRIPT_PREFIXES = ("scripts/ci/",)
LAB_SCRIPT_PREFIXES = ("scripts/labs/",)
LANGUAGE_SCRIPT_PREFIXES = {
    "scripts/languages/php/": "php",
    "scripts/languages/ocaml/": "ocaml",
    "scripts/consumers/go/": "go",
    "scripts/consumers/longrunning/": "go",
    "scripts/consumers/python/": "python",
    "scripts/consumers/java/": "java",
    "scripts/consumers/typescript/": "typescript",
}
DISCOVERY_INPUTS = {"language/discovery.json", "language/registry-metadata.json", "spec/languages.md"}
LANGUAGE_DOC_FILES = {"README.md", "README.zh-CN.md", "README.pod", "REGISTRY.md", "llms.md", "llms.txt",
                      "PUBLISHING.md", "CONTRIBUTING.md", "SECURITY.md", "LICENSE.md", "AGENTS.md"}
DOC_MARKDOWN_PATTERNS = [f"language/**/{name}" for name in sorted(LANGUAGE_DOC_FILES) if name.endswith(".md")]
DOC_MARKDOWN_PATTERNS += ["language/**/README*.md", "language/**/CHANGELOG*.md", "language/**/docs/**/*.md"]
LAB_LANGUAGES = {
    "compatibility": ("python", "typescript", "java", "rust", "fortran", "cobol"),
    "behavior": ("go", "python", "typescript", "java", "rust", "fortran", "cobol", "ruby",
                 "elixir", "erlang", "cpp", "php", "csharp", "lua", "r", "c"),
}


def git_diff(base: str, head: str) -> list[str]:
    revisions = [f"{base}...{head}"] if os.environ.get("EVENT_NAME") == "pull_request" else [base, head]
    output = subprocess.check_output(
        ["git", "diff", "--name-only", "--no-renames", "-z", *revisions],
        cwd=ROOT,
        text=True,
    )
    return [name for name in output.split("\0") if name]


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
    labs = full
    applications = set(LANGUAGES) if full else set()
    tutorials = set(LANGUAGES) if full else set()
    example_languages = set(LANGUAGES) if full else set()

    for name in files:
        parts = name.split("/")
        if name.startswith(DOCS_SCRIPT_PREFIXES) or name in DISCOVERY_INPUTS or (
            parts[0] == "language" and (parts[-1] in LANGUAGE_DOC_FILES or (
                name.endswith(".md") and (parts[-1].startswith(("README", "CHANGELOG")) or "docs" in parts[2:-1])))
        ):
            docs = True
            continue
        script_language = next((language for prefix, language in LANGUAGE_SCRIPT_PREFIXES.items()
                                if name.startswith(prefix)), None)
        if script_language:
            languages.add(script_language)
            continue
        if name.startswith(CI_SCRIPT_PREFIXES):
            docs = True
            continue
        if name.startswith(LAB_SCRIPT_PREFIXES):
            labs = True
            continue
        if name == "llms.txt":
            docs = True
        if len(parts) > 1 and parts[0] == "language":
            language = parts[1]
            if len(parts) > 2 and parts[2] == "application":
                applications.add(language)
            elif language == "matlab-octave-core":
                languages.update({"matlab", "octave"})
            elif language in LANGUAGES:
                languages.add(language)
                if len(parts) > 2 and parts[2] == "Tutorial":
                    tutorials.add(language)
                if len(parts) > 2 and parts[2] == "examples" and (
                    len(parts) < 4 or parts[3] != "consumer"
                ):
                    example_languages.add(language)
        if name.startswith(("language/go/examples/consumer-", "language/go/examples/consumer-go/")):
            consumers = True
        elif name.startswith(("language/go/examples/", "language/go/examples/live-model/")):
            examples = True
            example_languages.add("go")
        if name.startswith("docs/") or name.endswith(".md"):
            docs = True
        if name.startswith(("spec/", "scripts/", ".github/actions/")) or name == os.environ.get("WORKFLOW_FILE"):
            full = True
            core = True
        if name.startswith(("pkg/", "internal/", "cmd/", "bindings/", "api/", "benchmarks/", "tests/")):
            core = True
        if name.startswith("adapters/"):
            adapters = True
            core = True
        if name == "global.json":
            languages.add("csharp")
        if name in {"go.mod", "go.sum", "VERSION", "Makefile"} or (
            name.endswith(".go")
            and not name.startswith(("language/", "language/go/examples/", "adapters/"))
        ):
            core = True

    if full:
        languages = set(LANGUAGES)
        applications = set(LANGUAGES)
        tutorials = set(LANGUAGES)
        example_languages = set(LANGUAGES)
        core = docs = examples = consumers = adapters = labs = True

    dependencies = {
        "c": {"cpp", "objc", "fortran", "cobol", "nim", "opencl"},
        "java": {"kotlin", "scala", "groovy", "clojure"},
        "typescript": {"javascript"},
        "csharp": {"powershell", "fsharp"},
    }
    for language in list(languages):
        languages.update(dependencies.get(language, set()))
    if core:
        examples = consumers = adapters = labs = True
        applications.add("go")

    values = {
        "full": str(full).lower(),
        "core": str(core).lower(),
        "docs": str(docs).lower(),
        "examples": str(examples).lower(),
        "consumers": str(consumers).lower(),
        "adapters": str(adapters).lower(),
        "labs": str(labs).lower(),
        "languages": json.dumps(sorted(languages), separators=(",", ":")),
        "applications": json.dumps(sorted(applications), separators=(",", ":")),
        "tutorials": json.dumps(sorted(tutorials), separators=(",", ":")),
        "example_languages": json.dumps(sorted(example_languages), separators=(",", ":")),
    }
    selected = languages | ({"go"} if core else set())
    for lab, available in LAB_LANGUAGES.items():
        chosen = available if full or (labs and not selected) else selected
        values[f"{lab}_languages"] = json.dumps(
            [language for language in available if language in chosen], separators=(",", ":"))
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
