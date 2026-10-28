from __future__ import annotations

import argparse
import difflib
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SPEC = ROOT.parent.parent / "spec" / "SPEC_VERSION"
TOKEN = re.compile(
    r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|'
    r'(?:\d|\.\d)(?:[eEpP][+-]|[\w.])*|\w+|'
    r'>>=|<<=|\.\.\.|->|\+\+|--|<<|>>|<=|>=|==|!=|&&|\|\||'
    r'\*=|/=|%=|\+=|-=|&=|\^=|\|=|##|<:|:>|<%|%>|%:|[^\s]', re.ASCII)
MARKER = re.compile(r'^#\s+\d+\s+"([^"]+)"')


def normalize(text: str) -> str:
    return " ".join(TOKEN.findall(text))


def compiler_path(compiler: str | None = None) -> str:
    if compiler:
        return compiler
    for name in ("clang", "gcc", "cc"):
        found = shutil.which(name)
        if found:
            return found
    raise ValueError("API snapshot requires GCC or Clang; pass --compiler PATH")


def snapshot(root: Path = ROOT, spec: Path = SPEC, compiler: str | None = None) -> tuple[str, str]:
    headers = sorted((root / "include").glob("*.h"))
    if not headers:
        raise ValueError("no public headers found")
    paths = {path.resolve(): path.name for path in headers}
    declarations = {path.name: [] for path in headers}
    macros = {path.name: [] for path in headers}
    includes = {}
    for path in headers:
        source = path.read_text(encoding="utf-8")
        includes[path.name] = re.findall(r'^\s*#\s*include\s*([<"][^>"\n]+[>"])', source, re.MULTILINE)
    command = [compiler_path(compiler), "-std=c11", "-x", "c", "-I", str(root / "include")]
    source = "\n".join(f'#include "{path.name}"' for path in headers) + "\n"
    for flags in (["-fsyntax-only"], ["-E", "-dD"]):
        result = subprocess.run(command + flags + ["-"], input=source, text=True,
                                capture_output=True, check=True, timeout=30)
    current = None
    for line in result.stdout.splitlines():
        marker = MARKER.match(line)
        if marker:
            current = paths.get(Path(marker.group(1).replace("\\\\", "\\")).resolve())
            continue
        if current is None or not line.strip():
            continue
        if line.startswith("#define "):
            body = line[len("#define "):]
            name = re.match(r"\w+", body).group()
            prefix = "function " if body[len(name):].startswith("(") else ""
            macros[current].append(prefix + normalize(body))
        elif line.startswith("#"):
            raise ValueError(f"unsupported public preprocessor directive: {line}")
        else:
            declarations[current].append(line)
    all_macros = "\n".join(value for values in macros.values() for value in values)
    versions = {}
    for name in ("PRAXO_SDK_VERSION", "PRAXO_SPEC_VERSION", "PRAXO_CORE_VERSION"):
        match = re.search(rf'^{name} "(\d+\.\d+\.\d+)"$', all_macros, re.MULTILINE)
        if not match:
            raise ValueError(f"missing or invalid {name}")
        versions[name] = match.group(1)
    if versions["PRAXO_SPEC_VERSION"] != spec.read_text(encoding="utf-8").strip():
        raise ValueError("PRAXO_SPEC_VERSION does not match spec/SPEC_VERSION")
    version = versions["PRAXO_SDK_VERSION"]
    if versions["PRAXO_CORE_VERSION"] != version:
        raise ValueError("PRAXO_CORE_VERSION does not match PRAXO_SDK_VERSION")
    output = [f"# PRAXO-CORE C API {version}",
              f'# SPEC_VERSION {versions["PRAXO_SPEC_VERSION"]}', "# Format 1: C11 preprocessed declaration tokens", ""]
    for name in declarations:
        output.append(f"## include/{name}")
        output.extend(f"include {include}" for include in includes[name])
        output.extend(f"define {macro}" for macro in macros[name])
        statement = []
        depth = 0
        for token in TOKEN.findall("\n".join(declarations[name])):
            statement.append(token)
            if token in ("{", "(", "["):
                depth += 1
            elif token in ("}", ")", "]"):
                depth -= 1
            if token == ";" and depth == 0:
                output.append(" ".join(statement))
                statement = []
        if statement or depth:
            raise ValueError(f"incomplete public declaration in {name}")
        output.append("")
    return version, "\n".join(output)


def main(argv: list[str] | None = None, root: Path = ROOT, spec: Path = SPEC) -> int:
    parser = argparse.ArgumentParser(description="Snapshot C11 public headers using GCC or Clang")
    parser.add_argument("--check", action="store_true", help="compare without writing files")
    parser.add_argument("--compiler", help="GCC or Clang executable path")
    args = parser.parse_args(argv)
    try:
        version, content = snapshot(root, spec, args.compiler)
        target = root / "api" / f"{version}.txt"
        if target.exists():
            previous = target.read_text(encoding="utf-8")
            if previous != content:
                sys.stderr.writelines(difflib.unified_diff(previous.splitlines(True), content.splitlines(True),
                                                          fromfile=str(target), tofile="current public headers"))
                raise ValueError("API snapshot differs; existing version baselines are immutable")
            print(f"snapshot is current: {target}")
        elif args.check:
            raise ValueError(f"missing snapshot: {target}")
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("x", encoding="utf-8", newline="\n") as stream:
                stream.write(content)
            print(f"wrote {target}")
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"C API snapshot failed: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError):
            print(error.stderr, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
