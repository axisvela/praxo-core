from pathlib import Path
import os
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
re2_lib = ROOT / "build" / "re2-install" / "lib"
re2_bin = ROOT / "build" / "re2-install" / "bin"
if not re2_lib.is_dir():
    sys.exit("RE2 bridge not found; run python language/fortran/run-tests.py --re2-only")
env = os.environ.copy()
if os.name == "nt":
    compiler_dir = str(Path(compiler).resolve().parent)
    env["PATH"] = compiler_dir + os.pathsep + str(re2_bin) + os.pathsep + str(re2_lib) + os.pathsep + env["PATH"]
else:
    variable = "DYLD_LIBRARY_PATH" if sys.platform == "darwin" else "LD_LIBRARY_PATH"
    env[variable] = str(re2_lib) + os.pathsep + env.get(variable, "")
subprocess.run(
    [compiler, "-I", str(BUILD), "-J", str(BUILD), "-c",
     *[str(source) for source in sources]],
    cwd=BUILD,
    env=env,
    check=True,
)
objects = sorted(path.name for path in BUILD.glob("*.o"))
executable = BUILD / "structured_output_example"
subprocess.run(
    [compiler, "-o", str(executable), *objects,
     f"-L{re2_lib}", "-lpraxo_re2"],
    cwd=BUILD,
    env=env,
    check=True,
)
subprocess.run([str(executable)], cwd=BUILD, env=env, check=True)
