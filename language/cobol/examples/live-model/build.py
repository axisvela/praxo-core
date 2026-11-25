from pathlib import Path
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"
BUILD.mkdir(exist_ok=True)

main_source = Path(__file__).with_name("live_model_example.cob")
json_sources = [
    ROOT / "src" / "json-parse.cob",
    ROOT / "src" / "json-string.cob",
    ROOT / "src" / "json-quote.cob",
    ROOT / "src" / "json-generate.cob",
    ROOT / "src" / "utf8.cob",
]
modules = [ROOT / "src" / "agent.cob", ROOT / "src" / "openai.cob", *json_sources]
compiler = shutil.which(os.environ.get("COBC", "cobc"))
if not compiler:
    sys.exit("GnuCOBOL compiler not found; set COBC")

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

objects = []
for source in modules:
    destination = BUILD / ("live-model-" + source.stem + ".o")
    subprocess.run(
        [compiler, "-c", "-free", "-I", "copy", "-o", str(destination),
         str(source)],
        cwd=ROOT,
        env=env,
        check=True,
    )
    objects.append(str(destination))

executable = BUILD / ("live-model-example" + (".exe" if os.name == "nt" else ""))
subprocess.run(
    [compiler, "-x", "-free", "-I", "copy", "-I", "language/go/examples/live-model",
     "-o", str(executable), str(main_source), *objects],
    cwd=ROOT,
    env=env,
    check=True,
)
print(f"built {executable}")
