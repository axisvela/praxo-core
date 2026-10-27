# Delphi / Free Pascal Setup

Local verification used Free Pascal 3.2.2 on Windows i386 and Python 3.14.
Install FPC with its FCL JSON and RegExpr units and Python 3.10 or newer. Make
`fpc` available on PATH, set `FPC` to its executable, or pass `--compiler` to
the test runner. Commercial Delphi and other operating systems are not verified.

From the repository root in PowerShell:

```powershell
python language/delphi/run-tests.py
python language/delphi/api-snapshot.py --check
```

For a compiler outside PATH, use `python language/delphi/run-tests.py --compiler
"C:\path\to\fpc.exe"` or set `$env:FPC` to that executable. The runner invokes
`api-snapshot.py --check`, builds `praxo.pas` and the two native test programs
with `-Mobjfpc -Scghi -O2 -Fu.`, and runs them against the repository `spec`
directory. The tests cover JSON, all eleven shared vector groups, and agent error
cases. Build output goes to `language/delphi/build/`.

The reported local run with FPC 3.2.2 on Windows i386 passed all eleven vector
groups and the native tests. The compiler emitted existing managed result
warnings. Commercial Delphi, other operating systems, and remote CI remain
unverified.

The snapshot check compares `api/0.2.0.txt` and checks the contract version
and symbols in `spec/parity/delphi.md`.
The shared Go spec checks can also be run from the repository root:

```powershell
$env:GOWORK = 'off'
go test ./internal/spec
```

No result for that shared Go check is claimed here. These checks cover the
declared Core gate under Free Pascal; the commercial Delphi compiler is not
independently verified.
