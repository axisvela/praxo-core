from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
EXPECTED = [
    "grid_size=4",
    "placed=3",
    "overlaps=0",
    "within_grid=T",
    "wirelength_proxy= 12.5",
    "status=draft_only",
    "foundry_valid=F",
]


def compiler() -> str:
    configured = os.getenv("GFORTRAN", "gfortran")
    if Path(configured).is_file():
        return configured
    return shutil.which(configured) or ""


def main() -> int:
    gfortran = compiler()
    if not gfortran:
        print("gfortran is required; add it to PATH or set GFORTRAN", file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory(prefix="praxo-fortran-eda-") as tmp:
        output = Path(tmp) / ("eda.exe" if os.name == "nt" else "eda")
        try:
            build = subprocess.run(
                [gfortran, "-std=f2008", "-O2", "-o", str(output), str(HERE / "main.f90")],
                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=120,
            )
            if build.returncode != 0:
                print(f"Fortran EDA tutorial did not compile: {build.stderr}", file=sys.stderr)
                return 1
            result = subprocess.run(
                [str(output)], cwd=tmp, stdin=subprocess.DEVNULL,
                capture_output=True, text=True, timeout=60,
            )
            if result.returncode != 0:
                print(f"Fortran EDA tutorial failed: {result.stderr}", file=sys.stderr)
                return 1
            lines = [" ".join(line.split()) for line in result.stdout.splitlines() if line.strip()]
        except (subprocess.TimeoutExpired, OSError) as error:
            print(str(error), file=sys.stderr)
            return 1
    if lines != EXPECTED:
        print(f"unexpected EDA output: {lines}", file=sys.stderr)
        return 1
    for line in lines:
        print(line)
    print("Fortran OG-05 eda-placement tutorial: passed (review only)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
