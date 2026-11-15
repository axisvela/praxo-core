from pathlib import Path
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"
BUILD.mkdir(exist_ok=True)

main_source = Path(__file__).with_name("consumer_example.cob")
agent_source = ROOT / "src" / "agent.cob"
agent_object = BUILD / "consumer-agent.o"
compiler = shutil.which(os.environ.get("COBC", "cobc"))
if not compiler:
    sys.exit("GnuCOBOL compiler not found; set COBC")
executable = BUILD / ("consumer-example" + (".exe" if os.name == "nt" else ""))
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
subprocess.run(
    [compiler, "-c", "-free", "-I", "copy", "-o", str(agent_object),
     str(agent_source)],
    cwd=ROOT,
    env=env,
    check=True,
)
subprocess.run(
    [compiler, "-x", "-free", "-I", "copy", "-I", "examples/consumer",
     "-o", str(executable), str(main_source), str(agent_object)],
    cwd=ROOT,
    env=env,
    check=True,
)
subprocess.run([str(executable)], cwd=ROOT, env=env, check=True)
