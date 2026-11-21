from pathlib import Path
import subprocess
import sys
import tempfile


CONSUMER = Path(__file__).resolve().parents[1] / "consumer" / "build.py"
NORMAL = "accepted\t001\n"
EXCEPTIONS = "002\tpublic\n003\tprivate\n"
ADVICE = ["allow: recorded; effects=1", "deny: policy rejected; effects=0"]


def run_batch(directory: Path) -> None:
    (directory / "batch.tsv").write_text(NORMAL, encoding="utf-8")
    (directory / "exceptions.tsv").write_text(EXCEPTIONS, encoding="utf-8")


def main() -> None:
    scenarios = (
        ("reviewed", [sys.executable, str(CONSUMER)], 60),
        ("unavailable", [sys.executable, "-c", "raise SystemExit(75)"], 10),
        ("timeout", [sys.executable, "-c", "import time; time.sleep(60)"], 1),
    )
    for expected, command, timeout in scenarios:
        with tempfile.TemporaryDirectory(prefix="praxo-cobol-review-") as tmp:
            directory = Path(tmp)
            run_batch(directory)
            batch = directory / "batch.tsv"
            exceptions = directory / "exceptions.tsv"
            advice = directory / "advice.txt"
            handoff = exceptions.read_text(encoding="utf-8")
            if batch.read_text(encoding="utf-8") != NORMAL or handoff != EXCEPTIONS:
                raise RuntimeError("Batch failed before review")
            before = (batch.read_bytes(), exceptions.read_bytes())
            try:
                result = subprocess.run(
                    command, cwd=directory, stdin=subprocess.DEVNULL,
                    capture_output=True, text=True, timeout=timeout,
                )
            except subprocess.TimeoutExpired:
                outcome = "timeout"
            else:
                if result.returncode == 0:
                    lines = result.stdout.splitlines()
                    if lines[-2:] != ADVICE:
                        raise RuntimeError(f"Unexpected review output: {result.stdout!r}")
                    records = [row.split("\t")[0] for row in handoff.splitlines()]
                    advice.write_text(
                        "".join(f"{record}\t{text}\n" for record, text in zip(records, lines[-2:])),
                        encoding="utf-8",
                    )
                    outcome = "reviewed"
                elif result.returncode == 75 and expected == "unavailable":
                    outcome = "unavailable"
                else:
                    raise RuntimeError(
                        f"Review worker exited {result.returncode}: "
                        f"{result.stdout.strip()} {result.stderr.strip()}"
                    )

            if outcome != expected or advice.exists() != (expected == "reviewed"):
                raise RuntimeError(f"Expected {expected}, got {outcome}")
            if (batch.read_bytes(), exceptions.read_bytes()) != before:
                raise RuntimeError(f"Review changed batch output or exceptions: {outcome}")
            print(f"{outcome}: batch output unchanged; exceptions retained")


if __name__ == "__main__":
    main()
