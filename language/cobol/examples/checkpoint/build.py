from pathlib import Path
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"
BUILD.mkdir(exist_ok=True)

parts = [
    Path(__file__).with_name("checkpoint_example.cob"),
    ROOT / "src" / "checkpoint.cob",
    ROOT / "src" / "slice.cob",
    ROOT / "src" / "json-parse.cob",
    ROOT / "src" / "json-string.cob",
    ROOT / "src" / "json-quote.cob",
    ROOT / "src" / "json-generate.cob",
    ROOT / "src" / "utf8.cob",
]
compiler = shutil.which(os.environ.get("COBC", "cobc"))
if not compiler:
    sys.exit("GnuCOBOL compiler not found; set COBC")
executable = BUILD / ("checkpoint-example" + (".exe" if os.name == "nt" else ""))
subprocess.run(
    [compiler, "-x", "-free", "-I", "copy", "-o", str(executable),
     *[str(part) for part in parts]],
    cwd=ROOT,
    check=True,
)
subprocess.run([str(executable)], cwd=ROOT, check=True)
