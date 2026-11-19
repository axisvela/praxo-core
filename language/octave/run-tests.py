import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent
CORE = ROOT.parent / "matlab-octave-core"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--octave", default=os.environ.get("OCTAVE", "octave-cli"))
    args = parser.parse_args()
    executable = shutil.which(args.octave)
    if not executable:
        parser.error("Octave CLI not found; set OCTAVE or pass --octave")
    subprocess.run([sys.executable, str(ROOT / "api-snapshot.py"), "--check"], check=True)
    subprocess.run([executable, "--quiet", "--no-history", "--no-init-file", "--no-site-file",
                    "--eval", "run_tests"], cwd=CORE, check=True, timeout=120)
    environment = os.environ.copy()
    environment["PRAXO_PYTHON"] = sys.executable
    subprocess.run([executable, "--quiet", "--no-history", "--no-init-file", "--no-site-file",
                    "--eval", "addpath('tests'); test_plugin_process"],
                   cwd=CORE, env=environment, check=True, timeout=30)


if __name__ == "__main__":
    main()
