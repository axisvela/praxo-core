#!/usr/bin/env python3
"""Check registry-status page versions against registry metadata.

This is a structural consistency check: it does not verify that a registry page
is live or that an artifact installs. It prevents the status page and the
machine-readable manifest from drifting apart.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

DISPLAY_TO_KEY = {
    "Go": "Go",
    "Python": "Python",
    "TypeScript": "TypeScript",
    "Java": "Java",
    "Rust": "Rust",
    "C#": "C#",
    "Elixir": "Elixir",
    "Erlang": "Erlang",
    "Ruby": "Ruby",
    "Lua": "Lua",
    "PHP": "PHP",
}
ROW = re.compile(r"^\|\s*([^|]+?)\s*\|\s*[^|]*\|\s*`([^`]+)`\s*\|")


def status_versions(path: Path) -> dict[str, str]:
    versions: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = ROW.match(line)
        if match:
            versions[match.group(1).strip()] = match.group(2).strip()
    return versions


def normalize(language: str, version: str) -> str:
    return version.lstrip("v") if language == "Go" else version


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    metadata_path = root / "language/registry-metadata.json"
    status_path = root / "docs/languages/registry-status.md"
    version_path = root / "VERSION"
    for path in (metadata_path, status_path, version_path):
        if not path.is_file():
            errors.append(f"missing file: {path}")
    if errors:
        return errors

    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    versions = status_versions(status_path)
    for display, key in DISPLAY_TO_KEY.items():
        entry = metadata.get(key)
        if not isinstance(entry, dict):
            errors.append(f"registry-metadata.json: missing {key}")
            continue
        expected = entry.get("published_version")
        if not isinstance(expected, str) or not expected:
            errors.append(f"registry-metadata.json: {key}.published_version is empty")
            continue
        actual = versions.get(display)
        if actual is None:
            errors.append(f"registry-status.md: missing row for {display}")
            continue
        if normalize(display, actual) != normalize(display, expected):
            errors.append(
                f"{display}: registry-status {actual!r} != metadata {expected!r}"
            )

    version = version_path.read_text(encoding="utf-8").strip()
    go = metadata.get("Go", {})
    source = go.get("source_version") if isinstance(go, dict) else None
    if not isinstance(source, str) or normalize("Go", source) != version:
        errors.append(
            f"Go: metadata source_version {source!r} != VERSION {version!r}"
        )
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root (default: the script's parent repository)",
    )
    args = parser.parse_args(argv)
    errors = validate(args.root)
    if errors:
        print("registry state check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("registry state ok: status page matches registry metadata")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
