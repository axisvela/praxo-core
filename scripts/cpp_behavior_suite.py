from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "language" / "cpp" / "build"


def main() -> int:
    env = os.environ.copy()
    cache = BUILD / "CMakeCache.txt"
    if cache.is_file():
        for line in cache.read_text(encoding="utf-8").splitlines():
            if line.startswith("CMAKE_CXX_COMPILER:"):
                compiler = Path(line.split("=", 1)[1])
                if compiler.parent.is_dir():
                    env["PATH"] = str(compiler.parent) + os.pathsep + env.get("PATH", "")
                break
    command = ["ctest", "--test-dir", str(BUILD), "--output-on-failure"]
    return subprocess.run(command, cwd=ROOT, env=env).returncode


if __name__ == "__main__":
    raise SystemExit(main())
