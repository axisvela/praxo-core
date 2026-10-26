from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent

PUB_RE = re.compile(r"^pub (?:const|fn)\s+([A-Za-z_][A-Za-z0-9_]*)")


def snapshot() -> str:
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    spec = (REPO / "spec" / "SPEC_VERSION").read_text(encoding="utf-8").strip()
    entries: set[str] = set()
    for path in sorted((ROOT / "src").glob("*.zig")):
        if path.name == "conformance.zig":
            continue
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            match = PUB_RE.match(line)
            if match:
                entries.add(match.group(1))
    return "\n".join(
        [
            f"# PRAXO-CORE Zig API {version}",
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
