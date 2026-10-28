import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BINARY = Path(sys.argv[1]).resolve()


def run(temp):
    return subprocess.run(
        [str(BINARY)],
        cwd=temp,
        capture_output=True,
        text=True,
        timeout=30,
    )


def copy_spec(temp):
    target = temp / "spec"
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(ROOT / "spec", target)


def mutate_vector(temp, group, action):
    path = temp / "spec" / "vectors" / f"{group}.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    action(data)
    path.write_text(json.dumps(data), encoding="utf-8")


def main():
    with tempfile.TemporaryDirectory() as directory:
        temp = Path(directory)
        copy_spec(temp)
        baseline = run(temp)
        if baseline.returncode != 0:
            raise AssertionError(baseline.stderr or baseline.stdout)

        (temp / "spec" / "SPEC_VERSION").write_text("9.9.9\n", encoding="utf-8")
        mismatch = run(temp)
        if mismatch.returncode == 0 or "specVersion mismatch" not in mismatch.stderr:
            raise AssertionError(f"version mismatch accepted: {mismatch.stderr}")

        copy_spec(temp)
        (temp / "spec" / "SPEC_VERSION").write_text("0.2.0\n", encoding="utf-8")
        mutate_vector(
            temp,
            "toolcall",
            lambda data: data["vectors"].append(data["vectors"][0]),
        )
        duplicate = run(temp)
        if duplicate.returncode == 0 or "duplicate" not in duplicate.stderr:
            raise AssertionError(f"duplicate id accepted: {duplicate.stderr}")

        copy_spec(temp)
        (temp / "spec" / "SPEC_VERSION").write_text("0.2.0\n", encoding="utf-8")
        mutate_vector(temp, "event", lambda data: data.update(vectors=[]))
        empty = run(temp)
        if empty.returncode == 0 or "missing or empty vectors" not in empty.stderr:
            raise AssertionError(f"empty group accepted: {empty.stderr}")

        copy_spec(temp)
        (temp / "spec" / "SPEC_VERSION").write_text("0.2.0\n", encoding="utf-8")
        mutate_vector(temp, "memory", lambda data: data["vectors"][0].pop("input"))
        missing = run(temp)
        if missing.returncode == 0 or "missing input or expect" not in missing.stderr:
            raise AssertionError(f"missing input accepted: {missing.stderr}")

    print("C conformance inventory negative controls passed")


if __name__ == "__main__":
    main()
