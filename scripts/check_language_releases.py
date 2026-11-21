#!/usr/bin/env python3
"""Check language source tags against manifests, release notes, and docs.

The check is structural. It does not publish, push, or prove that a registry
contains a version. It prevents the language matrix, registry metadata, support
page, language manifests, source tags, and release notes from drifting apart.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

SEMVER = re.compile(r"\d+\.\d+\.\d+(?:-\d+)?")
TAG_VERSION = re.compile(r"/v(\d+\.\d+\.\d+(?:-\d+)?)$")
NOTE_SOURCE = re.compile(r"source `([^`]+)`")
README_VERSION = re.compile(r"(?:Core|Source) version: `([^`]+)`")
MATRIX_NAME_TO_KEY = {
    "Go": "Go",
    "Python": "Python",
    "TypeScript": "TypeScript",
    "Java": "Java",
    "Rust": "Rust",
    "C#": "C#",
    "C": "C",
    "C++": "C++",
    "PHP": "PHP",
    "Ruby": "Ruby",
    "Lua": "Lua",
    "Dart": "Dart",
    "Zig": "Zig",
    "D": "D",
    "Perl": "Perl",
    "PowerShell": "PowerShell",
    "Elixir": "Elixir",
    "Erlang": "Erlang",
    "Fortran": "Fortran",
    "COBOL": "COBOL",
    "Haskell": "Haskell",
    "Julia": "Julia",
    "MATLAB": "MATLAB",
    "Octave": "GNU Octave",
    "Nim": "Nim",
    "OCaml / Caml": "OCaml",
    "Objective-C": "Objective-C",
    "Swift": "Swift",
    "Delphi": "Delphi / Free Pascal",
    "V": "V",
    "R": "R",
}
FRESHNESS_NAME_TO_KEY = {
    "Python": "Python",
    "TypeScript": "TypeScript",
    "Java": "Java",
    "Rust": "Rust",
    "C#": "C#",
    "Elixir": "Elixir",
    "Erlang": "Erlang",
    "Ruby": "Ruby",
    "PHP": "PHP",
    "Lua": "Lua",
    "Dart": "Dart",
    "Julia": "Julia",
    "MATLAB": "MATLAB",
    "Octave": "GNU Octave",
    "Perl": "Perl",
    "PowerShell": "PowerShell",
    "Haskell": "Haskell",
    "R": "R",
    "Nim": "Nim",
    "OCaml": "OCaml",
    "Swift": "Swift",
    "Delphi / Free Pascal": "Delphi / Free Pascal",
    "D": "D",
}
PRIMARY_REGISTRY_KEYS = {"Go", "Python", "TypeScript", "Java", "Rust", "C#", "R"}
MANIFESTS = {
    "Go": ("VERSION", r"(?m)^(\S+)$"),
    "Python": ("language/python/pyproject.toml", r'(?m)^version\s*=\s*"([^"]+)"'),
    "TypeScript": ("language/typescript/package.json", r'"version"\s*:\s*"([^"]+)"'),
    "Java": ("language/java/pom.xml", r"<artifactId>praxo-core</artifactId>\s*<version>([^<]+)</version>"),
    "Rust": ("language/rust/Cargo.toml", r'(?m)^version\s*=\s*"([^"]+)"'),
    "C#": ("language/csharp/Praxo.Core/Praxo.Core.csproj", r"<Version>([^<]+)</Version>"),
    "Elixir": ("language/elixir/mix.exs", r'version:\s*"([^"]+)"'),
    "Erlang": ("language/erlang/src/praxo_core.app.src", r'\{vsn,\s*"([^"]+)"\}'),
    "Ruby": ("language/ruby/VERSION", r"(?m)^(\S+)$"),
    "PHP": ("language/php/composer.json", r'"version"\s*:\s*"([^"]+)"'),
    "Dart": ("language/dart/pubspec.yaml", r"(?m)^version:\s*(\S+)"),
    "Julia": ("language/julia/Project.toml", r'(?m)^version\s*=\s*"([^"]+)"'),
    "R": ("language/r/DESCRIPTION", r"(?m)^Version:\s*(\S+)"),
    "Perl": ("language/perl/lib/Praxo/Core.pm", r"\$VERSION\s*=\s*'([^']+)'"),
    "PowerShell": ("language/powershell/VERSION", r"(?m)^(\S+)$"),
    "Haskell": ("language/haskell/praxo-core.cabal", r"(?m)^version:\s*(\S+)"),
    "OCaml": ("language/ocaml/VERSION", r"(?m)^(\S+)$"),
    "Nim": ("language/nim/praxo_core.nimble", r'(?m)^version\s*=\s*"([^"]+)"'),
    "V": ("language/v/v.mod", r"version:\s*'([^']+)'"),
    "D": ("language/d/VERSION", r"(?m)^(\S+)$"),
    "C++": ("language/cpp/VERSION", r"(?m)^(\S+)$"),
    "Fortran": ("language/fortran/VERSION", r"(?m)^(\S+)$"),
    "COBOL": ("language/cobol/VERSION", r"(?m)^(\S+)$"),
    "Zig": ("language/zig/VERSION", r"(?m)^(\S+)$"),
    "Objective-C": ("language/objc/VERSION", r"(?m)^(\S+)$"),
    "Delphi / Free Pascal": ("language/delphi/VERSION", r"(?m)^(\S+)$"),
    "MATLAB": ("language/matlab/VERSION", r"(?m)^(\S+)$"),
    "GNU Octave": ("language/octave/VERSION", r"(?m)^(\S+)$"),
    "Swift": ("language/swift/VERSION", r"(?m)^(\S+)$"),
}


def _read(path: Path, errors: list[str]) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        errors.append(f"missing file: {path}")
        return ""


def _base_version(version: str) -> str:
    return re.sub(r"^v", "", version.strip()).split("-", 1)[0]


def _normalize(version: str) -> str:
    return re.sub(r"^v", "", version.strip())


def _git_tags(root: Path) -> set[str] | None:
    try:
        result = subprocess.run(
            ["git", "-C", str(root), "tag", "--list"],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    tags = {line.strip() for line in result.stdout.splitlines() if line.strip()}
    return tags or None


def _tag_parts(tag: str) -> list[str]:
    return [part.strip() for part in re.split(r"\s+and\s+", tag) if part.strip()]


def _check_metadata(root: Path, metadata: dict, tags: set[str] | None, errors: list[str]) -> None:
    for name, entry in metadata.items():
        if not isinstance(entry, dict):
            errors.append(f"registry-metadata.json: {name} must be an object")
            continue
        source = entry.get("source_version")
        tag = entry.get("tag", "")
        if not isinstance(source, str) or not source:
            errors.append(f"registry-metadata.json: {name}.source_version is empty")
            continue
        if not isinstance(tag, str):
            errors.append(f"registry-metadata.json: {name}.tag must be a string")
            continue
        for part in _tag_parts(tag):
            match = TAG_VERSION.search(part) or re.fullmatch(r"v(\d+\.\d+\.\d+(?:-\d+)?)", part)
            if match is None:
                errors.append(f"registry-metadata.json: {name}.tag has unexpected shape: {part!r}")
                continue
            if _base_version(match.group(1)) != _base_version(source):
                errors.append(
                    f"registry-metadata.json: {name}.tag version {match.group(1)!r} "
                    f"does not match source_version {source!r}"
                )
            if tags is not None and part not in tags:
                errors.append(f"registry-metadata.json: {name}.tag does not exist: {part!r}")
        manifest = MANIFESTS.get(name)
        if manifest is not None:
            relative, pattern = manifest
            text = _read(root / relative, errors)
            if text:
                match = re.search(pattern, text)
                if match is None:
                    errors.append(f"{relative}: could not read a version for {name}")
                elif _normalize(match.group(1)) != _normalize(source):
                    errors.append(
                        f"{relative}: manifest version {match.group(1)!r} "
                        f"does not match registry-metadata {source!r}"
                    )
        if name == "Lua":
            _check_lua_rockspec(root, source, errors)


def _check_lua_rockspec(root: Path, source: str, errors: list[str]) -> None:
    candidates = sorted((root / "language/lua").glob("praxo-core-*.rockspec"))
    for path in candidates:
        text = path.read_text(encoding="utf-8")
        match = re.search(r'(?m)^version\s*=\s*"([^"]+)"', text)
        if match is not None and _normalize(match.group(1)) == _normalize(source):
            return
    errors.append(
        "language/lua/*.rockspec: no rockspec declares "
        f"registry-metadata source_version {source!r}"
    )


def _changelog_path(root: Path, entry: dict) -> Path | None:
    relative = entry.get("dir")
    if not isinstance(relative, str) or not relative:
        return None
    directory = root / relative
    for name in ("CHANGELOG.md", "CHANGELOG"):
        path = directory / name
        if path.is_file():
            return path
    return None


def _check_release_notes(root: Path, metadata: dict, errors: list[str]) -> None:
    for name, entry in metadata.items():
        if not isinstance(entry, dict) or not entry.get("tag"):
            continue
        if entry.get("dir") == "language/matlab-octave-core":
            continue
        source = entry.get("source_version", "")
        if not isinstance(source, str) or not source:
            continue
        path = _changelog_path(root, entry)
        if path is None:
            errors.append(f"{name}: source tag {entry['tag']!r} has no CHANGELOG.md")
            continue
        text = path.read_text(encoding="utf-8")
        versions = [source]
        published = entry.get("published_version")
        if name in PRIMARY_REGISTRY_KEYS and isinstance(published, str) and published:
            versions.append(published)
        for version in dict.fromkeys(versions):
            escaped = re.escape(_base_version(version))
            if re.search(rf"(?m)^##\s*\[?{escaped}\]?(\s|$)", text) is None:
                label = "source" if version == source else "published"
                errors.append(f"{path}: missing release notes for {label} version {version!r}")


def _matrix_rows(path: Path, errors: list[str]) -> dict[str, tuple[str, str, str]]:
    text = _read(path, errors)
    if "## Matrix\n" not in text:
        errors.append(f"{path}: missing '## Matrix' section")
        return {}
    section = text.split("## Matrix\n", 1)[1].split("\n## ", 1)[0]
    rows: dict[str, tuple[str, str, str]] = {}
    for line in section.splitlines():
        if not line.startswith("| ") or line.startswith("| Language") or line.startswith("| ---"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 6:
            errors.append(f"{path}: invalid matrix row: {line}")
            continue
        name, _tier, status, tag, _maturity, notes = cells
        rows[name] = (status, tag.strip("`"), notes)
    return rows


def _check_matrix(root: Path, metadata: dict, errors: list[str]) -> None:
    path = root / "spec/languages.md"
    rows = _matrix_rows(path, errors)
    for display, key in MATRIX_NAME_TO_KEY.items():
        entry = metadata.get(key)
        if not isinstance(entry, dict) or display not in rows:
            continue
        status, tag, notes = rows[display]
        expected_tag = entry.get("tag", "")
        expected_status = "released" if expected_tag else "in progress"
        if status != expected_status:
            errors.append(f"{path}: {display} status is {status!r}, want {expected_status!r}")
        if expected_tag and tag != expected_tag:
            errors.append(f"{path}: {display} tag is {tag!r}, want {expected_tag!r}")
        if not expected_tag and tag != "none":
            errors.append(f"{path}: {display} tag is {tag!r}, want 'none' for an in-progress row")
        note_source = NOTE_SOURCE.search(notes)
        source = entry.get("source_version", "")
        if note_source is not None and isinstance(source, str) and source:
            if _normalize(note_source.group(1)) != _normalize(source):
                errors.append(
                    f"{path}: {display} note source version {note_source.group(1)!r} "
                    f"does not match registry-metadata {source!r}"
                )


def _check_support(root: Path, metadata: dict, errors: list[str]) -> None:
    path = root / "docs/languages/support.md"
    text = _read(path, errors)
    marker = "### Registry freshness against code"
    if marker not in text:
        return
    section = text.split(marker, 1)[1].split("\n### ", 1)[0]
    for line in section.splitlines():
        if not line.startswith("| ") or line.startswith("| Language") or line.startswith("| ---"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 4:
            continue
        display, code_cell, registry_cell, _status = cells
        key = FRESHNESS_NAME_TO_KEY.get(display)
        entry = metadata.get(key) if key else None
        if not isinstance(entry, dict):
            continue
        code_match = SEMVER.search(code_cell)
        if code_match is None:
            errors.append(f"{path}: {display} code column has no version")
        elif _normalize(code_match.group(0)) != _normalize(entry.get("source_version", "")):
            errors.append(
                f"{path}: {display} code version {code_match.group(0)!r} "
                f"does not match registry-metadata {entry.get('source_version')!r}"
            )
        registry_match = SEMVER.search(registry_cell)
        if registry_match is not None and _normalize(registry_match.group(0)) != _normalize(
            entry.get("published_version", "")
        ):
            errors.append(
                f"{path}: {display} registry version {registry_match.group(0)!r} "
                f"does not match registry-metadata {entry.get('published_version')!r}"
            )


def _check_language_readmes(root: Path, metadata: dict, errors: list[str]) -> None:
    for name, entry in metadata.items():
        if not isinstance(entry, dict):
            continue
        relative = entry.get("dir")
        if not isinstance(relative, str) or not relative or relative == ".":
            continue
        path = root / relative / "README.md"
        if not path.is_file():
            continue
        text = _read(path, errors)
        match = README_VERSION.search(text)
        if match is None:
            continue
        source = entry.get("source_version", "")
        if isinstance(source, str) and source and _normalize(match.group(1)) != _normalize(source):
            errors.append(
                f"{path}: README version {match.group(1)!r} "
                f"does not match registry-metadata {source!r}"
            )


def _registry_status_key(display: str) -> str | None:
    return MATRIX_NAME_TO_KEY.get(display) or FRESHNESS_NAME_TO_KEY.get(display)


def _check_registry_status(root: Path, metadata: dict, errors: list[str]) -> None:
    path = root / "docs/languages/registry-status.md"
    if not path.is_file():
        return
    text = _read(path, errors)
    marker = "## Source-only or not published to a registry"
    if marker not in text:
        errors.append(f"{path}: missing {marker!r} section")
        return
    section = text.split(marker, 1)[1].split("\n## ", 1)[0]
    for line in section.splitlines():
        if not line.startswith("| ") or line.startswith("| Language") or line.startswith("| ---"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 3:
            continue
        display, tag_cell, _state = cells
        key = _registry_status_key(display)
        entry = metadata.get(key) if key else None
        if not isinstance(entry, dict):
            continue
        expected = entry.get("tag")
        if not isinstance(expected, str) or not expected:
            continue
        tags = re.findall(r"`([^`]+)`", tag_cell)
        if expected not in tags:
            errors.append(
                f"{path}: {display} source tag {tag_cell!r} does not include {expected!r}"
            )


def validate(root: Path, check_tags: bool = True) -> list[str]:
    errors: list[str] = []
    metadata_path = root / "language/registry-metadata.json"
    raw = _read(metadata_path, errors)
    if not raw:
        return errors
    try:
        metadata = json.loads(raw)
    except json.JSONDecodeError as error:
        errors.append(f"{metadata_path}: invalid JSON: {error}")
        return errors
    if not isinstance(metadata, dict):
        errors.append(f"{metadata_path}: expected a JSON object")
        return errors
    tags = _git_tags(root) if check_tags else None
    _check_metadata(root, metadata, tags, errors)
    _check_release_notes(root, metadata, errors)
    _check_matrix(root, metadata, errors)
    _check_support(root, metadata, errors)
    _check_registry_status(root, metadata, errors)
    _check_language_readmes(root, metadata, errors)
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root (default: the script's parent repository)",
    )
    parser.add_argument(
        "--no-tags",
        action="store_true",
        help="skip git tag existence checks (for source archives without tags)",
    )
    args = parser.parse_args(argv)
    errors = validate(args.root, check_tags=not args.no_tags)
    if errors:
        print("language release check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("language release check ok: tags, manifests, release notes, matrix, and support page agree")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
