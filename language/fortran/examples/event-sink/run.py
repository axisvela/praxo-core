from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build" / "event-sink-example"
BUILD.mkdir(parents=True, exist_ok=True)
sources = [
    ROOT / "src" / "praxo_types.f90",
    ROOT / "src" / "praxo_interfaces.f90",
    ROOT / "src" / "praxo_runtime.f90",
    Path(__file__).with_name("event_sink_example.f90"),
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
executable = BUILD / "event_sink_example"
subprocess.run(
    [compiler, "-o", str(executable), *objects],
    cwd=BUILD,
    check=True,
)
subprocess.run([str(executable)], cwd=BUILD, check=True)
