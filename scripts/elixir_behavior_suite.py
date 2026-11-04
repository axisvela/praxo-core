from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LANGUAGE = ROOT / "language" / "elixir"
EBIN = LANGUAGE / "build" / "ebin"


def executable(name: str) -> list[str]:
    path = shutil.which(name)
    if path is None:
        raise SystemExit(f"executable not found: {name}")
    if os.name == "nt" and path.lower().endswith((".bat", ".cmd")):
        return ["cmd", "/c", path]
    return [path]


def main() -> int:
    EBIN.mkdir(parents=True, exist_ok=True)
    sources = sorted((LANGUAGE / "lib" / "praxo").glob("*.ex"))
    subprocess.run(
        [*executable("elixirc"), "-o", str(EBIN), *(str(path) for path in sources)],
        cwd=LANGUAGE,
        check=True,
    )
    subprocess.run(
        [*executable("elixir"), "-pa", str(EBIN), str(LANGUAGE / "tests" / "run_tests.exs")],
        cwd=ROOT,
        check=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
