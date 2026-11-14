#!/usr/bin/env python3
"""Render the root README for dedicated language mirror repositories."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORGANIZATION = "axisvela"
REPO_PREFIX = "praxo-core-"
COMMUNITY_LINKS = (
    ("X", "https://x.com/axisvela"),
    ("Weibo", "https://weibo.com/u/1936025761"),
)
DEFAULT_SPEC_VERSION = "0.2.0"
METADATA_BULLET_PREFIXES = (
    "`spec_version`",
    "core version",
    "tier:",
    "license:",
    "dependencies:",
    "package:",
    "registry:",
    "published",
    "source version",
    "source tag",
    "implementation type:",
    "package version:",
    "toolchain:",
    "local gate:",
    "supported `spec_version`",
    "the latest source tag",
    "the latest nuget package",
    "the latest hex package",
    "the hex package",
    "linux and windows ci",
)
INSTALL_FENCES = {
    "python": "bash",
    "typescript": "bash",
    "rust": "bash",
    "csharp": "bash",
    "powershell": "powershell",
    "r": "r",
    "elixir": "elixir",
    "erlang": "erlang",
    "perl": "bash",
    "haskell": "bash",
    "dart": "bash",
    "octave": "bash",
    "go": "bash",
    "java": "text",
    "matlab": "text",
}


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def _intro(text: str) -> tuple[str, list[str]]:
    paragraphs: list[str] = []
    bullets: list[str] = []
    current: list[str] = []
    in_bullet = False
    for line in text.splitlines():
        if line.startswith("# "):
            continue
        if line.startswith("## "):
            break
        stripped = line.strip()
        if not stripped:
            if current:
                paragraph = " ".join(part.strip() for part in current).strip()
                if paragraph:
                    paragraphs.append(paragraph)
                current = []
            in_bullet = False
            continue
        if stripped.startswith(("- ", "* ")):
            if current:
                paragraph = " ".join(part.strip() for part in current).strip()
                if paragraph:
                    paragraphs.append(paragraph)
                current = []
            bullets.append(stripped)
            in_bullet = True
            continue
        if in_bullet and line[:1] in (" ", "\t"):
            bullets[-1] = f"{bullets[-1]} {stripped}"
            continue
        in_bullet = False
        current.append(stripped)
    if current:
        paragraph = " ".join(part.strip() for part in current).strip()
        if paragraph:
            paragraphs.append(paragraph)
    return (paragraphs[0] if paragraphs else ""), bullets


def _section(text: str, names: set[str]) -> str:
    lines = text.splitlines()
    start = None
    for index, line in enumerate(lines):
        if line.startswith("## ") and line[3:].strip().lower() in names:
            start = index + 1
            break
    if start is None:
        return ""
    end = len(lines)
    for index in range(start, len(lines)):
        if lines[index].startswith("## "):
            end = index
            break
    return "\n".join(lines[start:end]).strip()


def _first_code_block(text: str) -> str:
    match = re.search(r"```[^\n]*\n.*?```", text, re.DOTALL)
    return match.group(0) if match else ""


def _rewrite_links(text: str, key: str) -> str:
    replacements = (
        ("](../../spec/", "](spec/"),
        ("](../../docs/", f"](https://github.com/{ORGANIZATION}/praxo-core/blob/main/docs/"),
        ("](../../", f"](https://github.com/{ORGANIZATION}/praxo-core/blob/main/"),
        ("](examples/", f"](language/{key}/examples/"),
        ("](api/", f"](language/{key}/api/"),
        ("](REGISTRY.md)", f"](language/{key}/REGISTRY.md)"),
        ("](README.md)", f"](language/{key}/README.md)"),
        ("](CHANGELOG.md)", f"](language/{key}/CHANGELOG.md)"),
        ("](SETUP.md)", f"](language/{key}/SETUP.md)"),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def _example_description(path: Path) -> str:
    paragraphs: list[str] = []
    for line in _read(path / "README.md").splitlines():
        if line.startswith("# "):
            continue
        if line.startswith("## "):
            break
        stripped = line.strip()
        if not stripped or stripped.startswith(">") or stripped.startswith("```"):
            if paragraphs:
                break
            continue
        paragraphs.append(stripped)
    description = " ".join(paragraphs).strip()
    if len(description) > 180:
        description = description[:177].rstrip() + "..."
    return description


def _example_entries(root: Path, entry: dict) -> list[tuple[str, str, str]]:
    entries: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    explicit = entry.get("examples_dirs")
    if explicit:
        directories = [(source, root / source) for source in explicit]
    else:
        directories = [
            (source, root / source / "examples") for source in entry["source_dirs"]
        ]
    for source, directory in directories:
        if not directory.is_dir():
            continue
        for path in sorted(directory.iterdir(), key=lambda item: item.name.lower()):
            if not path.is_dir() or path.name in seen:
                continue
            seen.add(path.name)
            relative = (
                Path(source, path.name).as_posix()
                if explicit
                else Path(source, "examples", path.name).as_posix()
            )
            entries.append((path.name, relative, _example_description(path)))
    return entries


def _capabilities(root: Path, entry: dict) -> list[tuple[str, str, str]]:
    source = entry.get("capabilities_source") or str(Path(entry["dir"]) / "REGISTRY.md")
    section = _section(_read(root / source), {"capabilities and status"})
    rows: list[tuple[str, str, str]] = []
    for line in section.splitlines():
        if (
            not line.startswith("| ")
            or line.startswith("| Adapter")
            or line.startswith("| ---")
        ):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) >= 2:
            rows.append((cells[0], cells[1], cells[2] if len(cells) > 2 else ""))
    return rows


def _spec_version(root: Path) -> str:
    value = _read(root / "spec" / "SPEC_VERSION").strip()
    return value or DEFAULT_SPEC_VERSION


def _published(entry: dict) -> bool:
    return not (
        "source-only" in entry.get("status", "")
        or "shared implementation" in entry.get("status", "")
    )


def _feature_bullets(bullets: list[str]) -> list[str]:
    features: list[str] = []
    for bullet in bullets:
        body = bullet.lstrip("-* ").strip().lower()
        if not body:
            continue
        if any(body.startswith(prefix) for prefix in METADATA_BULLET_PREFIXES):
            continue
        features.append(bullet)
    return features


def _cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ").strip()


def _community() -> str:
    lines = ["## Community", ""]
    for name, link in COMMUNITY_LINKS:
        lines.append(f"- {name}: <{link}>")
    return "\n".join(lines)


def mirror_readme(entry: dict, has_examples: bool = False, root: Path = ROOT) -> str:
    key = entry["key"]
    is_go = key == "go"
    readme_source = entry.get("readme_source") or str(
        Path(entry["dir"]) / "README.md"
    )
    source_readme = _read(root / readme_source)
    positioning, bullets = _intro(source_readme)
    bullets = _feature_bullets(bullets)
    if entry.get("intro"):
        positioning = entry["intro"]
    if entry.get("highlights") and not bullets:
        bullets = list(entry["highlights"])
    if not positioning:
        positioning = (
            f"Dedicated repository for the {entry['name']} implementation of "
            "PRAXO-CORE: an embeddable, MIT-licensed agent execution kernel with "
            "policy controls, human-in-the-loop approval, checkpoints, events, "
            "and tool calling. It runs in-process and does not require a hosted "
            "service."
        )
    positioning = _rewrite_links(positioning, key)
    capabilities = _capabilities(root, entry)
    if not bullets:
        bullets = [
            f"- {name}: {status}"
            for name, status, _ in capabilities
            if status.strip().lower() != "not implemented"
        ]
    if not bullets:
        bullets = [
            "- In-process agent loop with tool registration and dispatch.",
            "- Policy hooks, approvals, checkpoints, and typed events.",
            "- Provider-neutral model adapters and MCP tool sessions where declared.",
            "- Shared conformance vectors and API gates for the declared scope.",
        ]
    quickstart = _section(
        source_readme, {"quickstart", "quick start", "usage", "run the checks"}
    )
    quickstart_code = _first_code_block(quickstart)
    verify_code = _first_code_block(
        _section(
            source_readme,
            {"build and test", "build and tests", "build and test.", "testing"},
        )
    )
    examples = _example_entries(root, entry) if has_examples else []
    published = _published(entry)
    registry = entry["registry"]
    if entry.get("url"):
        registry = f"[{registry}]({entry['url']})"
    install_label = "Install" if published else "Build"
    install_value = (
        f"`{entry['install']}`"
        if published
        else entry.get("source_install", entry["install"])
    )

    lines = [
        f"# PRAXO-CORE for {entry['name']}",
        "",
        positioning,
        "",
        "## At a glance",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| Package | `{entry['package']}` |",
        f"| Registry | {registry} |",
        f"| {install_label} | {install_value} |",
        f"| Source version | `{entry['source_version']}` |",
        f"| Published version | `{entry['published_version']}` |"
        if published
        else "| Published version | not published |",
    ]
    if entry.get("tag"):
        lines.append(f"| Source tag | `{entry['tag']}` |")
    if entry.get("tier"):
        lines.append(f"| Tier | {entry['tier']} |")
    lines.extend(
        [
            f"| Contract | `SPEC_VERSION` `{_spec_version(root)}` |",
            f"| Documentation | {entry['docs']} |",
            "| License | MIT |",
            "",
            "## Highlights",
            "",
            *bullets,
            "",
            "## Quick start",
            "",
        ]
    )
    if published:
        lines.extend(
            [
                "Install the published package:",
                "",
                f"```{INSTALL_FENCES.get(key, 'text')}",
                entry["install"],
                "```",
            ]
        )
    else:
        lines.extend(
            [
                "This implementation is source-only. Follow the build instructions "
                f"in [`language/{key}/README.md`](language/{key}/README.md).",
            ]
        )
    if quickstart_code:
        lines.extend(["", quickstart_code])
    if published or quickstart_code:
        lines.extend(
            [
                "",
                f"See the [full {entry['name']} README](language/{key}/README.md) for "
                "complete installation, build, and verification commands.",
            ]
        )
    if capabilities:
        lines.extend(
            [
                "",
                "## What's included",
                "",
                "| Capability | Status | Detail |",
                "| --- | --- | --- |",
            ]
        )
        for name, status, detail in capabilities:
            lines.append(
                f"| {_cell(name)} | {_cell(status)} | {_cell(detail)} |"
            )
    if examples:
        example_intro = (
            "Runnable examples live under [`examples`](examples) and "
            "[`language/go/examples`](language/go/examples)."
            if is_go
            else f"Runnable examples live under "
            f"[`language/{key}/examples`](language/{key}/examples)."
        )
        lines.extend(
            [
                "",
                "## Examples",
                "",
                example_intro,
                "",
                "| Example | What it shows |",
                "| --- | --- |",
            ]
        )
        for name, relative, description in examples:
            lines.append(
                f"| [{_cell(name)}]({relative}) | {_cell(description)} |"
            )
    else:
        example_url = (
            f"https://github.com/{ORGANIZATION}/praxo-core/tree/main/language/{key}/examples"
        )
        if key == "octave":
            example_url = (
                f"https://github.com/{ORGANIZATION}/praxo-core/tree/main/language/matlab/examples"
            )
        lines.extend(
            [
                "",
                "## Examples",
                "",
                f"See the canonical examples: {example_url}.",
            ]
        )
    lines.extend(["", "## Verify", ""])
    if verify_code:
        lines.extend(
            [
                f"Run the checks from `language/{key}`:",
                "",
                verify_code,
                "",
            ]
        )
    if is_go:
        lines.extend(
            [
                "Run the module checks from the mirror root:",
                "",
                "```bash",
                "go test ./...",
                "go vet ./...",
                "go build ./...",
                "```",
                "",
            ]
        )
    lines.append(
        f"This mirror contains the language source and the shared `spec/` vectors, "
        f"so the implementation can be built and tested here. See "
        f"[`language/{key}/README.md`](language/{key}/README.md) for the exact "
        "commands. The monorepo CI runs conformance, API snapshot, and native "
        "tests for this implementation."
    )
    if is_go:
        layout = [
            "- `pkg/`, `adapters/`, `cmd/`, `internal/` — Go module source",
            "- `examples/` — runnable Go and cross-language examples",
            "- `language/go/examples/` — published-package consumer and live-model examples",
            "- `spec/` — shared contract, vectors, and parity inventories",
            "- `LICENSE` — MIT license",
        ]
        canonical = (
            f"- Canonical source: https://github.com/{ORGANIZATION}/praxo-core"
        )
        registry_intro = "- Registry introduction: `REGISTRY.md`"
        machine_entry = "- Machine-readable entry: `llms.txt` and `llms.md`"
    else:
        layout = [
            f"- `language/{key}/` — implementation source, tests, API snapshot, "
            "and examples",
            "- `spec/` — shared contract, vectors, and parity inventories",
            "- `LICENSE` — MIT license",
        ]
        canonical = (
            f"- Canonical source: https://github.com/{ORGANIZATION}/praxo-core"
            f"/tree/main/language/{key}"
        )
        registry_intro = f"- Registry introduction: `language/{key}/REGISTRY.md`"
        machine_entry = (
            f"- Machine-readable entry: `language/{key}/llms.txt` and "
            f"`language/{key}/llms.md`"
        )
    lines.extend(
        [
            "",
            _community(),
            "",
            "## Repository layout",
            "",
            *layout,
            "",
            "## Canonical source",
            "",
            canonical,
            registry_intro,
            machine_entry,
            f"- Mirror repository: https://github.com/{ORGANIZATION}/{REPO_PREFIX}{key}",
            "- Release index: https://axisvela.github.io/praxo-core/languages/registry-status/",
            "",
            f"This repository is a discovery mirror of the canonical {entry['name']} "
            "source. The monorepo remains the source of truth and the release "
            "workflow source.",
            "",
            "PRAXO-CORE is not a hosted model, workflow engine, identity provider, "
            "or safety controller. Do not infer exactly-once execution, complete "
            "sandbox isolation, production security certification, live-provider "
            "behavior, or physical safety from this package.",
            "",
            "MIT licensed.",
            "",
        ]
    )
    return "\n".join(lines)
