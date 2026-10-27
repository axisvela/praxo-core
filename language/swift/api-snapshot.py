from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent

TYPE_RE = re.compile(
    r"^public\s+(?:final\s+)?(class|struct|enum|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)"
)
EXTENSION_RE = re.compile(r"^extension\s+([A-Za-z_][A-Za-z0-9_]*)")
MEMBER_RE = re.compile(
    r"^public\s+(?:(?:final|static|override|class)\s+)*"
    r"(func|var|let|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)"
)
INIT_RE = re.compile(r"^public\s+init\s*\(")


def snapshot() -> str:
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    spec = (REPO / "spec" / "SPEC_VERSION").read_text(encoding="utf-8").strip()
    entries: set[str] = set()
    for path in sorted((ROOT / "Sources" / "PraxoCore").glob("*.swift")):
        current = ""
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if line == "}":
                current = ""
                continue
            if line.startswith("//") or not line:
                continue
            match = TYPE_RE.match(line)
            if match:
                kind, name = match.groups()
                current = name
                entries.add(f"{kind} {name}")
                continue
            match = EXTENSION_RE.match(line)
            if match:
                current = match.group(1)
                continue
            match = MEMBER_RE.match(line)
            if match:
                kind, name = match.groups()
                entries.add(f"{current}.{name} {kind}" if current else f"{name} {kind}")
                continue
            if INIT_RE.match(line):
                entries.add(f"{current}.init" if current else "init")
    return "\n".join(
        [
            f"# PRAXO-CORE Swift API {version}",
            f"# SPEC_VERSION {spec}",
            "",
            *sorted(entries),
            "",
        ]
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    target = ROOT / "api" / f"{version}.txt"
    content = snapshot()
    if args.check:
        if not target.exists():
            print(f"missing snapshot: {target}", file=sys.stderr)
            return 1
        if target.read_text(encoding="utf-8") != content:
            print(f"snapshot is stale: {target}", file=sys.stderr)
            return 1
        print(f"snapshot is current: {target}")
        return 0
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8", newline="\n")
    print(f"wrote {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
