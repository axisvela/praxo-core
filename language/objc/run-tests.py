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
    "src/PraxoJSON.m",
    "src/PraxoJsonSchema.m",
    "src/PraxoPlugin.m",
    "src/PraxoWire.m",
    "src/PraxoCore.m",
    "src/PraxoAgent.m",
    "src/PraxoHitl.m",
    "src/PraxoOpenAI.m",
    "src/PraxoAnthropic.m",
    "src/PraxoGemini.m",
    "src/PraxoHarmovela.m",
    "src/PraxoMCP.m",
    "src/PraxoOtel.m",
    "src/PraxoRetriever.m",
    "src/PraxoDelegation.m",
    "src/PraxoPluginProcess.m",
    "tests/main.m",
    "tests/correlation.m",
    "tests/middleware.m",
    "tests/openai.m",
    "tests/provider.m",
    "tests/harmovela.m",
    "tests/mcp.m",
    "tests/otel.m",
    "tests/retriever.m",
    "tests/delegation.m",
    "tests/session_checkpoint.m",
    "tests/hitl.m",
    "tests/plugin_process.m",
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
    command = [compiler, "-fobjc-arc", "-fblocks", "-I", str(ROOT / "src"), "-o", str(executable)]
    c_build = REPO / "language" / "c" / "build"
    if not (c_build / "libpraxo_core.a").is_file():
        raise SystemExit("build language/c first: cmake -S language/c -B language/c/build")
    command.extend(str(ROOT / source) for source in SOURCES)
    command.extend(["-I", str(REPO / "language" / "c" / "include"),
                    "-L", str(c_build), "-lpraxo_core"])
    if os.name == "nt":
        command.append("-lws2_32")
    if platform.system() == "Darwin":
        command.extend(["-framework", "Foundation"])
    else:
        command.extend([
            "-fobjc-runtime=gnustep-2.0",
            "-fuse-ld=lld",
            "-lgnustep-base",
            "-lobjc",
            "-lstdc++",
        ])
    environment = os.environ.copy()
    compiler_dir = str(Path(compiler).resolve().parent)
    environment["PATH"] = compiler_dir + os.pathsep + environment.get("PATH", "")
    subprocess.run(command, check=True, env=environment)
    subprocess.run([str(executable), str(REPO / "spec")],
                   cwd=ROOT, check=True, timeout=120, env=environment)


if __name__ == "__main__":
    main()
