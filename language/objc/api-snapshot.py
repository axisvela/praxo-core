import argparse
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]


def header_text():
    parts = [
        (ROOT / name).read_text(encoding="utf-8")
        for name in ("PraxoJSON.h", "PraxoWire.h", "PraxoCore.h")
    ]
    return "\n".join(parts)


def declared_symbols():
    text = header_text()
    declarations = re.findall(
        r"(?:FOUNDATION_EXPORT|extern)\s+(.+?);", text, re.DOTALL
    )
    symbols = []
    for raw in declarations:
        declaration = re.sub(r"\s+", " ", raw).strip()
        declaration = declaration.replace("( ", "(").replace(" )", ")")
        if "PXR" in declaration:
            symbols.append(declaration)
    return sorted(set(symbols))


def source_version(name):
    text = (ROOT / "PraxoWire.m").read_text(encoding="utf-8")
    match = re.search(
        r'NSString \*const ' + re.escape(name) + r' = @"([^"]+)";', text
    )
    if not match:
        raise ValueError("missing " + name)
    return match.group(1)


def snapshot():
    spec = (REPO / "spec/SPEC_VERSION").read_text(encoding="utf-8").strip()
    sdk = source_version("PXRSDKVersion")
    declared = source_version("PXRSpecVersion")
    if declared != spec:
        raise ValueError("Objective-C contract version does not match specification")
    symbols = declared_symbols()
    if not any("PXRParseToolCall" in item for item in symbols):
        raise ValueError("no public Objective-C declarations found")
    return "\n".join(
        [
            "# PRAXO-CORE Objective-C Core API " + sdk,
            "# SPEC_VERSION " + spec,
            "",
            *symbols,
            "",
        ]
    )


def parity_errors():
    text = (REPO / "spec/parity/objc.md").read_text(encoding="utf-8")
    spec = (REPO / "spec/SPEC_VERSION").read_text(encoding="utf-8").strip()
    header = header_text()
    errors = []
    if "- SPEC_VERSION: " + spec not in text.splitlines():
        errors.append("contract version mismatch")
    rows = 0
    for line in text.splitlines():
        if not line.startswith("| `"):
            continue
        cells = line.split("|")
        symbol = cells[2].strip(" `")
        if symbol not in header:
            errors.append("missing parity symbol: " + symbol)
        rows += 1
    if rows == 0:
        errors.append("empty parity inventory")
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    sdk_version = source_version("PXRSDKVersion")
    target = ROOT / "api" / f"{sdk_version}.txt"
    content = snapshot()
    errors = parity_errors()
    if errors:
        raise ValueError("\n".join(errors))
    if args.check:
        if not target.is_file() or target.read_text(encoding="utf-8") != content:
            print("Objective-C API snapshot is missing or stale", file=sys.stderr)
            return 1
        print("Objective-C API snapshot and parity are current")
    else:
        target.parent.mkdir(exist_ok=True)
        target.write_text(content, encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
