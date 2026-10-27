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
directory. The tests cover JSON, the shared toolcall, jsonschema, plugin, and
agent-loop vectors, and agent error cases. Build output goes to
`language/delphi/build/`.

The reported local run with FPC 3.2.2 on Windows i386 passed the wire and agent
vectors and agent error tests. The compiler emitted an existing managed result
warning. Commercial Delphi, other operating systems, and remote CI for the new
loop remain unverified.

The snapshot check compares `api/0.1.0.txt` and checks the contract version
and symbols in `spec/parity/delphi.md`, including the partial agent-loop row.
The shared Go spec checks can also be run from the repository root:

```powershell
$env:GOWORK = 'off'
go test ./internal/spec
```

No result for that shared Go check is claimed here. These checks do not establish
full Framework parity; this remains a Wire-stage candidate with source tag
`delphi/v0.1.0`.
