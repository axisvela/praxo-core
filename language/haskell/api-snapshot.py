import argparse
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parent


def snapshot():
    wire = (ROOT / "src/Praxo/Wire.hs").read_text(encoding="utf-8")
    sdk = re.search(r'^sdkVersion = "([^"]+)"$', wire, re.MULTILINE)[1]
    spec = re.search(r'^specVersion = "([^"]+)"$', wire, re.MULTILINE)[1]
    entries = ["# PRAXO-CORE Haskell Wire API " + sdk, "# SPEC_VERSION " + spec, ""]
    for path in sorted((ROOT / "src/Praxo").glob("*.hs")):
        text = path.read_text(encoding="utf-8")
        header = re.search(r"^module (\S+)\s+\((.*?)\)\s+where$", text, re.MULTILINE | re.DOTALL)
        if not header:
            raise ValueError("missing explicit exports: " + str(path))
        module = header[1]
        exports = header[2].replace("(..)", "").split(",")
        entries.append("## " + module)
        for name in sorted(export.strip() for export in exports):
            pattern = r"^(?:(?:data|newtype) " + re.escape(name) + r"\b.*|" + re.escape(name) + r" :: .*)$"
            declaration = re.search(pattern, text, re.MULTILINE)
            if not declaration:
                raise ValueError("missing declaration: " + module + "." + name)
            entries.append(declaration[0])
        entries.append("")
    return "\n".join(entries)


def parity_errors():
    repository = ROOT.parents[1]
    wire = (ROOT / "src/Praxo/Wire.hs").read_text(encoding="utf-8")
    spec = (repository / "spec/SPEC_VERSION").read_text(encoding="utf-8").strip()
    errors = []
    if f'specVersion = "{spec}"' not in wire:
        errors.append("Haskell contract version does not match spec/SPEC_VERSION")
    version = re.search(r'^version:\s*(\S+)', (ROOT / "praxo-core.cabal").read_text(encoding="utf-8"), re.MULTILINE)[1]
    if f'sdkVersion = "{version}"' not in wire:
        errors.append("Haskell SDK version does not match Cabal metadata")
    text = (repository / "spec/parity/haskell.md").read_text(encoding="utf-8")
    rows = 0
    for line in text.splitlines():
        if not line.startswith("| `"):
            continue
        cells = line.split("|")
        symbol = cells[2].strip(" `")
        module, name = symbol.rsplit(".", 1)
        path = ROOT / "src" / (module.replace(".", "/") + ".hs")
        if not path.is_file():
            errors.append("missing parity module: " + module)
            continue
        header = re.search(r"^module \S+\s+\((.*?)\)\s+where$", path.read_text(encoding="utf-8"), re.MULTILINE | re.DOTALL)
        exports = [entry.strip() for entry in header[1].replace("(..)", "").split(",")]
        if name not in exports:
            errors.append("missing parity export: " + symbol)
        rows += 1
    if rows == 0:
        errors.append("Haskell parity inventory has no symbols")
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    target = ROOT / "api/0.1.0.txt"
    content = snapshot()
    if args.check:
        if not target.is_file() or target.read_text(encoding="utf-8") != content:
            print("API snapshot is missing or stale", file=sys.stderr)
            return 1
        errors = parity_errors()
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return 1
        print("Haskell API snapshot is current")
    else:
        target.parent.mkdir(exist_ok=True)
        target.write_text(content, encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
