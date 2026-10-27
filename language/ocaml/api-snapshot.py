import argparse
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]


def interface():
    text = (ROOT / "praxo.mli").read_text(encoding="utf-8")
    return text


def snapshot():
    spec = (REPO / "spec/SPEC_VERSION").read_text(encoding="utf-8").strip()
    text = interface()
    sdk = re.search(r'let sdk_version = "([^"]+)"', (ROOT / "praxo.ml").read_text(encoding="utf-8"))
    declared_spec = re.search(r'let spec_version = "([^"]+)"', (ROOT / "praxo.ml").read_text(encoding="utf-8"))
    if not sdk or not declared_spec or declared_spec[1] != spec:
        raise ValueError("OCaml SDK or contract version does not match specification")
    lines = ["# PRAXO-CORE OCaml Wire API " + sdk[1], "# SPEC_VERSION " + spec, ""]
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("val ") or line.startswith("type ") or line.startswith("exception "):
            lines.append(line)
    if len(lines) <= 3:
        raise ValueError("no public OCaml declarations found")
    return "\n".join(lines) + "\n"


def parity_errors():
    text = (REPO / "spec/parity/ocaml.md").read_text(encoding="utf-8")
    mli = interface()
    spec = (REPO / "spec/SPEC_VERSION").read_text(encoding="utf-8").strip()
    errors = []
    if "- SPEC_VERSION: " + spec not in text.splitlines():
        errors.append("contract version mismatch")
    rows = 0
    for line in text.splitlines():
        if not line.startswith("| `"):
            continue
        cells = line.split("|")
        symbol = cells[2].strip(" `")
        name = symbol.split(".")[-1]
        if not re.search(r"^val\s+" + re.escape(name) + r"\b", mli, re.MULTILINE):
            errors.append("missing parity value: " + symbol)
        rows += 1
    if rows == 0:
        errors.append("empty parity inventory")
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    target = ROOT / "api/unreleased.txt"
    content = snapshot()
    errors = parity_errors()
    if errors:
        raise ValueError("\n".join(errors))
    if args.check:
        if not target.is_file() or target.read_text(encoding="utf-8") != content:
            print("OCaml API snapshot is missing or stale", file=sys.stderr)
            return 1
        print("OCaml API snapshot and parity are current")
    else:
        target.parent.mkdir(exist_ok=True)
        target.write_text(content, encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
