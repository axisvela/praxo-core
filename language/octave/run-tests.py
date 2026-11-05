import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--octave", default=os.environ.get("OCTAVE", "octave-cli"))
    args = parser.parse_args()
    executable = shutil.which(args.octave)
    if not executable:
        parser.error("Octave CLI not found; set OCTAVE or pass --octave")
    subprocess.run([sys.executable, str(ROOT / "api-snapshot.py"), "--check"], check=True)
    subprocess.run([executable, "--quiet", "--no-history", "--no-init-file", "--no-site-file",
                    "--eval", "addpath(pwd); run_tests"], cwd=ROOT, check=True, timeout=120)


if __name__ == "__main__":
    main()
