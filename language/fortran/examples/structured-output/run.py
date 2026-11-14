from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build" / "structured-output-example"
BUILD.mkdir(parents=True, exist_ok=True)
sources = [
    ROOT / "src" / "praxo_types.f90",
    ROOT / "src" / "praxo_unicode.f90",
    ROOT / "src" / "praxo_json.f90",
    ROOT / "src" / "praxo_pattern.f90",
    ROOT / "src" / "praxo_schema.f90",
    Path(__file__).with_name("structured_output_example.f90"),
]
compiler = shutil.which("gfortran")
if not compiler:
    sys.exit("gfortran not found")
subprocess.run(
    [compiler, "-I", str(BUILD), "-J", str(BUILD), "-c",
     *[str(source) for source in sources]],
    cwd=BUILD,
    check=True,
)
objects = sorted(path.name for path in BUILD.glob("*.o"))
executable = BUILD / "structured_output_example"
re2_lib = ROOT / "build" / "re2-install" / "lib"
subprocess.run(
    [compiler, "-o", str(executable), *objects,
     f"-L{re2_lib}", "-lpraxo_re2"],
    cwd=BUILD,
    check=True,
)
subprocess.run([str(executable)], cwd=BUILD, check=True)
