from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
LANGUAGE = ROOT / "language"
EXCLUDED = {"matlab-octave-core"}


def workflow_names() -> list[Path]:
    return sorted(
        path for path in WORKFLOWS.glob("*.yml")
        if path.name.startswith("ci")
    )


def language_paths() -> list[str]:
    return sorted(
        path.name for path in LANGUAGE.iterdir()
        if path.is_dir() and path.name not in EXCLUDED
    )


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> int:
    paths = {path.name: text(path) for path in workflow_names()}
    ci = paths.get("ci.yml", "")
    ignored = set(re.findall(r'"language/([^/"]+)/\*\*"', ci))
    missing = []
    for language in language_paths():
        if language not in ignored:
            continue
        owned = any(
            name != "ci.yml" and f'"language/{language}/**"' in body
            for name, body in paths.items()
        )
        if not owned:
            missing.append(language)
    if missing:
        print("uncovered language workflows: " + ", ".join(missing), file=sys.stderr)
        return 1
    print(f"CI workflow coverage ok: {len(language_paths())} languages")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
