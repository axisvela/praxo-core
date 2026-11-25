from pathlib import Path
import os
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve()
ROOT = HERE.parents[2]
BUILD = ROOT / "build" / "simulation-metrics"
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
    HERE.with_name("main.f90"),
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
executable = BUILD / "simulation_metrics"
link = ["-L", str(ROOT / "build" / "re2-install" / "lib"), "-lpraxo_re2"]
if os.name != "nt":
    origin = "@loader_path" if sys.platform == "darwin" else "$ORIGIN"
    link.append(f"-Wl,-rpath,{origin}/../re2-install/lib")
subprocess.run(
    [compiler, "-o", str(executable), *objects, *link],
    cwd=BUILD,
    check=True,
)
env = os.environ.copy()
runtime = ROOT / "build" / "re2-install" / "bin"
paths = [str(Path(compiler).parent)]
if runtime.is_dir():
    paths.append(str(runtime))
env["PATH"] = os.pathsep.join(paths + [env.get("PATH", "")])
subprocess.run([str(executable)], cwd=BUILD, env=env, check=True)
