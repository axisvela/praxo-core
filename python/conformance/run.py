from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.conformance import run_all
from praxo.parity import check_parity


def main() -> int:
    failures = run_all()
    parity = check_parity()
    for failure in failures:
        print(failure)
    for failure in parity:
        print(f"parity: {failure}")
    if not failures and not parity:
        print("all spec vectors and Python parity checks passed")
        return 0
    print(f"{len(failures)} vector(s) failed, {len(parity)} parity gap(s)")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
