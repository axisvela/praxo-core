from pathlib import Path
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"
BUILD.mkdir(exist_ok=True)
compiler = shutil.which(os.environ.get("COBC", "cobc"))
if not compiler:
    sys.exit("GnuCOBOL compiler not found; set COBC")
executable = BUILD / ("fallback-example" + (".exe" if os.name == "nt" else ""))
subprocess.run(
    [compiler, "-x", "-free", "-o", str(executable),
     str(Path(__file__).with_name("fallback_example.cob"))],
    cwd=ROOT,
    check=True,
)
subprocess.run([str(executable)], cwd=ROOT, check=True)
