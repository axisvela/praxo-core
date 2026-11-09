#!/usr/bin/env python3
"""Check the registry-page audit table against registry metadata.

Structural only: it does not fetch or render the registry pages.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

PILOT = ("Go", "Python", "TypeScript", "Java")
ROW = re.compile(r"^\|\s*(Go|Python|TypeScript|Java)\s*\|[^|]*\|\s*`([^`]+)`\s*\|")


def page_versions(path: Path) -> dict[str, str]:
    versions: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = ROW.match(line)
        if match:
            versions[match.group(1)] = match.group(2).strip()
    return versions


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    metadata_path = root / "language/registry-metadata.json"
    pages_path = root / "docs/languages/registry-pages.md"
    for path in (metadata_path, pages_path):
        if not path.is_file():
            errors.append(f"missing file: {path}")
    if errors:
        return errors

    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    versions = page_versions(pages_path)
    for language in PILOT:
        entry = metadata.get(language)
        if not isinstance(entry, dict):
            errors.append(f"registry-metadata.json: missing {language}")
            continue
        expected = entry.get("published_version")
        actual = versions.get(language)
        if actual is None:
            errors.append(f"registry-pages.md: missing pilot row for {language}")
            continue
        if language == "Go":
            actual = actual.lstrip("v")
            expected = expected.lstrip("v") if isinstance(expected, str) else expected
        if actual != expected:
            errors.append(
                f"{language}: registry-pages {actual!r} != metadata {expected!r}"
            )

    text = pages_path.read_text(encoding="utf-8")
    for language in PILOT:
        if f"| {language} |" in text and "https://" not in text.split(f"| {language} |", 1)[1].split("\n", 1)[0]:
            errors.append(f"registry-pages.md: {language} row lacks an HTTPS link")
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
        print("registry page check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("registry page check ok: pilot rows match registry metadata")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
