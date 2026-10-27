import argparse
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]


def snapshot():
    spec = (REPO / "spec/SPEC_VERSION").read_text(encoding="utf-8").strip()
    lines = ["# PRAXO-CORE MATLAB/Octave Wire API 0.1.0", "# SPEC_VERSION " + spec, ""]
    for path in sorted((ROOT / "+praxo").glob("*.m")):
        text = path.read_text(encoding="utf-8")
        match = re.match(r"function\s+([^\n]+)", text)
        if not match or not re.search(r"\b" + re.escape(path.stem) + r"\s*\(", match[1]):
            raise ValueError("invalid public function declaration: " + str(path))
        lines.append("praxo." + match[1].strip())
    return "\n".join(lines) + "\n"


def parity_errors():
    text = (REPO / "spec/parity/matlab.md").read_text(encoding="utf-8")
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
        if not symbol.startswith("praxo.") or not (ROOT / "+praxo" / (symbol[6:] + ".m")).is_file():
            errors.append("missing parity function: " + symbol)
        rows += 1
    if rows == 0:
        errors.append("empty parity inventory")
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    target = ROOT / "api/0.1.0.txt"
    content = snapshot()
    errors = parity_errors()
    if errors:
        raise ValueError("\n".join(errors))
    if args.check:
        if not target.is_file() or target.read_text(encoding="utf-8") != content:
            print("MATLAB/Octave API snapshot is missing or stale", file=sys.stderr)
            return 1
        print("MATLAB/Octave API snapshot and parity are current")
    else:
        target.parent.mkdir(exist_ok=True)
        target.write_text(content, encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
