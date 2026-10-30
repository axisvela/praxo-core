import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from conformance import generate_all


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
    subprocess.run([sys.executable, str(root / "api-snapshot.py"), "--check"],
                   check=True)
    subprocess.run([sys.executable, str(root / "tests" / "tooling.py")],
                   check=True)
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
    json_sources = [
        "src/json-parse.cob", "src/json-string.cob", "src/json-quote.cob",
        "src/json-generate.cob", "src/utf8.cob",
    ]
    group_sources = {
        "agent-loop": ["tests/agent-vector.cob", "src/agent.cob"],
        "checkpoint": ["src/checkpoint.cob", "src/slice.cob", *json_sources],
        "context": ["src/context.cob"],
        "event": ["src/event.cob"],
        "jsonschema": ["src/schema.cob", "src/schema-visit.cob",
                       "src/schema-scalar.cob", "src/pattern.cob",
                       "src/slice.cob", *json_sources],
        "memory": ["src/memory.cob"],
        "middleware": ["src/middleware.cob", "src/schema.cob",
                       "src/schema-visit.cob", "src/schema-scalar.cob",
                       "src/pattern.cob", "src/slice.cob", *json_sources],
        "plugin": ["src/plugin.cob", *json_sources],
        "policy": ["src/policy.cob", "src/path-normalize.cob"],
        "stream": ["src/stream.cob"],
        "toolcall": ["src/toolcall.cob", "src/slice.cob", *json_sources],
    }
    for group, destination, count in generate_all(root, build):
        executable = build / ("fixture_" + group.replace("-", "_") +
                              (".exe" if os.name == "nt" else ""))
        temp = tempfile.mkdtemp(prefix="cob-", dir=build)
        group_env = env.copy()
        group_env["TMP"] = temp
        group_env["TEMP"] = temp
        combined = build / f"combined_{group.replace('-', '_')}.cob"
        parts = [destination.read_text(encoding="utf-8")]
        for source in group_sources[group]:
            parts.append((root / source).read_text(encoding="utf-8"))
        combined.write_text("\n".join(parts), encoding="utf-8")
        subprocess.run(
            [compiler, "-x", "-free", "-debug", "-Wall", "-I", "copy", "-I", "tests",
             "-o", str(executable), str(combined)],
            cwd=root, env=group_env, check=True,
        )
        subprocess.run([str(executable)], cwd=root, env=env, check=True)
    suites = {
        "registry-tests": ["tests/registry.cob", "src/registry.cob"],
        "registry-agent-tests": ["tests/registry-agent.cob", "src/agent.cob", "src/registry.cob"],
        "core-tests": ["tests/run.cob", "src/agent.cob"],
        "json-tests": ["tests/json.cob", "src/json-parse.cob",
                       "src/json-string.cob", "src/json-quote.cob", "src/utf8.cob",
                       "src/json-generate.cob"],
        "contract-tests": ["tests/contracts.cob", "src/checkpoint.cob",
                           "src/context.cob", "src/event.cob", "src/memory.cob",
                           "src/middleware.cob", "src/path-normalize.cob",
                           "src/pattern.cob", "src/plugin.cob", "src/policy.cob",
                           "src/registry.cob", "src/schema.cob", "src/schema-visit.cob",
                           "src/schema-scalar.cob", "src/slice.cob",
                           "src/stream.cob", "src/toolcall.cob", *json_sources],
    }
    for name, sources in suites.items():
        executable = build / (name + (".exe" if os.name == "nt" else ""))
        combined = build / f"combined_{name}.cob"
        parts = [(root / sources[0]).read_text(encoding="utf-8")]
        for source in sources[1:]:
            parts.append((root / source).read_text(encoding="utf-8"))
        combined.write_text("\n".join(parts), encoding="utf-8")
        subprocess.run(
            [compiler, "-x", "-free", "-debug", "-Wall", "-I", "copy", "-I", "tests",
             "-o", str(executable), str(combined)],
            cwd=root, env=env, check=True,
        )
        subprocess.run([str(executable)], cwd=root, env=env, check=True)


if __name__ == "__main__":
    main()
