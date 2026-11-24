from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
BUDGET = "B1,10000,10800,5,5\nB2,5000,4800,3,3\nB3,7000,7000,4,3\n"
EXPECTED = [
    "item=B1 variance=+000000800 status=review",
    "item=B2 variance=-000000200 status=ok",
    "item=B3 variance=+000000000 status=review",
    "total=0003 flagged=0002",
]


def compiler() -> str:
    configured = os.getenv("COBC", "cobc")
    if Path(configured).is_file():
        return configured
    return shutil.which(configured) or ""


def main() -> int:
    cobc = compiler()
    if not cobc:
        print("cobc is required; add GnuCOBOL to PATH or set COBC", file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory(prefix="praxo-cobol-budget-") as tmp:
        directory = Path(tmp)
        program = directory / ("review.exe" if os.name == "nt" else "review")
        try:
            build = subprocess.run(
                [cobc, "-x", "-free", "-o", str(program), str(HERE / "review.cob")],
                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=120,
            )
            if build.returncode != 0:
                print(f"COBOL budget review did not compile: {build.stderr}", file=sys.stderr)
                return 1
            (directory / "budget.csv").write_text(BUDGET, encoding="utf-8")
            result = subprocess.run(
                [str(program)], cwd=directory, stdin=subprocess.DEVNULL,
                capture_output=True, text=True, timeout=60,
            )
            if result.returncode != 0:
                print(f"COBOL budget review failed: {result.stderr}", file=sys.stderr)
                return 1
            output = directory / "review.txt"
            if not output.is_file():
                print("COBOL budget review wrote no review file", file=sys.stderr)
                return 1
            lines = [" ".join(line.split()) for line in output.read_text(encoding="utf-8").splitlines() if line.strip()]
        except (subprocess.TimeoutExpired, OSError) as error:
            print(str(error), file=sys.stderr)
            return 1
    if lines != EXPECTED:
        print(f"unexpected budget review: {lines}", file=sys.stderr)
        return 1
    for line in lines:
        print(line)
    print("COBOL CT-07 budget review tutorial: passed (variance flags only, no audit conclusion)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
