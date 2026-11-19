import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default=os.environ.get("COBC", "cobc"))
    args = parser.parse_args()
    compiler = shutil.which(args.compiler)
    if not compiler:
        parser.error("GnuCOBOL compiler not found")
    root = Path(__file__).resolve().parents[1]
    repo = root.parents[1]
    toolchain = Path(compiler).resolve().parent.parent
    env = os.environ.copy()
    env["PATH"] = str(Path(compiler).parent) + os.pathsep + env.get("PATH", "")
    if os.name == "nt":
        env.setdefault("COB_CONFIG_DIR", str(toolchain / "config"))
        env.setdefault("COB_COPY_DIR", str(toolchain / "copy"))
        env["COB_CFLAGS"] = f'-I"{toolchain / "include"}"'
        env["COB_LDFLAGS"] = f'-L"{toolchain / "lib"}"'
    gcc = shutil.which("gcc", path=env["PATH"])
    if not gcc:
        parser.error("GCC matching GnuCOBOL is required")
    build = root / "build" / "plugin-process"
    build.mkdir(parents=True, exist_ok=True)
    c = repo / "language" / "c"
    objects = []
    for name in ("plugin_process", "json", "json_equals"):
        obj = build / f"{name}.o"
        subprocess.run([gcc, "-std=c11", "-I", str(c / "include"),
                        "-I", str(c / "src"), "-c", str(c / "src" / f"{name}.c"),
                        "-o", str(obj)], env=env, check=True, timeout=60)
        objects.append(str(obj))
    executable = build / ("test.exe" if os.name == "nt" else "test")
    subprocess.run([compiler, "-x", "-free", "-o", str(executable),
                    str(root / "tests" / "plugin_process.cob"), *objects,
                    *([] if os.name == "nt" else ["-lm"])],
                   env=env, check=True, timeout=60)
    env["PRAXO_PYTHON"] = sys.executable
    env["PRAXO_PLUGIN_FIXTURE"] = str(
        repo / "language" / "c" / "tests" / "fixtures" / "process_plugin.py")
    subprocess.run([str(executable)], env=env, check=True, timeout=30)


if __name__ == "__main__":
    main()
