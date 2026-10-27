import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default=os.environ.get("FPC", "fpc"))
    args = parser.parse_args()
    compiler = shutil.which(args.compiler)
    if not compiler:
        parser.error("Free Pascal compiler not found; set FPC or pass --compiler")
    subprocess.run([sys.executable, str(ROOT / "api-snapshot.py"), "--check"], check=True)
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    flags = ["-Mobjfpc", "-Scghi", "-O2", "-Fu."]
    subprocess.run([compiler, *flags, f"-FE{build}", "praxo.pas"], cwd=ROOT, check=True)
    subprocess.run([compiler, *flags, f"-FE{build}", "praxo_core.pas"], cwd=ROOT, check=True)
    subprocess.run([compiler, *flags, "-Futests", f"-FE{build}", "tests/praxo_tests.lpr"],
                   cwd=ROOT, check=True)
    executable = build / ("praxo_tests.exe" if os.name == "nt" else "praxo_tests")
    if not executable.is_file():
        executable = build / "praxo_tests"
    subprocess.run([str(executable), str(ROOT.parents[1] / "spec")], cwd=ROOT, check=True, timeout=120)
    subprocess.run([compiler, *flags, "-Futests", f"-FE{build}", "tests/agent_tests.lpr"],
                   cwd=ROOT, check=True)
    executable = build / ("agent_tests.exe" if os.name == "nt" else "agent_tests")
    subprocess.run([str(executable), str(ROOT.parents[1] / "spec")], cwd=ROOT, check=True, timeout=120)
    subprocess.run([compiler, *flags, "-Futests", f"-FE{build}", "tests/core_tests.lpr"],
                   cwd=ROOT, check=True)
    executable = build / ("core_tests.exe" if os.name == "nt" else "core_tests")
    subprocess.run([str(executable), str(ROOT.parents[1] / "spec")], cwd=ROOT, check=True, timeout=120)


if __name__ == "__main__":
    main()
