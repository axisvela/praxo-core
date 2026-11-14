from pathlib import Path
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"
BUILD.mkdir(exist_ok=True)
sources = [
    Path(__file__).with_name("mcp_example.cob"),
    ROOT / "src" / "mcp.cob",
    ROOT / "src" / "json-parse.cob",
    ROOT / "src" / "json-string.cob",
    ROOT / "src" / "json-quote.cob",
    ROOT / "src" / "json-generate.cob",
    ROOT / "src" / "utf8.cob",
]
combined = BUILD / "combined_mcp_example.cob"
combined.write_text(
    "\n".join(source.read_text(encoding="utf-8") for source in sources),
    encoding="utf-8",
)
compiler = shutil.which(os.environ.get("COBC", "cobc"))
if not compiler:
    sys.exit("GnuCOBOL compiler not found; set COBC")
executable = BUILD / ("mcp-example" + (".exe" if os.name == "nt" else ""))
subprocess.run(
    [compiler, "-x", "-free", "-I", "copy", "-o", str(executable), str(combined)],
    cwd=ROOT,
    check=True,
)
subprocess.run([str(executable)], cwd=ROOT, check=True)
