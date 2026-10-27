import argparse
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
SOURCES = [
    "PraxoJSON.m",
    "PraxoJsonSchema.m",
    "PraxoPlugin.m",
    "PraxoWire.m",
    "tests/main.m",
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default=os.environ.get("CLANG", "clang"))
    args = parser.parse_args()
    compiler = shutil.which(args.compiler)
    if not compiler:
        parser.error("clang not found; set CLANG or pass --compiler")
    subprocess.run([sys.executable, str(ROOT / "api-snapshot.py"), "--check"],
                   check=True)
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    executable = build / ("praxo_tests.exe" if os.name == "nt" else "praxo_tests")
    command = [compiler, "-fobjc-arc", "-I", str(ROOT), "-o", str(executable)]
    command.extend(str(ROOT / source) for source in SOURCES)
    if platform.system() == "Darwin":
        command.extend(["-framework", "Foundation"])
    else:
        command.extend([
            "-fobjc-runtime=gnustep-2.0",
            "-fuse-ld=lld",
            "-lgnustep-base",
            "-lobjc",
        ])
    environment = os.environ.copy()
    compiler_dir = str(Path(compiler).resolve().parent)
    environment["PATH"] = compiler_dir + os.pathsep + environment.get("PATH", "")
    subprocess.run(command, check=True, env=environment)
    subprocess.run([str(executable), str(REPO / "spec")],
                   cwd=ROOT, check=True, timeout=120, env=environment)


if __name__ == "__main__":
    main()
