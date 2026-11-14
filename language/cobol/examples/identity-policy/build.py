from pathlib import Path
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"
BUILD.mkdir(exist_ok=True)
sources = [
    Path(__file__).with_name("identity_policy_example.cob"),
    ROOT / "src" / "policy.cob",
    ROOT / "src" / "path-normalize.cob",
]
compiler = shutil.which(os.environ.get("COBC", "cobc"))
if not compiler:
    sys.exit("GnuCOBOL compiler not found; set COBC")
executable = BUILD / ("identity-policy-example" + (".exe" if os.name == "nt" else ""))
subprocess.run(
    [compiler, "-x", "-free", "-I", "copy", "-o", str(executable),
     *[str(source) for source in sources]],
    cwd=ROOT,
    check=True,
)
subprocess.run([str(executable)], cwd=ROOT, check=True)
