#!/usr/bin/env python3
"""Check that consumer starter pins match the recommended package map.

This is a static consistency check. It does not install packages, run tests, or
prove registry availability.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

GO_MOD = re.compile(r"require\s+github\.com/axisvela/praxo-core/v2\s+v(\d+\.\d+\.\d+)")
PY_REQ = re.compile(r"^praxo-core==(\d+\.\d+\.\d+)\s*$", re.MULTILINE)
POM_NS = {"m": "http://maven.apache.org/POM/4.0.0"}


def recommended(root: Path) -> dict[str, str]:
    data = json.loads(
        (root / "docs/getting-started/agent-integration.json").read_text(encoding="utf-8")
    )
    return {entry["language"]: entry["version"] for entry in data["languages"]}


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    try:
        expected = recommended(root)
    except (OSError, KeyError, json.JSONDecodeError) as error:
        return [f"agent-integration.json: {error}"]

    version = (root / "VERSION").read_text(encoding="utf-8").strip()
    if expected.get("Go") != version:
        errors.append(f"Go map {expected.get('Go')!r} != VERSION {version!r}")

    go_mod = (root / "examples/consumer-go/go.mod").read_text(encoding="utf-8")
    match = GO_MOD.search(go_mod)
    if match is None:
        errors.append("consumer-go/go.mod: missing praxo-core requirement")
    elif match.group(1) != version:
        errors.append(f"consumer-go/go.mod: {match.group(1)!r} != VERSION {version!r}")

    py_req = (root / "examples/consumer-python/requirements.txt").read_text(encoding="utf-8")
    match = PY_REQ.search(py_req)
    if match is None:
        errors.append("consumer-python/requirements.txt: missing praxo-core pin")
    elif match.group(1) != expected.get("Python"):
        errors.append(
            f"consumer-python: {match.group(1)!r} != map {expected.get('Python')!r}"
        )

    ts = json.loads(
        (root / "examples/consumer-typescript/package.json").read_text(encoding="utf-8")
    )
    ts_version = ts.get("dependencies", {}).get("@axisvela/praxo-core")
    if ts_version != expected.get("TypeScript"):
        errors.append(
            f"consumer-typescript: {ts_version!r} != map {expected.get('TypeScript')!r}"
        )

    pom = ET.parse(root / "examples/consumer-java/pom.xml").getroot()
    java_version = None
    for dependency in pom.findall(".//m:dependency", POM_NS):
        artifact = dependency.find("m:artifactId", POM_NS)
        if artifact is not None and artifact.text == "praxo-core":
            found = dependency.find("m:version", POM_NS)
            java_version = found.text if found is not None else None
            break
    if java_version != expected.get("Java"):
        errors.append(f"consumer-java: {java_version!r} != map {expected.get('Java')!r}")

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
        print("consumer pin check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("consumer pin check ok: starters match the package map")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
