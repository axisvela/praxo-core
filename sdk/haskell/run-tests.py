import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default=os.environ.get("GHC", "ghc"))
    args = parser.parse_args()
    compiler = shutil.which(args.compiler)
    if not compiler:
        parser.error("Haskell compiler not found; set GHC or pass --compiler")
    subprocess.run([sys.executable, str(ROOT / "api-snapshot.py"), "--check"], check=True)
    for suite in ("tests", "conformance"):
        output = ROOT / "build" / suite
        output.mkdir(parents=True, exist_ok=True)
        binary = output / ("run.exe" if os.name == "nt" else "run")
        subprocess.run([compiler, "--make", "-Wall", "-isrc", "-outputdir", str(output),
                        "-o", str(binary), suite + "/Main.hs"], cwd=ROOT, check=True)
        command = [str(binary)]
        if suite == "conformance":
            command.append(str(ROOT.parents[1] / "spec"))
        subprocess.run(command, cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
