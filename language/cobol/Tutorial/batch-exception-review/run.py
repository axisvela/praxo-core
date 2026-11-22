from pathlib import Path
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
EXAMPLE = ROOT / "language/cobol/examples/batch-exception-review/run.py"
EXPECTED = (
    "reviewed: batch output unchanged; exceptions retained",
    "unavailable: batch output unchanged; exceptions retained",
    "timeout: batch output unchanged; exceptions retained",
)


def main() -> int:
    if not shutil.which(os.getenv("COBC", "cobc")) and not Path(os.getenv("COBC", "")).is_file():
        print("cobc is required; add GnuCOBOL to PATH or set COBC", file=sys.stderr)
        return 1
    try:
        result = subprocess.run(
            [sys.executable, str(EXAMPLE)],
            cwd=ROOT,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=180,
        )
    except subprocess.TimeoutExpired:
        print("batch exception review timed out", file=sys.stderr)
        return 1
    lines = result.stdout.splitlines()
    if result.returncode != 0 or tuple(lines[-3:]) != EXPECTED:
        print(result.stdout, file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        print("batch exception review did not satisfy its contract", file=sys.stderr)
        return 1
    print("COBOL batch exception review tutorial: passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
