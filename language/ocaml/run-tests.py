import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default=os.environ.get("OCAMLC", "ocamlc"))
    args = parser.parse_args()
    compiler = shutil.which(args.compiler)
    if not compiler:
        parser.error("OCaml compiler not found; set OCAMLC or pass --compiler")
    runtime = shutil.which("ocamlrun")
    if not runtime:
        candidate = Path(compiler).with_name("ocamlrun.exe" if os.name == "nt" else "ocamlrun")
        runtime = str(candidate) if candidate.is_file() else None
    if not runtime:
        parser.error("ocamlrun not found; install the OCaml runtime")
    subprocess.run([sys.executable, str(ROOT / "api-snapshot.py"), "--check"], check=True)
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    def build_path(name):
        return str(build / name)

    subprocess.run([compiler, "-g", "-c", "-o", build_path("praxo_core.cmi"),
                    "src/praxo_core.mli"], cwd=ROOT, check=True)
    modules = [
        "praxo_types", "praxo_json", "praxo_toolcall", "praxo_schema",
        "praxo_manifest", "praxo_message", "praxo_provider_util",
        "praxo_openai", "praxo_anthropic", "praxo_gemini", "praxo_plugin",
        "praxo_runtime", "praxo_middleware", "praxo_agent", "praxo_seams",
    ]
    for module in modules:
        subprocess.run([compiler, "-g", "-c", "-I", str(build), "-o",
                        build_path(module + ".cmo"), f"src/{module}.ml"],
                       cwd=ROOT, check=True)
    subprocess.run([compiler, "-g", "-c", "-I", str(build), "-o", build_path("praxo_core.cmo"),
                    "src/praxo_core.ml"], cwd=ROOT, check=True)
    subprocess.run([compiler, "-g", "-a", "-o", build_path("praxo_core.cma"), "-I", str(build)] +
                   [build_path(module + ".cmo") for module in modules] +
                   [build_path("praxo_core.cmo")],
                   cwd=ROOT, check=True)
    subprocess.run([compiler, "-g", "-c", "-I", str(build), "-o",
                    build_path("praxo_adapter_tests.cmo"),
                    "tests/praxo_adapter_tests.ml"], cwd=ROOT, check=True)
    subprocess.run([compiler, "-g", "-c", "-I", str(build), "-o",
                    build_path("praxo_tests.cmo"),
                    "tests/praxo_tests.ml"], cwd=ROOT, check=True)
    executable = build / ("praxo_tests.exe" if os.name == "nt" else "praxo_tests")
    plugin = build / ("process_plugin.exe" if os.name == "nt" else "process_plugin")
    subprocess.run([compiler, "-g", "-o", str(plugin), "-I", str(build),
                    "unix.cma"] + [build_path(module + ".cmo") for module in modules] +
                   [build_path("praxo_core.cmo"), "tests/process_plugin.ml"],
                   cwd=ROOT, check=True)
    subprocess.run([compiler, "-g", "-o", str(executable), "-I", str(build),
                    "unix.cma"] + [build_path(module + ".cmo") for module in modules] +
                   [build_path("praxo_core.cmo"),
                    build_path("praxo_adapter_tests.cmo"), build_path("praxo_tests.cmo")],
                   cwd=ROOT, check=True)
    subprocess.run([runtime, str(executable), str(ROOT.parents[1] / "spec"), str(plugin)],
                   cwd=ROOT, check=True, timeout=120)


if __name__ == "__main__":
    main()
