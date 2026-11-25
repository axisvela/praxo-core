from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
BUILD = ROOT / "build" / "application"
BUILD.mkdir(parents=True, exist_ok=True)

EXPECTED = (
    "public: reviewed advisory=1 executions=0",
    "private: denied before read",
    "direct: denied with zero effects",
    "tenant: denied before model",
    "weak: denied without rationale",
)
FIXTURE = (
    "002,public,25.00\n"
    "003,private,-1.00\n"
)


def compiler() -> str:
    found = shutil.which(os.environ.get("COBC", "cobc"))
    if not found:
        sys.exit("GnuCOBOL compiler not found; set COBC")
    return found


def environment(cobc: str) -> dict[str, str]:
    env = os.environ.copy()
    toolchain = Path(cobc).resolve().parent.parent
    if os.name == "nt":
        env["PATH"] = str(Path(cobc).parent) + os.pathsep + env["PATH"]
        if (toolchain / "config" / "default.conf").is_file():
            env.setdefault("COB_CONFIG_DIR", str(toolchain / "config"))
            env.setdefault("COB_COPY_DIR", str(toolchain / "copy"))
            for name, flag, directory in (
                ("COB_CFLAGS", "-I", "include"),
                ("COB_LDFLAGS", "-L", "lib"),
            ):
                env[name] = f'{flag}"{toolchain / directory}" ' + env.get(name, "")
    return env


def build(cobc: str, env: dict[str, str]) -> Path:
    agent_object = BUILD / "batch-analyst-agent.o"
    executable = BUILD / (
        "cobol-batch-analyst" + (".exe" if os.name == "nt" else "")
    )
    subprocess.run(
        [cobc, "-c", "-free", "-I", str(ROOT / "copy"),
         "-o", str(agent_object), str(ROOT / "src" / "agent.cob")],
        cwd=ROOT,
        env=env,
        check=True,
    )
    subprocess.run(
        [cobc, "-x", "-free", "-I", str(ROOT / "copy"),
         "-I", str(HERE), "-o", str(executable),
         str(HERE / "application.cob"), str(agent_object)],
        cwd=ROOT,
        env=env,
        check=True,
    )
    return executable


def check_self_test(executable: Path, env: dict[str, str]) -> None:
    result = subprocess.run(
        [str(executable), "--test"],
        cwd=ROOT,
        env=env,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=60,
    )
    lines = result.stdout.splitlines()
    if result.returncode != 0 or tuple(lines[:5]) != EXPECTED:
        print(result.stdout, file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        sys.exit("COBOL batch analyst self-test failed")
    if lines[-1] != "COBOL batch analyst self-test: passed":
        print(result.stdout, file=sys.stderr)
        sys.exit("COBOL batch analyst did not report success")


def check_batch(executable: Path, env: dict[str, str]) -> None:
    with tempfile.TemporaryDirectory(prefix="praxo-cobol-analyst-") as tmp:
        directory = Path(tmp)
        (directory / "exceptions.tsv").write_text(FIXTURE, encoding="utf-8")
        result = subprocess.run(
            [str(executable)],
            cwd=directory,
            env=env,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            print(result.stdout, file=sys.stderr)
            print(result.stderr, file=sys.stderr)
            sys.exit("COBOL batch analyst run failed")
        advisory = (directory / "advisory.tsv").read_text(encoding="utf-8")
        if "002,public," not in advisory:
            sys.exit("public exception produced no advisory")
        if "003,private," in advisory:
            sys.exit("private exception produced an advisory")
        if "executions=0" not in result.stdout:
            print(result.stdout, file=sys.stderr)
            sys.exit("batch output did not record zero effects")


def main() -> int:
    cobc = compiler()
    env = environment(cobc)
    executable = build(cobc, env)
    check_self_test(executable, env)
    check_batch(executable, env)
    print("COBOL batch exception analyst: passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
