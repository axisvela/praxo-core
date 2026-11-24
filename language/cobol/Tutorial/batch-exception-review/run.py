from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
EXAMPLE = ROOT / "language/cobol/examples/batch-exception-review/run.py"
EXPECTED = (
    "reviewed: batch output unchanged; exceptions retained",
    "unavailable: batch output unchanged; exceptions retained",
    "timeout: batch output unchanged; exceptions retained",
)
LEDGER = "001,12000,10000\n002,05000,05000\n003,00999,01000\n"
EXPECTED_DIFFS = [("001", 2000), ("003", -1)]


def compiler() -> str:
    configured = os.getenv("COBC", "cobc")
    if Path(configured).is_file():
        return configured
    found = shutil.which(configured)
    return found or ""


def compile_reconciler(cobc: str) -> Path:
    build = HERE / "build"
    build.mkdir(exist_ok=True)
    output = build / ("reconcile.exe" if os.name == "nt" else "reconcile")
    result = subprocess.run(
        [cobc, "-x", "-free", "-o", str(output), str(HERE / "reconcile.cob")],
        cwd=ROOT,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=120,
    )
    if result.returncode != 0 or not output.is_file():
        raise RuntimeError(f"COBOL reconciliation did not compile: {result.stderr}")
    return output


def run_reconciliation(reconciler: Path) -> list[tuple[str, int]]:
    with tempfile.TemporaryDirectory(prefix="praxo-cobol-reconcile-") as tmp:
        directory = Path(tmp)
        (directory / "ledger.tsv").write_text(LEDGER, encoding="utf-8")
        result = subprocess.run(
            [str(reconciler)],
            cwd=directory,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            raise RuntimeError(f"COBOL reconciliation failed: {result.stderr}")
        output = directory / "reconciliation.tsv"
        if not output.is_file():
            raise RuntimeError("COBOL reconciliation wrote no exception file")
        rows = []
        for line in output.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            record, difference = line.split(",")
            rows.append((record.strip(), int(difference)))
        return rows


def main() -> int:
    cobc = compiler()
    if not cobc:
        print("cobc is required; add GnuCOBOL to PATH or set COBC", file=sys.stderr)
        return 1
    try:
        reconciler = compile_reconciler(cobc)
        diffs = run_reconciliation(reconciler)
        if diffs != EXPECTED_DIFFS:
            print(f"unexpected reconciliation: {diffs}", file=sys.stderr)
            return 1
        result = subprocess.run(
            [sys.executable, str(EXAMPLE)],
            cwd=ROOT,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=180,
        )
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
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
