import argparse
import difflib
from pathlib import Path
import re


def logical_lines(path):
    result, pending = [], ""
    for source in path.read_text(encoding="utf-8").splitlines():
        line = source.strip()
        if not line or line.startswith("!"):
            continue
        pending += (" " if pending else "") + line.lstrip("&").strip()
        if pending.endswith("&"):
            pending = pending[:-1].rstrip()
            continue
        result.append(re.sub(r"\s+", " ", pending))
        pending = ""
    if pending:
        raise ValueError(f"unterminated declaration: {path}")
    return result


def snapshot(root):
    output = ["Fortran API declaration inventory 0.2.1"]
    for source in sorted((root / "src").glob("*.f90")):
        lines = logical_lines(source)
        module = re.fullmatch(r"module (\w+)", lines[0], re.I).group(1)
        exports = set()
        for line in lines:
            match = re.fullmatch(r"public\s*::\s*(.*)", line, re.I)
            if match:
                exports.update(name.strip() for name in match.group(1).split(","))
        output += ["", f"module {module}", "public :: " + ", ".join(sorted(exports))]
        methods = set()
        for i, line in enumerate(lines):
            match = re.match(r"type(?:\s*,\s*[^:]+)?\s*::\s*(\w+)\s*$", line, re.I)
            if match and match.group(1) in exports:
                end = next(j for j in range(i + 1, len(lines)) if lines[j].lower() == "end type")
                output.extend(lines[i:end + 1])
                for binding in lines[i:end]:
                    match = re.match(r"procedure(?:\([^)]*\))?([^:]*)::\s*(\w+)(?:\s*=>\s*(\w+))?", binding, re.I)
                    if match and "private" not in match.group(1).lower():
                        methods.add(match.group(3) or match.group(2))
            if re.match(r"(?:character|integer|logical|real).*\bparameter\b", line, re.I):
                if any(re.search(r"\b" + re.escape(name) + r"\b", line.split("::")[-1]) for name in exports):
                    output.append(line)
            if line.lower() == "abstract interface":
                end = next(j for j in range(i + 1, len(lines)) if lines[j].lower() == "end interface")
                output.extend(lines[i:end + 1])
        requested = exports | methods
        for i, line in enumerate(lines):
            match = re.match(r"(?:(?:recursive|logical|integer|pure)\s+)*(?:subroutine|function)\s+(\w+)\s*\(([^)]*)\)(.*)", line, re.I)
            if not match or match.group(1) not in requested:
                continue
            output.append(line)
            result = re.search(r"result\((\w+)\)", match.group(3), re.I)
            for declaration in lines[i + 1:]:
                if "::" not in declaration:
                    break
                if "intent(" in declaration.lower() or (result and re.search(
                    r"\b" + re.escape(result.group(1)) + r"\b", declaration.split("::", 1)[1]
                )):
                    output.append(declaration)
            output.append("end interface declaration")
    return "\n".join(output) + "\n"


def main():
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--update", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    path = root / "api" / "0.2.1.txt"
    current = snapshot(root)
    if args.update:
        path.parent.mkdir(exist_ok=True)
        path.write_text(current, encoding="utf-8")
        return
    expected = path.read_text(encoding="utf-8") if path.exists() else ""
    if current != expected:
        print("".join(difflib.unified_diff(expected.splitlines(True), current.splitlines(True),
                                         fromfile=str(path), tofile="current API")))
        raise SystemExit("Fortran API snapshot mismatch")
    print("PASS: Fortran API declaration snapshot")


if __name__ == "__main__":
    main()
