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
    parser.add_argument("--cxx", default=os.environ.get("CXX"))
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
    sibling = Path(compiler).resolve().parent / ("g++.exe" if os.name == "nt" else "g++")
    cxx = args.cxx or (str(sibling) if sibling.is_file() else "c++")
    cxx = shutil.which(cxx)
    if not cxx:
        parser.error("C++17 compiler not found; set CXX or pass --cxx")
    for program in ("cmake", "ctest", "ninja", "git"):
        if not shutil.which(program):
            parser.error(f"{program} is required to build the pinned RE2 bridge")
    native = build / "re2"
    prefix = build / "re2-install"
    subprocess.run(
        ["cmake", "-S", str(root / "native"), "-B", str(native), "-G", "Ninja",
         "-DCMAKE_BUILD_TYPE=Release", f"-DCMAKE_CXX_COMPILER={cxx}"],
        env=env, check=True, timeout=900,
    )
    subprocess.run(["cmake", "--build", str(native), "--parallel", "4"],
                   env=env, check=True, timeout=900)
    subprocess.run(["ctest", "--test-dir", str(native), "--output-on-failure", "--timeout", "30"],
                   env=env, check=True, timeout=60)
    subprocess.run(["cmake", "--install", str(native), "--prefix", str(prefix)],
                   env=env, check=True, timeout=60)
    for dependency in ("re2", "abseil"):
        if not (prefix / "share/licenses/praxo-fortran-re2" / dependency / "LICENSE").is_file():
            raise RuntimeError(f"missing installed {dependency} license")
    env["PATH"] = str(prefix / "bin") + os.pathsep + env["PATH"]
    link = ["-L", str(prefix / "lib"), "-lpraxo_re2"]
    if os.name != "nt":
        origin = "@loader_path" if sys.platform == "darwin" else "$ORIGIN"
        link.append(f"-Wl,-rpath,{origin}/re2-install/lib")
    sources = [root / "src" / f"praxo_{name}.f90"
               for name in ("types", "unicode", "json", "interfaces", "context", "pattern", "schema", "middleware",
                            "agent", "runtime", "checkpoint", "toolcall", "policy", "stream", "plugin")]
    sources.append(root / "tests" / "doubles.f90")
    fixtures = build / "fixtures.f90"
    generate(root, fixtures)
    suites = {"core-tests": root / "tests" / "run.f90", "json-tests": root / "tests" / "json.f90",
              "contract-tests": root / "tests" / "contracts.f90", "fixture-tests": fixtures,
              "pattern-tests": root / "tests" / "pattern.f90"}
    for name, main_source in suites.items():
        executable = build / (name + (".exe" if os.name == "nt" else ""))
        subprocess.run(
            [compiler, "-std=f2008", "-Wall", "-Wextra", "-Werror", "-fcheck=all",
             "-ffree-line-length-none", "-fbacktrace", "-g", "-J", str(build), "-o", str(executable),
             *map(str, sources), str(main_source), *link],
            cwd=build, env=env, check=True,
        )
        subprocess.run([str(executable)], cwd=root, env=env, check=True, timeout=60)


if __name__ == "__main__":
    main()
