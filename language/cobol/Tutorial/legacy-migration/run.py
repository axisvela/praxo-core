from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
CATALOG = "CUSTMAIN,CICS,ACTIVE,1200\nBILLCALC,BATCH,ACTIVE,800\nRPTGEN,BATCH,RETIRED,300\n"
EXPECTED = [
    "module=CUSTMAIN kind=CICS status=ACTIVE lines=01200",
    "module=BILLCALC kind=BATCH status=ACTIVE lines=00800",
    "module=RPTGEN kind=BATCH status=RETIRED lines=00300",
    "total=0003 active=0002 batch=0002",
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
    with tempfile.TemporaryDirectory(prefix="praxo-cobol-migration-") as tmp:
        directory = Path(tmp)
        program = directory / ("inventory.exe" if os.name == "nt" else "inventory")
        try:
            build = subprocess.run(
                [cobc, "-x", "-free", "-o", str(program), str(HERE / "inventory.cob")],
                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=120,
            )
            if build.returncode != 0:
                print(f"COBOL inventory did not compile: {build.stderr}", file=sys.stderr)
                return 1
            (directory / "catalog.csv").write_text(CATALOG, encoding="utf-8")
            result = subprocess.run(
                [str(program)], cwd=directory, stdin=subprocess.DEVNULL,
                capture_output=True, text=True, timeout=60,
            )
            if result.returncode != 0:
                print(f"COBOL inventory failed: {result.stderr}", file=sys.stderr)
                return 1
            output = directory / "inventory.txt"
            if not output.is_file():
                print("COBOL inventory wrote no inventory file", file=sys.stderr)
                return 1
            lines = [" ".join(line.split()) for line in output.read_text(encoding="utf-8").splitlines() if line.strip()]
        except (subprocess.TimeoutExpired, OSError) as error:
            print(str(error), file=sys.stderr)
            return 1
    if lines != EXPECTED:
        print(f"unexpected inventory: {lines}", file=sys.stderr)
        return 1
    for line in lines:
        print(line)
    print("COBOL SE-03 legacy migration tutorial: passed (inventory only, no migration)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
