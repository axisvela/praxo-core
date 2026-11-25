import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent
CORE = ROOT.parent
BUILD = ROOT / "build" / "ebin"


def resolve(env_name, default):
    value = os.environ.get(env_name, default)
    found = shutil.which(value)
    if found:
        return found
    candidate = Path(value)
    if candidate.is_file():
        return str(candidate)
    return None


def main():
    erlc = resolve("ERLC", "erlc")
    erl = resolve("ERL", "erl")
    if not erlc:
        raise SystemExit("erlc not found; set ERLC or add Erlang to PATH")
    if not erl:
        sibling = Path(erlc).with_name("erl.exe" if os.name == "nt" else "erl")
        if sibling.is_file():
            erl = str(sibling)
    if not erl:
        raise SystemExit("erl not found; set ERL or add Erlang to PATH")

    BUILD.mkdir(parents=True, exist_ok=True)
    core_sources = sorted((CORE / "src").rglob("*.erl"))
    app_sources = sorted((ROOT / "src").glob("*.erl"))
    sources = [str(source) for source in core_sources + app_sources]
    subprocess.run(
        [erlc, "-I", str(CORE / "src"), "-I", str(ROOT / "src"), "-o", str(BUILD)]
        + sources,
        cwd=ROOT,
        check=True,
    )
    shutil.copyfile(ROOT / "src" / "praxo_ops.app.src", BUILD / "praxo_ops.app")
    subprocess.run(
        [
            erl,
            "-noshell",
            "-pa",
            str(BUILD),
            "-eval",
            "praxo_ops_tests:run().",
            "-s",
            "init",
            "stop",
        ],
        cwd=ROOT,
        check=True,
        timeout=120,
    )


if __name__ == "__main__":
    main()
