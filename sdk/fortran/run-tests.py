import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

from conformance import generate


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default=os.environ.get("FC", "gfortran"))
    args = parser.parse_args()
    compiler = shutil.which(args.compiler)
    if not compiler:
        parser.error("Fortran compiler not found; set FC or pass --compiler")
    root = Path(__file__).resolve().parent
    build = root / "build"
    build.mkdir(exist_ok=True)
    subprocess.run([sys.executable, str(root / "api-snapshot.py"), "--check"], check=True)
    subprocess.run([sys.executable, str(root / "tests" / "tooling.py")], check=True)
    env = os.environ.copy()
    env["PATH"] = str(Path(compiler).resolve().parent) + os.pathsep + env["PATH"]
    sources = [root / "src" / f"praxo_{name}.f90"
               for name in ("types", "unicode", "json", "interfaces", "context", "pattern", "schema", "middleware",
                            "agent", "runtime", "checkpoint", "toolcall", "policy", "stream", "plugin")]
    sources.append(root / "tests" / "doubles.f90")
    fixtures = build / "fixtures.f90"
    generate(root, fixtures)
    suites = {"core-tests": root / "tests" / "run.f90", "json-tests": root / "tests" / "json.f90",
              "contract-tests": root / "tests" / "contracts.f90", "fixture-tests": fixtures}
    for name, main_source in suites.items():
        executable = build / (name + (".exe" if os.name == "nt" else ""))
        subprocess.run(
            [compiler, "-std=f2008", "-Wall", "-Wextra", "-Werror", "-fcheck=all",
             "-ffree-line-length-none", "-fbacktrace", "-g", "-J", str(build), "-o", str(executable),
             *map(str, sources), str(main_source)],
            cwd=build, env=env, check=True,
        )
        subprocess.run([str(executable)], cwd=root, env=env, check=True)


if __name__ == "__main__":
    main()
