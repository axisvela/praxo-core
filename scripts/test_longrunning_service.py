from pathlib import Path
import os
import platform
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
RECIPE = ROOT / "examples/recipes/long-running-go"


def run(name, command, env=None, cwd=ROOT):
    print(f"== {name} ==")
    print(" ".join(map(str, command)))
    result = subprocess.run(command, cwd=cwd, env=env, text=True)
    if result.returncode != 0:
        raise SystemExit(f"{name} failed with exit code {result.returncode}")


def main():
    go = "go"
    env = dict(os.environ, GOWORK="off")
    print(f"python={sys.version.split()[0]} platform={platform.platform()}")
    run("go version", [go, "version"], env=env, cwd=RECIPE)
    run("module tests", [go, "test", "-mod=readonly", "./..."], env=env, cwd=RECIPE)
    load_env = dict(env, PRAXO_LOAD_SUBMISSIONS="100")
    run(
        "load and fault test",
        [go, "test", "-mod=readonly", "-run", "TestStandaloneServiceLoadFault", "-v", "./cmd/longrunning-service"],
        env=load_env,
        cwd=RECIPE,
    )
    run("published-package recipe", [sys.executable, "scripts/test_go_longrunning.py"])
    print("long-running service reproduction passed")


if __name__ == "__main__":
    main()
