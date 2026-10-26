import argparse
import os
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default=os.environ.get("COBC", "cobc"))
    args = parser.parse_args()
    compiler = shutil.which(args.compiler)
    if not compiler:
        parser.error("GnuCOBOL compiler not found; set COBC or pass --compiler")
    root = Path(__file__).resolve().parent
    build = root / "build"
    build.mkdir(exist_ok=True)
    env = os.environ.copy()
    toolchain = Path(compiler).resolve().parent.parent
    if os.name == "nt":
        env["PATH"] = str(Path(compiler).parent) + os.pathsep + env["PATH"]
        if (toolchain / "config" / "default.conf").is_file():
            env.setdefault("COB_CONFIG_DIR", str(toolchain / "config"))
            env.setdefault("COB_COPY_DIR", str(toolchain / "copy"))
            for name, flag, directory in (
                ("COB_CFLAGS", "-I", "include"),
                ("COB_LDFLAGS", "-L", "lib"),
            ):
                env[name] = f'{flag}"{toolchain / directory}" ' + env.get(name, "")
    suites = {
        "core-tests": ["tests/run.cob", "src/agent.cob"],
        "json-tests": ["tests/json.cob", "src/json-parse.cob",
                       "src/json-string.cob", "src/json-quote.cob", "src/utf8.cob",
                       "src/json-generate.cob"],
    }
    for name, sources in suites.items():
        executable = build / (name + (".exe" if os.name == "nt" else ""))
        subprocess.run(
            [compiler, "-x", "-free", "-debug", "-Wall", "-I", "copy", "-I", "tests",
             "-o", str(executable), *sources],
            cwd=root, env=env, check=True,
        )
        subprocess.run([str(executable)], cwd=root, env=env, check=True)


if __name__ == "__main__":
    main()
