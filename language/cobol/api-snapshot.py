import argparse
import difflib
from pathlib import Path
import re


def normalized(text):
    return re.sub(r"\s+", " ", text.strip())


def copybook_members(path):
    result = []
    for source in path.read_text(encoding="utf-8").splitlines():
        line = source.strip()
        if not line or line.startswith("*>"):
            continue
        match = re.match(r"(\d\d)\s+([A-Za-z0-9-]+)(.*)", line)
        if match:
            result.append(f"  {match.group(1)} {match.group(2)}"
                          f"{normalized(match.group(3))}")
    return result


def program_api(path):
    text = path.read_text(encoding="utf-8")
    result = []
    for match in re.finditer(r"(?im)^\s*program-id\.\s*([A-Za-z0-9-]+)", text):
        result.append(f"program {match.group(1)}")
    for match in re.finditer(r"(?is)procedure\s+division\s+using\s+(.*?)\.",
                             text):
        using = normalized(match.group(1))
        result.append(f"  using {using}")
    return result


def snapshot(root):
    output = ["COBOL API inventory 0.1.2"]
    for path in sorted((root / "copy").glob("*.cpy")):
        output += ["", f"copybook {path.stem}"]
        output += copybook_members(path)
    for path in sorted((root / "src").glob("*.cob")):
        output += ["", f"module {path.stem}"]
        output += program_api(path)
    return "\n".join(output) + "\n"


def main():
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--update", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    path = root / "api" / "0.1.2.txt"
    current = snapshot(root)
    if args.update:
        path.parent.mkdir(exist_ok=True)
        path.write_text(current, encoding="utf-8")
        return
    expected = path.read_text(encoding="utf-8") if path.exists() else ""
    if current != expected:
        print("".join(difflib.unified_diff(
            expected.splitlines(True), current.splitlines(True),
            fromfile=str(path), tofile="current API")))
        raise SystemExit("COBOL API snapshot mismatch")
    print("PASS: COBOL API declaration snapshot")


if __name__ == "__main__":
    main()
