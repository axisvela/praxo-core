from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build" / "session-checkpoint-example"
BUILD.mkdir(parents=True, exist_ok=True)
sources = [
    ROOT / "src" / "praxo_types.f90",
    ROOT / "src" / "praxo_unicode.f90",
    ROOT / "src" / "praxo_interfaces.f90",
    ROOT / "src" / "praxo_json.f90",
    ROOT / "src" / "praxo_context.f90",
    ROOT / "src" / "praxo_stream.f90",
    ROOT / "src" / "praxo_pattern.f90",
    ROOT / "src" / "praxo_schema.f90",
    ROOT / "src" / "praxo_middleware.f90",
    ROOT / "src" / "praxo_agent.f90",
    ROOT / "src" / "praxo_checkpoint.f90",
    Path(__file__).with_name("checkpoint_example.f90"),
]
compiler = shutil.which("gfortran")
if not compiler:
    sys.exit("gfortran not found")
subprocess.run(
    [compiler, "-std=f2008", "-Wall", "-Wextra", "-Werror", "-fcheck=all",
     "-ffree-line-length-none", "-I", str(BUILD), "-J", str(BUILD), "-c",
     *[str(source) for source in sources]],
    cwd=BUILD,
    check=True,
)
objects = sorted(path.name for path in BUILD.glob("*.o"))
executable = BUILD / "session_checkpoint_example"
link = ["-L", str(ROOT / "build" / "re2-install" / "lib"), "-lpraxo_re2"]
subprocess.run(
    [compiler, "-o", str(executable), *objects, *link],
    cwd=BUILD,
    check=True,
)
subprocess.run([str(executable)], cwd=BUILD, check=True)
