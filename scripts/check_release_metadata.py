#!/usr/bin/env python3
"""Check canonical release metadata consistency.

The check is structural: it does not publish, tag, or prove that CI passed for the
current revision. It only prevents documentation and version files from drifting
apart before a release decision.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SEMVER = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
REVISION_ROW = re.compile(r"^\|\s*Revision\s*\|\s*`([0-9a-f]{40})`\s*\|", re.MULTILINE)
RELEASE_ROW = re.compile(r"^\|\s*(\d+\.\d+\.\d+)\s*\|", re.MULTILINE)


def _read(path: Path, errors: list[str]) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        errors.append(f"missing file: {path}")
        return ""


def _check_version(root: Path, errors: list[str]) -> tuple[str, int | None]:
    version = _read(root / "VERSION", errors).strip()
    if not version:
        errors.append("VERSION: empty")
        return version, None
    match = SEMVER.fullmatch(version)
    if match is None:
        errors.append(f"VERSION: expected plain X.Y.Z without a pre-release suffix, got {version!r}")
        return version, None
    return version, int(match.group(1))


def _check_release_files(root: Path, version: str, errors: list[str]) -> None:
    for relative, label in (
        (f"api/{version}.txt", "API snapshot"),
        (f"docs/releases/{version}.md", "English release notes"),
        (f"docs/zh-CN/releases/{version}.md", "zh-CN release notes"),
    ):
        text = _read(root / relative, errors)
        if not text.strip():
            errors.append(f"{label}: empty or missing at {relative}")
        elif relative.startswith("docs/") and not text.lstrip().startswith(f"# PRAXO-CORE {version}"):
            errors.append(f"{label}: title must start with '# PRAXO-CORE {version}'")

    changelog = _read(root / "CHANGELOG.md", errors)
    if f"## [{version}]" not in changelog:
        errors.append(f"CHANGELOG.md: missing '## [{version}]' section")


def _check_release_indexes(root: Path, version: str, errors: list[str]) -> None:
    for relative, marker in (
        ("docs/releases/index.md", f"Core `{version}` is the current framework release."),
        ("docs/zh-CN/releases/index.md", f"当前框架核心版本为 `{version}`"),
    ):
        text = _read(root / relative, errors)
        if marker not in text:
            errors.append(f"{relative}: missing current-version marker for {version}")
        rows = RELEASE_ROW.findall(text)
        if not rows:
            errors.append(f"{relative}: missing release table")
        elif rows[0] != version:
            errors.append(f"{relative}: first release row is {rows[0]}, want {version}")
        if f"]({version}.md)" not in text:
            errors.append(f"{relative}: missing release-note link for {version}")


def _check_module(root: Path, major: int | None, errors: list[str]) -> None:
    go_mod = _read(root / "go.mod", errors)
    module = ""
    for line in go_mod.splitlines():
        if line.startswith("module "):
            module = line.split()[1]
            break
    if not module:
        errors.append("go.mod: missing module line")
        return
    if major is None:
        return
    if major >= 2:
        if not module.endswith(f"/v{major}"):
            errors.append(f"go.mod: module {module!r} must end with /v{major}")
    elif re.search(r"/v\d+$", module):
        errors.append(f"go.mod: module {module!r} must not carry a /vN suffix before v2")


def _check_agent_map(root: Path, version: str, errors: list[str]) -> None:
    spec_version = _read(root / "spec/SPEC_VERSION", errors).strip()
    if not SEMVER.fullmatch(spec_version):
        errors.append(f"spec/SPEC_VERSION: expected plain X.Y.Z, got {spec_version!r}")
    raw = _read(root / "docs/getting-started/agent-integration.json", errors)
    if not raw:
        return
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as error:
        errors.append(f"docs/getting-started/agent-integration.json: invalid JSON: {error}")
        return
    if data.get("specVersion") != spec_version:
        errors.append(
            "docs/getting-started/agent-integration.json: specVersion "
            f"{data.get('specVersion')!r} does not match {spec_version!r}"
        )
    entries = data.get("languages")
    if not isinstance(entries, list):
        errors.append("docs/getting-started/agent-integration.json: languages must be a list")
        return
    go_entry = next((entry for entry in entries if isinstance(entry, dict) and entry.get("language") == "Go"), None)
    if go_entry is None:
        errors.append("docs/getting-started/agent-integration.json: missing Go entry")
    elif go_entry.get("version") != version:
        errors.append(
            "docs/getting-started/agent-integration.json: Go version "
            f"{go_entry.get('version')!r} does not match VERSION {version!r}"
        )


def _check_public_entry_points(root: Path, version: str, errors: list[str]) -> None:
    for relative in ("README.md", "docs/index.md", "docs/zh-CN/index.md"):
        text = _read(root / relative, errors)
        if f"@v{version}" not in text:
            errors.append(f"{relative}: missing install reference @v{version}")
        if f"releases/{version}.md" not in text:
            errors.append(f"{relative}: missing release-note link for {version}")


def _check_evidence_labels(root: Path, errors: list[str]) -> None:
    for relative in ("docs/project/verification-evidence.md", "docs/zh-CN/project/verification-evidence.md"):
        text = _read(root / relative, errors)
        lowered = text.lower()
        if "current ci behavior job" in lowered or "当前 CI behavior job" in text:
            errors.append(f"{relative}: a recorded CI run must not be labeled current")
    for relative in ("docs/languages/behavior-lab-matrix.md", "docs/zh-CN/languages/behavior-lab-matrix.md"):
        text = _read(root / relative, errors)
        if REVISION_ROW.search(text) is None:
            errors.append(f"{relative}: missing a full 40-character Revision row")


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    version, major = _check_version(root, errors)
    if version:
        _check_release_files(root, version, errors)
        _check_release_indexes(root, version, errors)
        _check_agent_map(root, version, errors)
        _check_public_entry_points(root, version, errors)
    _check_module(root, major, errors)
    _check_evidence_labels(root, errors)
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
        print("release metadata check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    version = (args.root / "VERSION").read_text(encoding="utf-8").strip()
    print(f"release metadata ok: {version} (snapshot, notes, changelog, indexes, module, agent map)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
