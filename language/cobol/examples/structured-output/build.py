from pathlib import Path
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"
BUILD.mkdir(exist_ok=True)
objects_dir = BUILD / "structured-output-obj"
objects_dir.mkdir(exist_ok=True)
sources = [
    ROOT / "src" / "schema.cob",
    ROOT / "src" / "schema-visit.cob",
    ROOT / "src" / "schema-scalar.cob",
    ROOT / "src" / "pattern.cob",
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
objects = []
for source in sources:
    target = objects_dir / (source.stem + ".o")
    subprocess.run(
        [compiler, "-c", "-free", "-I", "copy", "-o", str(target), str(source)],
        cwd=ROOT,
        check=True,
    )
    objects.append(str(target))
executable = BUILD / ("structured-output-example" + (".exe" if os.name == "nt" else ""))
subprocess.run(
    [compiler, "-x", "-free", "-I", "copy", "-o", str(executable),
     str(Path(__file__).with_name("structured_output_example.cob")), *objects],
    cwd=ROOT,
    check=True,
)
subprocess.run([str(executable)], cwd=ROOT, check=True)
