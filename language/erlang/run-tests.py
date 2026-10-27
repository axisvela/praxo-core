import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent


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

    subprocess.run([sys.executable, str(ROOT / "api-snapshot.py"), "--check"], check=True)

    build = ROOT / "build" / "ebin"
    build.mkdir(parents=True, exist_ok=True)
    sources = sorted((ROOT / "src").glob("*.erl"))
    sources += sorted((ROOT / "conformance").glob("*.erl"))
    sources += sorted((ROOT / "tests").glob("*.erl"))
    subprocess.run(
        [erlc, "-I", str(ROOT / "src"), "-o", str(build)] + [str(source) for source in sources],
        cwd=ROOT,
        check=True,
    )
    subprocess.run(
        [erl, "-noshell", "-pa", str(build), "-eval", "praxo_conformance:main().", "-s", "init", "stop"],
        cwd=ROOT,
        check=True,
        timeout=120,
    )
    subprocess.run(
        [erl, "-noshell", "-pa", str(build), "-eval", "praxo_tests:run().", "-s", "init", "stop"],
        cwd=ROOT,
        check=True,
        timeout=120,
    )


if __name__ == "__main__":
    main()
