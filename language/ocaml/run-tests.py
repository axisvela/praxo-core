import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default=os.environ.get("OCAMLC", "ocamlc"))
    args = parser.parse_args()
    compiler = shutil.which(args.compiler)
    if not compiler:
        parser.error("OCaml compiler not found; set OCAMLC or pass --compiler")
    runtime = shutil.which("ocamlrun")
    if not runtime:
        candidate = Path(compiler).with_name("ocamlrun.exe" if os.name == "nt" else "ocamlrun")
        runtime = str(candidate) if candidate.is_file() else None
    if not runtime:
        parser.error("ocamlrun not found; install the OCaml runtime")
    subprocess.run([sys.executable, str(ROOT / "api-snapshot.py"), "--check"], check=True)
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    subprocess.run([compiler, "-g", "-c", "praxo.mli"], cwd=ROOT, check=True)
    subprocess.run([compiler, "-g", "-c", "praxo.ml"], cwd=ROOT, check=True)
    subprocess.run([compiler, "-g", "-c", "praxo_tests.ml"], cwd=ROOT, check=True)
    executable = build / ("praxo_tests.exe" if os.name == "nt" else "praxo_tests")
    subprocess.run([compiler, "-g", "-o", str(executable), "praxo.cmo", "praxo_tests.cmo"],
                   cwd=ROOT, check=True)
    subprocess.run([runtime, str(executable), str(ROOT.parents[1] / "spec")],
                   cwd=ROOT, check=True, timeout=120)


if __name__ == "__main__":
    main()
