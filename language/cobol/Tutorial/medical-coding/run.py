from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
RECORDS = "R1,67,2,1\nR2,45,1,0\nR3,81,3,2\n"
EXPECTED = [
    "record=R1 complete=YES code=DRG-DRAFT-A status=draft_only",
    "record=R2 complete=NO code=REVIEW status=review_required",
    "record=R3 complete=YES code=DRG-DRAFT-A status=draft_only",
    "total=0003 complete=0002 review=0001",
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
    with tempfile.TemporaryDirectory(prefix="praxo-cobol-coding-") as tmp:
        directory = Path(tmp)
        program = directory / ("review.exe" if os.name == "nt" else "review")
        try:
            build = subprocess.run(
                [cobc, "-x", "-free", "-o", str(program), str(HERE / "review.cob")],
                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=120,
            )
            if build.returncode != 0:
                print(f"COBOL review did not compile: {build.stderr}", file=sys.stderr)
                return 1
            (directory / "records.csv").write_text(RECORDS, encoding="utf-8")
            result = subprocess.run(
                [str(program)], cwd=directory, stdin=subprocess.DEVNULL,
                capture_output=True, text=True, timeout=60,
            )
            if result.returncode != 0:
                print(f"COBOL review failed: {result.stderr}", file=sys.stderr)
                return 1
            output = directory / "review.txt"
            if not output.is_file():
                print("COBOL review wrote no review file", file=sys.stderr)
                return 1
            lines = [" ".join(line.split()) for line in output.read_text(encoding="utf-8").splitlines() if line.strip()]
        except (subprocess.TimeoutExpired, OSError) as error:
            print(str(error), file=sys.stderr)
            return 1
    if lines != EXPECTED:
        print(f"unexpected review: {lines}", file=sys.stderr)
        return 1
    for line in lines:
        print(line)
    print("COBOL HC-04 medical coding tutorial: passed (review-only draft codes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
