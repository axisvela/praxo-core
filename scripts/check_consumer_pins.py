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
RUBY_GEM = re.compile(r"gem\s+['\"]praxo-core['\"]\s*,\s*['\"]([^'\"]+)['\"]")
ELIXIR_DEP = re.compile(r"\{:praxo_core,\s*\"~>\s*([0-9.]+)\"")
LUA_README = re.compile(r"LuaRocks\s+`praxo-core`\s+`([^`]+)`")
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

    py_req = (root / "language/python/examples/consumer/requirements.txt").read_text(encoding="utf-8")
    match = PY_REQ.search(py_req)
    if match is None:
        errors.append("consumer-python/requirements.txt: missing praxo-core pin")
    elif match.group(1) != expected.get("Python"):
        errors.append(
            f"consumer-python: {match.group(1)!r} != map {expected.get('Python')!r}"
        )

    ts = json.loads(
        (root / "language/typescript/examples/consumer/package.json").read_text(encoding="utf-8")
    )
    ts_version = ts.get("dependencies", {}).get("@axisvela/praxo-core")
    if ts_version != expected.get("TypeScript"):
        errors.append(
            f"consumer-typescript: {ts_version!r} != map {expected.get('TypeScript')!r}"
        )

    pom = ET.parse(root / "language/java/examples/consumer/pom.xml").getroot()
    java_version = None
    for dependency in pom.findall(".//m:dependency", POM_NS):
        artifact = dependency.find("m:artifactId", POM_NS)
        if artifact is not None and artifact.text == "praxo-core":
            found = dependency.find("m:version", POM_NS)
            java_version = found.text if found is not None else None
            break
    if java_version != expected.get("Java"):
        errors.append(f"consumer-java: {java_version!r} != map {expected.get('Java')!r}")

    gemfile = (root / "language/ruby/examples/consumer/Gemfile").read_text(encoding="utf-8")
    match = RUBY_GEM.search(gemfile)
    if match is None:
        errors.append("consumer-ruby/Gemfile: missing praxo-core pin")
    elif match.group(1) != expected.get("Ruby"):
        errors.append(f"consumer-ruby: {match.group(1)!r} != map {expected.get('Ruby')!r}")

    composer = json.loads(
        (root / "language/php/examples/consumer/composer.json").read_text(encoding="utf-8")
    )
    php_version = composer.get("require", {}).get("axisvela/praxo-core")
    if php_version != expected.get("PHP"):
        errors.append(f"consumer-php: {php_version!r} != map {expected.get('PHP')!r}")

    mix = (root / "language/elixir/examples/consumer/mix.exs").read_text(encoding="utf-8")
    match = ELIXIR_DEP.search(mix)
    if match is None:
        errors.append("consumer-elixir/mix.exs: missing praxo_core dependency")
    elif match.group(1) != expected.get("Elixir"):
        errors.append(f"consumer-elixir: {match.group(1)!r} != map {expected.get('Elixir')!r}")

    lua_readme = (root / "language/lua/examples/consumer/README.md").read_text(encoding="utf-8")
    match = LUA_README.search(lua_readme)
    if match is None:
        errors.append("consumer-lua/README.md: missing praxo-core version")
    elif match.group(1) != expected.get("Lua"):
        errors.append(f"consumer-lua: {match.group(1)!r} != map {expected.get('Lua')!r}")

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
